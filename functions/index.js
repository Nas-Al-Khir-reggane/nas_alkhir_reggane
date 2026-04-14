const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();

// Set global options for v2 functions
setGlobalOptions({maxInstances: 10, timeoutSeconds: 60, region: "us-central1"});

exports.sendNotification = onDocumentCreated("notifications/{notificationId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    console.log("No data associated with the event");
    return;
  }

  const notificationData = snapshot.data();
  const notificationId = event.params.notificationId;

  console.log(`Processing notification: ${notificationId}`, JSON.stringify(notificationData));

  const {
    title,
    body,        // FIX: Flutter writes 'body', not 'message'
    targetRole,  // e.g., 'admin', 'superAdmin', 'worker', 'donor', 'all'
    userId,      // If targeting a specific user
    type,
    requestId,
    chatId,
    bloodType,
    hospital,
    phone,
    senderName,
    imageUrl,
  } = notificationData;

  // Build the FCM data payload (all values must be strings per FCM spec)
  const fcmData = {
    click_action: "FLUTTER_NOTIFICATION_CLICK",
    notificationId: notificationId,
    type: String(type || "general"),
  };

  // Safely add optional string fields to data payload
  if (requestId != null) fcmData.requestId = String(requestId);
  if (chatId != null) fcmData.chatId = String(chatId);
  if (bloodType != null) fcmData.bloodType = String(bloodType);
  if (hospital != null) fcmData.hospital = String(hospital);
  if (phone != null) fcmData.phone = String(phone);
  if (senderName != null) fcmData.senderName = String(senderName);
  if (imageUrl != null) fcmData.imageUrl = String(imageUrl);

  try {
    const tokens = [];

    if (userId) {
      // 1. Target a specific user by userId
      console.log(`Targeting user: ${userId}`);
      const userDoc = await admin.firestore().collection("users").doc(userId).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
          tokens.push(...userData.fcmTokens);
        }
      }

    } else if (targetRole === "all") {
      // 2. Broadcast to ALL users
      console.log("Broadcasting to all users");
      const usersSnapshot = await admin.firestore().collection("users").get();
      usersSnapshot.forEach(doc => {
        const userData = doc.data();
        if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
          tokens.push(...userData.fcmTokens);
        }
      });

    } else if (targetRole === "admin") {
      // 3. Target admins AND superAdmins (they see admin-level notifications)
      console.log("Targeting role: admin + superAdmin");
      const [adminSnap, superAdminSnap] = await Promise.all([
        admin.firestore().collection("users").where("role", "==", "admin").get(),
        admin.firestore().collection("users").where("role", "==", "superAdmin").get(),
      ]);
      adminSnap.forEach(doc => {
        const userData = doc.data();
        if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
          tokens.push(...userData.fcmTokens);
        }
      });
      superAdminSnap.forEach(doc => {
        const userData = doc.data();
        if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
          tokens.push(...userData.fcmTokens);
        }
      });

    } else if (targetRole) {
      // 4. Target any other specific role (worker, donor, beneficiary, chatModerator, etc.)
      console.log(`Targeting role: ${targetRole}`);
      const usersSnapshot = await admin.firestore().collection("users")
        .where("role", "==", targetRole).get();
      usersSnapshot.forEach(doc => {
        const userData = doc.data();
        if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
          tokens.push(...userData.fcmTokens);
        }
      });
    }

    if (tokens.length === 0) {
      console.log(`No FCM tokens found for notification ${notificationId} (userId=${userId}, targetRole=${targetRole})`);
      await snapshot.ref.update({
        status: "no_tokens",
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    // Remove duplicates (a user with multiple devices might have multiple tokens)
    const uniqueTokens = [...new Set(tokens)];
    console.log(`Dispatching FCM to ${uniqueTokens.length} unique token(s)`);

    // Send all notifications in a single multicast call (max 500 tokens per call)
    const BATCH_SIZE = 500;
    let totalSuccess = 0;
    let totalFailure = 0;
    const allFailedTokens = [];

    for (let i = 0; i < uniqueTokens.length; i += BATCH_SIZE) {
      const batch = uniqueTokens.slice(i, i + BATCH_SIZE);

      const response = await admin.messaging().sendEachForMulticast({
        tokens: batch,
        notification: {
          title: title || "إشعار جديد",
          body: body || "",
        },
        data: fcmData,
        android: {
          priority: "high",
          notification: {
            title: title || "إشعار جديد",
            body: body || "",
            sound: "notification",
            channelId: "nas_alkhair_v2",
            icon: "@mipmap/launcher_icon",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
            notificationPriority: "PRIORITY_MAX",
            visibility: "PUBLIC",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "notification.wav",
              badge: 1,
              contentAvailable: true,
            },
          },
        },
      });

      totalSuccess += response.successCount;
      totalFailure += response.failureCount;

      // Collect invalid tokens for cleanup
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const errCode = resp.error?.code;
          console.warn(`FCM error for token[${i + idx}]: ${errCode} - ${resp.error?.message}`);
          if (
            errCode === "messaging/invalid-registration-token" ||
            errCode === "messaging/registration-token-not-registered" ||
            errCode === "messaging/invalid-argument"
          ) {
            allFailedTokens.push(batch[idx]);
          }
        }
      });
    }

    console.log(`FCM result: ${totalSuccess} succeeded, ${totalFailure} failed`);

    // ─── Cleanup invalid tokens from Firestore ───
    if (allFailedTokens.length > 0) {
      console.log(`Cleaning up ${allFailedTokens.length} invalid/expired FCM token(s)...`);

      if (userId) {
        // Simple single-user cleanup
        await admin.firestore().collection("users").doc(userId).update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...allFailedTokens),
        });
      } else {
        // Multi-user cleanup — find all users that hold any of the failed tokens
        const allUsersSnap = await admin.firestore().collection("users").get();
        const firestoreBatch = admin.firestore().batch();
        let batchOpCount = 0;

        allUsersSnap.forEach(doc => {
          const userData = doc.data();
          const tokensArr = userData.fcmTokens;
          if (!tokensArr || !Array.isArray(tokensArr)) return;

          const hasInvalid = tokensArr.some(t => allFailedTokens.includes(t));
          if (hasInvalid) {
            firestoreBatch.update(doc.ref, {
              fcmTokens: admin.firestore.FieldValue.arrayRemove(...allFailedTokens),
            });
            batchOpCount++;
          }
        });

        if (batchOpCount > 0) {
          await firestoreBatch.commit();
          console.log(`Cleaned invalid tokens from ${batchOpCount} user document(s)`);
        }
      }
    }

    // Mark the notification document as processed
    await snapshot.ref.update({
      status: "sent",
      successCount: totalSuccess,
      failureCount: totalFailure,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

  } catch (error) {
    console.error(`Error processing notification ${notificationId}:`, error);
    await snapshot.ref.update({
      status: "failed",
      error: error.message,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
});

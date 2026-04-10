const admin = require('firebase-admin');
const express = require('express');
const app = express();

app.use(express.json());

// ======================================================
// إعداد Firebase Admin
// ======================================================
let serviceAccount;
try {
  if (process.env.FIREBASE_CONFIG) {
    serviceAccount = JSON.parse(process.env.FIREBASE_CONFIG);
  } else {
    serviceAccount = require('./serviceAccountKey.json');
  }
} catch (e) {
  console.error("❌ خطأ فادح في معالجة إعدادات Firebase:", e.message);
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();
const fcm = admin.messaging();

// ======================================================
// مسار التأكد من عمل السيرفر
// ======================================================
app.get('/', (req, res) => res.send('🚀 خادم إشعارات "ناس الخير" يعمل بنجاح على Vercel!'));

// ======================================================
// دالة مساعدة: استخراج كل توكنات المستخدم (بدون تكرار)
// ======================================================
function extractTokens(userData) {
  const tokens = new Set();

  if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
    userData.fcmTokens.forEach(t => {
      if (t && typeof t === 'string' && t.length > 10) tokens.add(t);
    });
  }

  if (userData.fcmToken && typeof userData.fcmToken === 'string' && userData.fcmToken.length > 10) {
    tokens.add(userData.fcmToken);
  }

  return [...tokens];
}

// ======================================================
// دالة مساعدة: إرسال FCM مع إعادة المحاولة (Retry)
// ======================================================
async function sendFCMWithRetry(tokens, notification, dataPayload, retries = 3) {
  if (!tokens || tokens.length === 0) {
    console.log('⚠️ لا توجد توكنات صالحة للإرسال.');
    return { success: 0, failure: 0 };
  }

  const uniqueTokens = [...new Set(tokens)];
  console.log(`📨 إرسال إلى ${uniqueTokens.length} جهاز...`);

  // ─── تحديد نوع الصوت بناءً على نوع الإشعار ───
  const type = dataPayload.type || '';
  const isChat = type === 'new_message' || type === 'group_message' || type === 'guest_message';
  const isEmergency = type === 'blood_emergency' || type === 'sos_trigger' || type.includes('emergency');
  
  const channelId = isEmergency ? 'nas_alkhair_emergency' : (isChat ? 'nas_alkhair_chats' : 'nas_alkhair_v2');
  const soundName = isEmergency ? 'siren' : (isChat ? 'new_message' : 'notification');

  const message = {
    notification: {
      title: notification.title || 'جمعية ناس الخير',
      body: notification.body || '',
    },
    data: dataPayload,
    android: {
      priority: 'high',
      notification: {
        channelId: channelId,
        sound: soundName,
        defaultVibrateTimings: true,
        notificationPriority: 'PRIORITY_MAX',
        visibility: 'PUBLIC',
        tag: `nas_${dataPayload.type || 'general'}_${dataPayload.notificationId || 'unknown'}`,
      }
    },
    apns: {
      payload: {
        aps: {
          alert: {
            title: notification.title || 'جمعية ناس الخير',
            body: notification.body || '',
          },
          sound: soundName + '.wav',
          badge: 1,
          'content-available': 1,
          'mutable-content': 1,
          'thread-id': `nas_${dataPayload.type || 'general'}`,
        }
      },
      headers: {
        'apns-priority': '10',
        'apns-collapse-id': `nas_${dataPayload.notificationId || 'unknown'}`,
      },
    },
  };

  const deadTokens = [];
  let totalSuccess = 0;
  let totalFailure = 0;

  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      if (uniqueTokens.length === 1) {
        try {
          await fcm.send({ ...message, token: uniqueTokens[0] });
          console.log('✅ تم إرسال الإشعار بنجاح.');
          totalSuccess = 1;
          break;
        } catch (err) {
          console.error(`❌ فشل الإرسال (محاولة ${attempt}):`, err.message);
          if (err.code === 'messaging/registration-token-not-registered' ||
              err.code === 'messaging/invalid-registration-token') {
            deadTokens.push(uniqueTokens[0]);
            break; // لا فائدة من إعادة المحاولة مع توكن ميت
          }
          if (attempt === retries) { totalFailure = 1; break; }
          await new Promise(r => setTimeout(r, attempt * 1000));
        }
      } else {
        for (let i = 0; i < uniqueTokens.length; i += 500) {
          const batch = uniqueTokens.slice(i, i + 500);
          try {
            const response = await fcm.sendEachForMulticast({ ...message, tokens: batch });
            console.log(`✅ نجح: ${response.successCount}, فشل: ${response.failureCount} من ${batch.length}`);
            totalSuccess += response.successCount;
            totalFailure += response.failureCount;

            response.responses.forEach((resp, idx) => {
              if (!resp.success) {
                const errCode = resp.error?.code;
                if (errCode === 'messaging/registration-token-not-registered' ||
                    errCode === 'messaging/invalid-registration-token') {
                  deadTokens.push(batch[idx]);
                }
              }
            });
          } catch (err) {
            console.error('❌ فشل إرسال دفعة:', err.message);
            totalFailure += batch.length;
          }
        }
        break; // multicast لا يحتاج إعادة محاولة
      }
    } catch (outerErr) {
      console.error(`❌ خطأ عام (محاولة ${attempt}):`, outerErr.message);
      if (attempt < retries) await new Promise(r => setTimeout(r, attempt * 1000));
    }
  }

  // تنظيف التوكنات الميتة
  if (deadTokens.length > 0) {
    console.log(`🧹 حذف ${deadTokens.length} توكن منتهي الصلاحية...`);
    try {
      const usersSnap = await db.collection('users').get();
      const writeBatch = db.batch();
      usersSnap.forEach(doc => {
        const data = doc.data();
        const userTokens = extractTokens(data);
        const hasDeadToken = deadTokens.some(dead => userTokens.includes(dead));
        if (hasDeadToken) {
          const updates = {};
          if (deadTokens.includes(data.fcmToken)) {
            updates.fcmToken = admin.firestore.FieldValue.delete();
          }
          if (data.fcmTokens) {
            updates.fcmTokens = admin.firestore.FieldValue.arrayRemove(...deadTokens);
          }
          if (Object.keys(updates).length > 0) {
            writeBatch.update(doc.ref, updates);
          }
        }
      });
      await writeBatch.commit();
    } catch (e) {
      console.error('⚠️ خطأ في تنظيف التوكنات الميتة:', e.message);
    }
  }

  return { success: totalSuccess, failure: totalFailure };
}

// ======================================================
// ⚡ نقطة الوصول الرئيسية: إرسال إشعار FCM فوراً
// يُستدعى من تطبيق Flutter بعد كتابة الإشعار في Firestore
// ======================================================
app.post('/send-notification', async (req, res) => {
  try {
    const { notificationId } = req.body;

    if (!notificationId) {
      return res.status(400).json({ error: 'notificationId مطلوب' });
    }

    // جلب بيانات الإشعار من Firestore
    const notifDoc = await db.collection('notifications').doc(notificationId).get();
    if (!notifDoc.exists) {
      return res.status(404).json({ error: 'الإشعار غير موجود' });
    }

    const data = notifDoc.data();

    // تجنب الإرسال المزدوج
    if (data.fcmSent === true) {
      return res.status(200).json({ message: 'تم إرساله مسبقاً', alreadySent: true });
    }

    const senderId = data.senderId || data.data?.senderId || null;

    // تجهيز payload البيانات
    const fcmDataPayload = {
      notificationId: String(notificationId),
      type: String(data.type || 'general'),
    };

    const topLevelFields = ['chatId', 'requestId', 'bloodType', 'hospital', 'phone',
                             'patientName', 'collection', 'targetRole', 'imageUrl',
                             'donationId', 'senderName', 'senderId'];
    topLevelFields.forEach(key => {
      if (data[key] != null) fcmDataPayload[key] = String(data[key]);
    });

    if (data.data && typeof data.data === 'object') {
      for (const [key, value] of Object.entries(data.data)) {
        if (value != null && fcmDataPayload[key] === undefined) {
          fcmDataPayload[key] = String(value);
        }
      }
    }

    const notification = {
      title: data.title || 'جمعية ناس الخير',
      body: data.body || '',
    };

    let targetTokens = [];

    // ── أ: إشعار لمستخدم محدد (userId) ──────────────────
    if (data.userId) {
      if (senderId && senderId === data.userId) {
        console.log(`⏭️ تخطي: إشعار ذاتي للمستخدم ${data.userId}`);
        await db.collection('notifications').doc(notificationId).update({ fcmSent: true });
        return res.status(200).json({ message: 'تم تخطيه (إشعار ذاتي)', skipped: true });
      }

      const userDoc = await db.collection('users').doc(data.userId).get();
      if (userDoc.exists) {
        targetTokens = extractTokens(userDoc.data());
      } else {
        console.log(`⚠️ المستخدم ${data.userId} غير موجود.`);
      }

    // ── ب: إشعار جماعي (targetRole) ─────────────────────
    } else if (data.targetRole) {
      let query = db.collection('users');

      if (data.targetRole === 'admin') {
        query = query.where('role', 'in', ['admin', 'superAdmin', 'superadmin']);
      } else if (data.targetRole === 'all') {
        // كل المستخدمين بدون فلترة
      } else {
        query = query.where('role', '==', data.targetRole);
      }

      const usersSnap = await query.get();
      usersSnap.forEach(userDoc => {
        if (userDoc.id === senderId) return;
        if (data.excludeUserId && userDoc.id === data.excludeUserId) return;
        targetTokens.push(...extractTokens(userDoc.data()));
      });

      console.log(`ℹ️ [${data.targetRole}] تجميع ${targetTokens.length} توكن.`);
    } else {
      await db.collection('notifications').doc(notificationId).update({ fcmSent: true });
      return res.status(200).json({ message: 'لا يوجد هدف (userId/targetRole)', skipped: true });
    }

    // إرسال FCM مع إعادة المحاولة
    const result = await sendFCMWithRetry(targetTokens, notification, fcmDataPayload);

    // تحديث الوثيقة كـ "تم الإرسال"
    await db.collection('notifications').doc(notificationId).update({
      fcmSent: true,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ [${notificationId}] تم الإرسال: نجح ${result.success}, فشل ${result.failure}`);
    return res.status(200).json({
      message: 'تم الإرسال بنجاح',
      success: result.success,
      failure: result.failure,
    });

  } catch (err) {
    console.error('❌ خطأ في /send-notification:', err.message);
    return res.status(500).json({ error: err.message });
  }
});

// ======================================================
// ⚡ نقطة وصول احتياطية: معالجة كل الإشعارات المعلقة
// يمكن استدعاؤها دورياً كشبكة أمان
// ======================================================
app.post('/process-pending', async (req, res) => {
  try {
    const pendingSnap = await db.collection('notifications')
      .where('fcmSent', '==', false)
      .orderBy('createdAt', 'desc')
      .limit(20)
      .get();

    // أيضاً الإشعارات التي لا تحتوي حقل fcmSent أصلاً (قديمة)
    const noFieldSnap = await db.collection('notifications')
      .orderBy('createdAt', 'desc')
      .limit(50)
      .get();

    const allPending = new Map();
    pendingSnap.docs.forEach(doc => allPending.set(doc.id, doc));
    noFieldSnap.docs.forEach(doc => {
      const data = doc.data();
      if (data.fcmSent === undefined || data.fcmSent === null) {
        allPending.set(doc.id, doc);
      }
    });

    if (allPending.size === 0) {
      return res.status(200).json({ message: 'لا توجد إشعارات معلقة', processed: 0 });
    }

    console.log(`📋 معالجة ${allPending.size} إشعار معلق...`);
    let processed = 0;

    for (const [notificationId, notifDoc] of allPending) {
      const data = notifDoc.data();
      if (data.fcmSent === true) continue;

      const senderId = data.senderId || data.data?.senderId || null;

      const fcmDataPayload = {
        notificationId: String(notificationId),
        type: String(data.type || 'general'),
      };

      const topLevelFields = ['chatId', 'requestId', 'bloodType', 'hospital', 'phone',
                               'patientName', 'collection', 'targetRole', 'imageUrl',
                               'donationId', 'senderName', 'senderId'];
      topLevelFields.forEach(key => {
        if (data[key] != null) fcmDataPayload[key] = String(data[key]);
      });

      if (data.data && typeof data.data === 'object') {
        for (const [key, value] of Object.entries(data.data)) {
          if (value != null && fcmDataPayload[key] === undefined) {
            fcmDataPayload[key] = String(value);
          }
        }
      }

      const notification = {
        title: data.title || 'جمعية ناس الخير',
        body: data.body || '',
      };

      let targetTokens = [];

      if (data.userId) {
        if (senderId && senderId === data.userId) {
          await db.collection('notifications').doc(notificationId).update({ fcmSent: true });
          continue;
        }
        const userDoc = await db.collection('users').doc(data.userId).get();
        if (userDoc.exists) targetTokens = extractTokens(userDoc.data());
      } else if (data.targetRole) {
        let query = db.collection('users');
        if (data.targetRole === 'admin') {
          query = query.where('role', 'in', ['admin', 'superAdmin', 'superadmin']);
        } else if (data.targetRole !== 'all') {
          query = query.where('role', '==', data.targetRole);
        }
        const usersSnap = await query.get();
        usersSnap.forEach(userDoc => {
          if (userDoc.id === senderId) return;
          if (data.excludeUserId && userDoc.id === data.excludeUserId) return;
          targetTokens.push(...extractTokens(userDoc.data()));
        });
      } else {
        await db.collection('notifications').doc(notificationId).update({ fcmSent: true });
        continue;
      }

      await sendFCMWithRetry(targetTokens, notification, fcmDataPayload);
      await db.collection('notifications').doc(notificationId).update({
        fcmSent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      processed++;
    }

    return res.status(200).json({ message: `تم معالجة ${processed} إشعار`, processed });
  } catch (err) {
    console.error('❌ خطأ في /process-pending:', err.message);
    return res.status(500).json({ error: err.message });
  }
});

module.exports = app;

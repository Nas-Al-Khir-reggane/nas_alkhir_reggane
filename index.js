const admin = require('firebase-admin');
const express = require('express');
const app = express();

app.use(express.json());

const PORT = process.env.PORT || 3000;

// ======================================================
// إعداد Firebase Admin
// ======================================================
let serviceAccount;
try {
  console.log("🛠️ محاولة قراءة FIREBASE_CONFIG...");
  if (process.env.FIREBASE_CONFIG) {
    serviceAccount = JSON.parse(process.env.FIREBASE_CONFIG);
    console.log("✅ تم تحليل FIREBASE_CONFIG بنجاح.");
  } else {
    console.log("ℹ️ لم يتم العثور على FIREBASE_CONFIG، محاولة قراءة الملف المحلي...");
    serviceAccount = require('./serviceAccountKey.json');
  }
} catch (e) {
  console.error("❌ خطأ فادح في معالجة إعدادات Firebase:");
  console.error(e.message);
  console.error("💡 تأكد من أن محتوى FIREBASE_CONFIG في Render هو نص JSON سليم (يبدأ بـ { وينتهي بـ }).");
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
// Keep-Alive (Free Tier)
// ======================================================
const APP_URL = 'https://nas-alkhir-reggane.onrender.com';
app.get('/', (req, res) => res.send('🚀 خادم إشعارات "ناس الخير" يعمل بنجاح!'));

setInterval(() => {
  const http = require('http');
  console.log('📡 Keep-Alive: Pinging server...');
  http.get(APP_URL, (res) => {
    console.log(`📡 Keep-Alive Status: ${res.statusCode}`);
  }).on('error', (err) => {
    console.error('❌ Keep-Alive Error:', err.message);
  });
}, 10 * 60 * 1000);

// ======================================================
// دالة مساعدة: استخراج كل توكنات المستخدم
// ======================================================
function extractTokens(userData) {
  const tokens = new Set();

  // الحقل الجديد (مصفوفة)
  if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
    userData.fcmTokens.forEach(t => {
      if (t && typeof t === 'string' && t.length > 10) tokens.add(t);
    });
  }

  // الحقل القديم – للتوافق مع المستخدمين الذين لم يُحدِّثوا التطبيق بعد
  if (userData.fcmToken && typeof userData.fcmToken === 'string' && userData.fcmToken.length > 10) {
    tokens.add(userData.fcmToken);
  }

  return [...tokens];
}

// ======================================================
// دالة مساعدة: إرسال FCM مع تنظيف التوكنات الميتة
// ======================================================
async function sendFCM(tokens, notification, dataPayload) {
  if (!tokens || tokens.length === 0) {
    console.log('⚠️ لا توجد توكنات صالحة للإرسال.');
    return;
  }

  const uniqueTokens = [...new Set(tokens)];
  console.log(`📨 إرسال إلى ${uniqueTokens.length} جهاز...`);

  // ⚠️ نستخدم data-only message (بدون حقل notification)
  // لكي يتحكم التطبيق بالكامل في عرض الإشعار ولا يعرض النظام إشعاراً مزدوجاً
  const enrichedData = {
    ...dataPayload,
    title: notification.title || 'جمعية ناس الخير',
    body: notification.body || '',
  };

  const message = {
    data: enrichedData,
    android: {
      priority: 'high',
    },
    apns: {
      payload: { aps: { contentAvailable: true, 'mutable-content': 1 } },
      headers: { 'apns-priority': '10' },
    },
  };

  const deadTokens = [];

  if (uniqueTokens.length === 1) {
    try {
      await fcm.send({ ...message, token: uniqueTokens[0] });
      console.log('✅ تم إرسال الإشعار بنجاح.');
    } catch (err) {
      console.error('❌ فشل الإرسال:', err.message);
      if (err.code === 'messaging/registration-token-not-registered' ||
          err.code === 'messaging/invalid-registration-token') {
        deadTokens.push(uniqueTokens[0]);
      }
    }
  } else {
    // تقسيم التوكنات على دفعات من 500
    for (let i = 0; i < uniqueTokens.length; i += 500) {
      const batch = uniqueTokens.slice(i, i + 500);
      try {
        const response = await fcm.sendEachForMulticast({ ...message, tokens: batch });
        console.log(`✅ نجح: ${response.successCount}, فشل: ${response.failureCount} من ${batch.length}`);

        // جمع التوكنات المعطلة لحذفها
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
      }
    }
  }

  // تنظيف التوكنات الميتة من Firestore
  if (deadTokens.length > 0) {
    console.log(`🧹 حذف ${deadTokens.length} توكن منتهي الصلاحية...`);
    try {
      const usersSnap = await db.collection('users').get();
      const batch = db.batch();
      usersSnap.forEach(doc => {
        const data = doc.data();
        const tokens = extractTokens(data);
        const hasDeadToken = deadTokens.some(dead => tokens.includes(dead));
        if (hasDeadToken) {
          const updates = {};
          if (deadTokens.includes(data.fcmToken)) {
            updates.fcmToken = admin.firestore.FieldValue.delete();
          }
          if (data.fcmTokens) {
            updates.fcmTokens = admin.firestore.FieldValue.arrayRemove(...deadTokens);
          }
          if (Object.keys(updates).length > 0) {
            batch.update(doc.ref, updates);
          }
        }
      });
      await batch.commit();
    } catch (e) {
      console.error('⚠️ خطأ في تنظيف التوكنات الميتة:', e.message);
    }
  }
}

// ======================================================
// ذاكرة مؤقتة لمنع التكرار (idempotency)
// ======================================================
const processedNotifications = new Set();
setInterval(() => {
  processedNotifications.clear();
  console.log('🧹 تم تنظيف الذاكرة المؤقتة للإشعارات.');
}, 60 * 60 * 1000);

// ======================================================
// مراقبة Firestore → إرسال FCM
// ======================================================
db.collection('notifications').onSnapshot(snapshot => {
  snapshot.docChanges().forEach(async (change) => {
    if (change.type !== 'added') return;

    const notificationId = change.doc.id;
    const data = change.doc.data();

    // منع التكرار
    if (data.fcmSent === true) return;
    if (processedNotifications.has(notificationId)) return;
    processedNotifications.add(notificationId);

    try {
      const senderId = data.senderId || data.data?.senderId || null;

      // تجهيز payload البيانات (FCM يطلب قيماً نصية فقط)
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
        // لا نرسل للمرسل نفسه
        if (senderId && senderId === data.userId) {
          console.log(`⏭️ تخطي: إشعار ذاتي للمستخدم ${data.userId}`);
          await db.collection('notifications').doc(notificationId).update({ fcmSent: true });
          return;
        }

        const userDoc = await db.collection('users').doc(data.userId).get();
        if (userDoc.exists) {
          targetTokens = extractTokens(userDoc.data());
        } else {
          console.log(`⚠️ المستخدم ${data.userId} غير موجود في قاعدة البيانات.`);
        }

      // ── ب: إشعار جماعي (targetRole) ─────────────────────
      } else if (data.targetRole) {
        let query = db.collection('users');

        if (data.targetRole === 'admin') {
          query = query.where('role', 'in', ['admin', 'superAdmin', 'superadmin']);
        } else if (data.targetRole !== 'all') {
          query = query.where('role', '==', data.targetRole);
        }

        const usersSnap = await query.get();
        usersSnap.forEach(userDoc => {
          // استثناء المرسل
          if (userDoc.id === senderId) return;
          // استثناء مستخدم محدد إضافاً (excludeUserId)
          if (data.excludeUserId && userDoc.id === data.excludeUserId) return;
          targetTokens.push(...extractTokens(userDoc.data()));
        });

        console.log(`ℹ️ [${data.targetRole}] تجميع ${targetTokens.length} توكن (بعد استثناء المرسل).`);
      } else {
        console.log(`⚠️ وثيقة إشعار (${notificationId}) لا تحتوي userId ولا targetRole. تجاهل.`);
        await db.collection('notifications').doc(notificationId).update({ fcmSent: true });
        return;
      }

      // إرسال FCM
      await sendFCM(targetTokens, notification, fcmDataPayload);

      // تحديث الوثيقة كـ "تم الإرسال"
      await db.collection('notifications').doc(notificationId).update({
        fcmSent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    } catch (err) {
      console.error(`❌ خطأ في معالجة الإشعار (${notificationId}):`, err.message);
      // إعادة الإشعار للقائمة للمحاولة مجدداً في الدقيقة القادمة
      processedNotifications.delete(notificationId);
    }
  });
});

// ======================================================
// تشغيل السيرفر
// ======================================================
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🌍 السيرفر يعمل الآن على المنفذ: ${PORT}`);
});

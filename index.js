const admin = require('firebase-admin');
const express = require('express');
const app = express();

app.use(express.json());

const PORT = process.env.PORT || 3000;

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

// سيرفر بسيط لإبقاء الخدمة تعمل
const APP_URL = 'https://nas-alkhir-reggane.onrender.com'; // سيتم تحديثه تلقائياً إذا تغير

app.get('/', (req, res) => res.send('🚀 خادم إشعارات "ناس الخير" يعمل بنجاح سحابياً!'));

// سكريبت Keep-Alive لمنع Render من النوم (Free Tier)
setInterval(() => {
  const http = require('http');
  console.log('📡 Keep-Alive: Pinging server...');
  http.get(APP_URL, (res) => {
    console.log(`📡 Keep-Alive Status: ${res.statusCode}`);
  }).on('error', (err) => {
    console.error('❌ Keep-Alive Error:', err.message);
  });
}, 10 * 60 * 1000); // كل 10 دقائق

app.post('/send-emergency', async (req, res) => {
  const { title, body } = req.body;
  const message = {
    notification: { title, body },
    android: {
      priority: 'high',
      notification: {
        sound: 'default'
      }
    },
    apns: {
      payload: {
        aps: {
          contentAvailable: true,
          sound: 'default'
        },
      },
      headers: {
        'apns-priority': '10',
      },
    },
    topic: 'emergencies' // الإرسال لجميع المشتركين في هذا الموضوع
  };

  try {
    const response = await fcm.send(message);
    console.log('✅ تم إرسال بلاغ طوارئ جماعي للمشتركين:', response);
    res.status(200).send('تم إرسال البلاغ الجماعي بنجاح');
  } catch (error) {
    console.error('❌ خطأ في إرسال البلاغ الجماعي:', error);
    res.status(500).send(error.message);
  }
});

// ذاكرة مؤقتة لمنع سباق البيانات (Race Condition) والتكرار
const processedNotifications = new Set();
// تنظيف الذاكرة المؤقتة كل ساعة لمنع استهلاك الذاكرة بشكل مستمر
setInterval(() => processedNotifications.clear(), 60 * 60 * 1000);

// مراقبة Firestore لإرسال الإشعارات التلقائية
db.collection('notifications').onSnapshot(snapshot => {
  snapshot.docChanges().forEach(async (change) => {
    if (change.type === 'added') {
      const notificationId = change.doc.id;
      const data = change.doc.data();

      // 1. منع تكرار الإرسال
      if (data.fcmSent === true || processedNotifications.has(notificationId)) return;
      
      processedNotifications.add(notificationId);

      try {
        const senderId = data.senderId || (data.data && data.data.senderId);

        // تجهيز بيانات FCM
        let fcmDataPayload = {
          type: String(data.type || 'general'),
          notificationId: String(notificationId)
        };

        if (data.data && typeof data.data === 'object') {
           for (const [key, value] of Object.entries(data.data)) {
              if (value !== null && value !== undefined) fcmDataPayload[key] = String(value);
           }
        }
        ['chatId', 'requestId', 'bloodType', 'hospital', 'phone', 'patientName', 'collection', 'targetRole'].forEach(key => {
           if (data[key] !== null && data[key] !== undefined) fcmDataPayload[key] = String(data[key]);
        });
        if (data.imageUrl || (data.data && data.data.imageUrl)) {
            fcmDataPayload.imageUrl = String(data.imageUrl || data.data.imageUrl);
        }

        let targetTokens = [];

        if (data.userId) {
          // أ- إشعار موجه لشخص واحد محدد
          if (senderId && senderId === data.userId) {
            console.log(`ℹ️ تخطي الإشعار الفردي لأنه موجه لنفس المرسل (${data.userId})`);
            await db.collection('notifications').doc(notificationId).update({ fcmSent: true });
            return;
          }
          const userDoc = await db.collection('users').doc(data.userId).get();
          if (userDoc.exists && userDoc.data().fcmToken) {
             targetTokens.push(userDoc.data().fcmToken);
          }
        } else if (data.targetRole) {
          // ب- إشعار موجه لمجموعة (role أو all)
          let usersQuery = db.collection('users');
          
          if (data.targetRole !== 'all') {
            if (data.targetRole === 'admin') {
              usersQuery = usersQuery.where('role', 'in', ['admin', 'superAdmin', 'superadmin']);
            } else {
              usersQuery = usersQuery.where('role', '==', data.targetRole);
            }
          }
          
          const usersSnap = await usersQuery.get();
          usersSnap.forEach(userDoc => {
             const userData = userDoc.data();
             // استثناء المرسل نفسه أو من لا يملك توكن
             if (userData.fcmToken && userDoc.id !== senderId) {
                targetTokens.push(userData.fcmToken);
             }
          });
          
          if (targetTokens.length > 0) {
            console.log(`ℹ️ تم تجميع ${targetTokens.length} توكن للمجموعة ${data.targetRole}`);
          }
        }

        // إرسال الإشعارات لمن لديه توكن
        if (targetTokens.length > 0) {
          const message = {
            notification: { title: data.title, body: data.body },
            data: fcmDataPayload,
          };
          
          if (targetTokens.length === 1) {
            message.token = targetTokens[0];
            await fcm.send(message);
          } else {
            // إرسال جماعي (يصل إلى 500 توكن في المرة الواحدة)
            message.tokens = targetTokens.slice(0, 500);
            await fcm.sendEachForMulticast(message);
          }

          console.log(`✅ تم رسال الإشعار لـ ${targetTokens.length} مستخدم/مستخدمين.`);
        } else {
          console.log(`⚠️ لم يتم إرسال الإشعار لأنه لا توجد توكنز مستهدفة صالحة.`);
        }

        // تحديث الوثيقة كمنتهية
        await db.collection('notifications').doc(notificationId).update({
          fcmSent: true,
          sentAt: admin.firestore.FieldValue.serverTimestamp()
        });

      } catch (err) {
        console.error("❌ خطأ أثناء معالجة إشعار Firestore:", err.message);
        processedNotifications.delete(notificationId);
      }
    }
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🌍 السيرفر يعمل الآن على المنفذ: ${PORT}`);
});

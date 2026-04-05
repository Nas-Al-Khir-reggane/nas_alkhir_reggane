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

// مراقبة Firestore لإرسال الإشعارات التلقائية
db.collection('notifications').onSnapshot(snapshot => {
  snapshot.docChanges().forEach(async (change) => {
    if (change.type === 'added') {
      const data = change.doc.data();

      // 1. منع تكرار الإرسال
      if (data.fcmSent === true) return;

      try {
        // 2. جلب توكن المستخدم المستهدف
        const userDoc = await db.collection('users').doc(data.userId).get();
        if (userDoc.exists && userDoc.data().fcmToken) {

          // 3. التحقق من أن المرسل ليس هو نفسه المستلم (إذا كان الحقل متوفراً)
          // ملاحظة: الحقل senderId يجب أن يكون موجوداً في وثيقة الإشعار في Firestore
          if (data.senderId && data.senderId === data.userId) {
            console.log(`ℹ️ تخطي الإشعار لأن المرسل هو نفسه المستلم (${data.userId})`);
            return;
          }

          const message = {
            notification: { title: data.title, body: data.body },
            token: userDoc.data().fcmToken,
            data: {
              type: data.type || 'general',
              notificationId: change.doc.id // لمعرفه هوية الإشعار ومنع التكرار في الهاتف
            }
          };
          await fcm.send(message);

          // تحديث الوثيقة فوراً لمنع أي Snapshot آخر من معالجتها
          await db.collection('notifications').doc(change.doc.id).update({
            fcmSent: true,
            sentAt: admin.firestore.FieldValue.serverTimestamp()
          });

          console.log(`✅ تم إرسال إشعار للمستخدم ${data.userId}`);
        }
      } catch (err) {
        console.error("❌ خطأ أثناء معالجة إشعار Firestore:", err.message);
      }
    }
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🌍 السيرفر يعمل الآن على المنفذ: ${PORT}`);
});

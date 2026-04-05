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

      // 1. منع تكرار الإرسال عبر الذاكرة المؤقتة والحالة في قاعدة البيانات
      if (data.fcmSent === true || processedNotifications.has(notificationId)) return;
      
      processedNotifications.add(notificationId);

      try {
        // 2. التحقق من أن المرسل ليس هو نفسه المستلم (منع الإشعارات الذاتية)
        const senderId = data.senderId || (data.data && data.data.senderId); // قد يكون داخل خريطة data
        if (senderId && senderId === data.userId) {
          console.log(`ℹ️ تخطي الإشعار لأن المرسل هو نفسه المستلم (${data.userId})`);
          // تحديث الحالة حتى لا يتم معالجته لاحقاً
          await db.collection('notifications').doc(notificationId).update({ fcmSent: true });
          return;
        }

        // 3. جلب توكن المستخدم المستهدف
        const userDoc = await db.collection('users').doc(data.userId).get();
        if (userDoc.exists && userDoc.data().fcmToken) {
          
          // تجهيز بيانات FCM. يجب أن تكون كل القيم من نوع String
          let fcmDataPayload = {
            type: data.type || 'general',
            notificationId: notificationId
          };

          // نقل كل البيانات الموجودة في الجذر أو في حقل data إلى الـ payload
          if (data.data && typeof data.data === 'object') {
             for (const [key, value] of Object.entries(data.data)) {
                if (value !== null && value !== undefined) {
                   fcmDataPayload[key] = String(value);
                }
             }
          }
          // إضافة الحقول المباشرة إذا لزم الأمر
          ['chatId', 'requestId', 'bloodType', 'hospital', 'phone', 'patientName', 'collection', 'targetRole'].forEach(key => {
             if (data[key] !== null && data[key] !== undefined) {
                 fcmDataPayload[key] = String(data[key]);
             }
          });

          // إضافة imageUrl لتفعيل الإشعارات المصورة
          if (data.imageUrl || (data.data && data.data.imageUrl)) {
              fcmDataPayload.imageUrl = String(data.imageUrl || data.data.imageUrl);
          }

          const message = {
            notification: { title: data.title, body: data.body },
            token: userDoc.data().fcmToken,
            data: fcmDataPayload
          };
          
          await fcm.send(message);

          // تحديث الوثيقة في قاعدة البيانات
          await db.collection('notifications').doc(notificationId).update({
            fcmSent: true,
            sentAt: admin.firestore.FieldValue.serverTimestamp()
          });

          console.log(`✅ تم إرسال إشعار للمستخدم ${data.userId}`);
        } else {
           // المتلقي لا يملك توكن (مستخدم غير مسجل الدخول ربما)، نسجلها كـ sent لتفادي محاولة إرسالها كل مرة
           await db.collection('notifications').doc(notificationId).update({ fcmSent: true });
        }
      } catch (err) {
        console.error("❌ خطأ أثناء معالجة إشعار Firestore:", err.message);
        processedNotifications.delete(notificationId); // إزالة من الذاكرة في حالة الخطأ لإعادة المحاولة لاحقاً
      }
    }
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🌍 السيرفر يعمل الآن على المنفذ: ${PORT}`);
});

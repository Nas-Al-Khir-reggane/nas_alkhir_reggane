const admin = require('firebase-admin');
const express = require('express');
const app = express();

// 1. إعداد منفذ للسيرفر (مطلوب للمنصات السحابية)
const PORT = process.env.PORT || 3000;

// 2. قراءة بيانات شهادة Firebase من متغير بيئة FIREBASE_CONFIG أو من الملف المحلي
let serviceAccount;
try {
  if (process.env.FIREBASE_CONFIG) {
    serviceAccount = JSON.parse(process.env.FIREBASE_CONFIG);
  } else {
    serviceAccount = require('./serviceAccountKey.json');
  }
} catch (e) {
  console.error("❌ فشل في تحميل ملف مفتاح الخدمة! تأكد من إعداد FIREBASE_CONFIG بشكل صحيح كـ JSON.");
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
app.get('/', (req, res) => res.send('🚀 خادم إشعارات "ناس الخير" يعمل بنجاح 24/7'));
app.listen(PORT, () => console.log(`🌍 السيرفر يعمل على المنفذ: ${PORT}`));

console.log('📡 بدأت مراقبة قاعدة البيانات لإرسال الإشعارات الفورية...');

// مراقبة جدول الإشعارات (notifications) في Firestore
db.collection('notifications').onSnapshot(snapshot => {
  snapshot.docChanges().forEach(async (change) => {
    if (change.type === 'added') {
      const data = change.doc.data();

      // إذا كان الإشعار قد تم إرساله مسبقاً عبر FCM، نتخطاه
      if (data.fcmSent === true) return;

      const userId = data.userId;
      const title = data.title || 'تنبيه من ناس الخير';
      const body = data.body || 'لديك إشعار جديد';

      try {
        // جلب توكن المستخدم من جدول الـ users
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists) {
          console.log(`⚠️ المستخدم ${userId} غير موجود.`);
          return;
        }

        const registrationToken = userDoc.data().fcmToken;
        if (!registrationToken) {
          console.log(`⚠️ لا يوجد FCM Token للمستخدم ${userId}`);
          return;
        }

        const message = {
          notification: { title, body },
          data: {
            type: data.type || 'general',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            ...Object.keys(data.data || {}).reduce((acc, key) => {
               acc[key] = String(data.data[key]);
               return acc;
            }, {})
          },
          android: {
            priority: 'high',
            notification: {
              sound: 'default',
              channelId: 'nas_alkhair_v2'
            }
          },
          token: registrationToken
        };

        // إرسال الإشعار
        const response = await fcm.send(message);
        console.log(`✅ تم إرسال إشعار ("${title}") للمستخدم ${userId} بنجاح.`);

        // تحديث حالة الإشعار في Firestore لعدم تكرار الإرسال
        await db.collection('notifications').doc(change.doc.id).update({
          fcmSent: true,
          fcmResponse: response
        });

      } catch (error) {
        console.error('❌ خطأ في إرسال الإشعار:', error);
      }
    }
  });
});

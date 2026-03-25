import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import '../../firebase_options.dart';

class NotificationService extends GetxController {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  final RxInt unreadCount = 0.obs;
  StreamSubscription? _unreadSubscription;

  @override
  void onInit() {
    super.onInit();
    _startListeningToUnreadCount();
    // Listen for auth changes to restart listener
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _unreadSubscription?.cancel();
      if (user != null) {
        _startListeningToUnreadCount();
      } else {
        unreadCount.value = 0;
      }
    });
  }

  void _startListeningToUnreadCount() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _unreadSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      unreadCount.value = snapshot.docs.length;
    });
  }

  @override
  void onClose() {
    _unreadSubscription?.cancel();
    super.onClose();
  }

  static Future<void> init() async {
    try {
      // 1. تهيئة الإشعارات المحلية
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (details) => _onNotificationTap(details),
      );

      // السماح للمعالج بأخذ استراحة (تجنب تعليق الواجهة)
      await Future.delayed(const Duration(milliseconds: 100));

      // 2. إنشاء قناة الإشعارات
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'nas_al_kheir_channel',
        'جمعية ناس الخير',
        description: 'إشعارات جمعية ناس الخير',
        importance: Importance.high,
        playSound: true,
        enableLights: true,
        ledColor: Color(0xFF00C853),
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // استراحة قصيرة أخرى
      await Future.delayed(const Duration(milliseconds: 100));

      // 3. إعداد مستمعي FCM
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 4. طلب صلاحيات الإشعارات (يُفضل طلبها بعد استقرار الواجهة)
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // 5. الحصول على التوكن مع مهلة زمنية لعدم تعطيل التطبيق في حال ضعف الاتصال
      final token = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('FCM getToken timed out.');
          return null;
        },
      );
      if (token != null) await _saveToken(token);

      FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  static Future<void> _saveToken(String token) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'fcmToken': token,
        });
      } catch (e) {
        debugPrint('Error saving FCM token: $e');
      }
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      _notificationsPlugin.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'nas_al_kheir_channel',
            'جمعية ناس الخير',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFF00C853),
            enableLights: true,
            ledColor: Color(0xFF00C853),
            ledOnMs: 1000,
            ledOffMs: 500,
            playSound: true,
          ),
        ),
      );
    }
  }

  static void _handleBackgroundMessage(RemoteMessage message) {
    if (message.data['type'] == 'new_request') {
      Get.toNamed('/adminRequests');
    } else {
      Get.toNamed('/notifications');
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    // Navigate based on notification type
    Get.toNamed('/notifications');
  }

  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  // Send notification to a specific user
  static Future<void> sendNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': userId,
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Notify all admins
  static Future<void> notifyAllAdmins({
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final admins = await FirebaseFirestore.instance
        .collection('users')
        .where('role', whereIn: ['admin', 'superAdmin'])
        .where('isApproved', isEqualTo: true)
        .get();

    for (var admin in admins.docs) {
      await sendNotification(userId: admin.id, type: type, title: title, body: body, data: data);
    }
  }

  // Notify all workers
  static Future<void> notifyAllWorkers({required String title, required String body}) async {
    final workers = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .where('isApproved', isEqualTo: true)
        .get();
    
    for (var worker in workers.docs) {
      await sendNotification(userId: worker.id, type: 'announcement', title: title, body: body);
    }
  }

  Future<void> markAllAsRead() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final batch = FirebaseFirestore.instance.batch();
    final unread = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}

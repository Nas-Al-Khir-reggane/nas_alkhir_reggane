import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:io';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../../core/animations/sound_manager.dart';
import '../../firebase_options.dart';

class NotificationService extends GetxController {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  final RxInt unreadCount = 0.obs;
  StreamSubscription? _unreadSubscription;
  StreamSubscription? _newNotificationsSubscription;

  @override
  void onInit() {
    super.onInit();
    debugPrint('🔔 NotificationService: Controller Active');
    _initListeners();
    
    // اختبار النظام بعد 5 ثوانٍ من التشغيل
    Future.delayed(const Duration(seconds: 5), () {
      _showLocalNotification(
        title: 'نظام الإشعارات يعمل ✅',
        body: 'تم فحص الاتصال وتفعيل التنبيهات بنجاح',
      );
    });

    FirebaseAuth.instance.authStateChanges().listen((user) {
      _cleanupSubscriptions();
      if (user != null) {
        _initListeners();
        scheduleMonthlyReminders(); 
      } else {
        unreadCount.value = 0;
      }
    });
  }

  void _initListeners() {
    debugPrint('📡 NotificationService: Re-initializing Listeners...');
    _startListeningToUnreadCount();
    _startListeningToNewNotifications();
  }

  void _cleanupSubscriptions() {
    _unreadSubscription?.cancel();
    _newNotificationsSubscription?.cancel();
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
    }, onError: (error) {
      debugPrint('❌ Firestore Unread Error: $error');
      // محاولة إعادة الاتصال بعد 10 ثوانٍ في حال الفشل
      Future.delayed(const Duration(seconds: 10), () => _startListeningToUnreadCount());
    });
  }

  void _startListeningToNewNotifications() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // تم إزالة شرط الوقت الصارم للسماح باستقبال الإشعارات المتأخرة قليلاً
    _newNotificationsSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(1) // نراقب آخر إشعار فقط
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data() as Map<String, dynamic>;
              
              debugPrint('🔔 New Internal Notification Detected: ${data['title']}');
              _showLocalNotification(
                title: data['title'] ?? 'إشعار جديد',
                body: data['body'] ?? '',
                payload: data['type'] ?? '',
              );
              
              try {
                 Get.find<SoundManager>().playNotification();
              } catch (_) {}
            }
          }
        }, onError: (error) {
          debugPrint('❌ Firestore Stream Error: $error');
          // إعادة الاتصال التلقائي
          Future.delayed(const Duration(seconds: 15), () => _startListeningToNewNotifications());
        });
  }

  void _showLocalNotification({required String title, required String body, String? payload}) {
    _notificationsPlugin.show(
      id: title.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'nas_al_kheir_channel',
          'جمعية ناس الخير',
          channelDescription: 'إشعارات جمعية ناس الخير',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          color: const Color(0xFF00C853),
          playSound: true,
          enableLights: true,
          ledColor: const Color(0xFF00C853),
          ledOnMs: 1000,
          ledOffMs: 500,
          showWhen: true,
          ticker: 'ناس الخير',
          subText: 'جمعية ناس الخير',
          styleInformation: BigTextStyleInformation(
            body,
            htmlFormatBigText: false,
            contentTitle: title,
            htmlFormatContentTitle: false,
            summaryText: 'ناس الخير',
            htmlFormatSummaryText: false,
          ),
        ),
      ),
      payload: payload,
    );
  }

  @override
  void onClose() {
    _cleanupSubscriptions();
    super.onClose();
  }

  static Future<void> init() async {
    try {
      debugPrint('🚀 NotificationService: Global Init');
      
      // طلب الإذن (سيعيد true مباشرة لأنك وافقت مسبقاً)
      await FirebaseMessaging.instance.requestPermission();

      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.requestNotificationsPermission();
      }

      tz.initializeTimeZones(); 
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // إنشاء القناة بوضعية Importance.max لضمان الظهور
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'nas_al_kheir_channel',
        'جمعية ناس الخير',
        description: 'إشعارات جمعية ناس الخير',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('🔑 Token Verified: $token');
      if (token != null) await _saveToken(token);

    } catch (e) {
      debugPrint('❌ Init Error: $e');
    }
  }

  static Future<void> _saveToken(String token) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {}
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('🔔 FCM Foreground: ${message.notification?.title}');
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
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
            playSound: true,
          ),
        ),
      );
    }
  }

  static void _handleBackgroundMessage(RemoteMessage message) {
    Get.toNamed(message.data['type'] == 'new_request' ? '/adminRequests' : '/notifications');
  }

  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload ?? '';
    if (payload.startsWith('{')) {
      try {
        // Here we could parse JSON if we had a library, 
        // but for simplicity we can check for key markers
        if (payload.contains('new_request') || payload.contains('requestId')) {
           Get.toNamed('/admin/requests'); // We can improve this if we have a way to pass arguments
        } else {
          Get.toNamed('/notifications');
        }
      } catch (e) {
        Get.toNamed('/notifications');
      }
    } else if (payload == 'new_request') {
      Get.toNamed('/admin/requests');
    } else {
      Get.toNamed('/notifications');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  Future<void> scheduleMonthlyReminders() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final subscriptions = await FirebaseFirestore.instance
          .collection('donations')
          .where('donorId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .get();

      for (var doc in subscriptions.docs) {
        final projectId = doc['projectId'] as String;
        final projectDoc = await FirebaseFirestore.instance.collection('projects').doc(projectId).get();
        if (projectDoc.exists && (projectDoc.data()?['isSubscription'] ?? false)) {
          await _notificationsPlugin.zonedSchedule(
            id: projectId.hashCode,
            title: 'تذكير بالمساهمة الشهرية 💎',
            body: 'أخي المتبرع، موعد مساهمتك لـ [${projectDoc.data()?['name']}] حان',
            scheduledDate: _nextInstanceOfFirstOfMonth(),
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails('monthly_reminders', 'التذكيرات'),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
          );
        }
      }
    } catch (e) {}
  }

  tz.TZDateTime _nextInstanceOfFirstOfMonth() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, 1, 10);
    if (scheduled.isBefore(now)) scheduled = tz.TZDateTime(tz.local, now.year, now.month + 1, 1, 10);
    return scheduled;
  }

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
      'data': data ?? {},
      // نسخ حقول البيانات الهامة إلى المستوى الأعلى لسهولة التنقل
      if (data != null && data['requestId'] != null) 'requestId': data['requestId'],
      if (data != null && data['collection'] != null) 'collection': data['collection'],
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> notifyAllAdmins({
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final admins = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: [
            'admin', 'superAdmin', 'super_admin', 'sub_admin', 'subAdmin', 
            'manager', 'general_manager', 'generalManager', 'director'
          ])
          .where('isApproved', isEqualTo: true)
          .get();
      for (var admin in admins.docs) {
        await sendNotification(userId: admin.id, type: type, title: title, body: body, data: data);
      }
    } catch (e) {}
  }

  static Future<void> notifyAllWorkers({required String title, required String body}) async {
    try {
      final workers = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'worker')
          .where('isApproved', isEqualTo: true)
          .get();
      for (var worker in workers.docs) {
        await sendNotification(userId: worker.id, type: 'announcement', title: title, body: body);
      }
    } catch (e) {}
  }

  Future<void> markAllAsRead() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    try {
      final unread = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in unread.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {}
  }
}

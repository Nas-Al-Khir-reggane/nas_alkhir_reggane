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
  final DateTime _sessionStartTime = DateTime.now().subtract(const Duration(minutes: 2));
  
  final RxInt unreadCount = 0.obs;
  StreamSubscription? _unreadSubscription;
  StreamSubscription? _newNotificationsSubscription;

  @override
  void onInit() {
    super.onInit();
    debugPrint('🔔 NotificationService: Controller Active');
    _initListeners();
    
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
              final Timestamp? createdAt = data['createdAt'] as Timestamp?;
              
              // اجتياز الإشعارات القديمة لتجنب تكرار التنبيه عند فتح التطبيق
              if (createdAt != null && createdAt.toDate().isBefore(_sessionStartTime)) {
                continue;
              }

              debugPrint('🔔 New Internal Notification Detected: ${data['title']}');
              String payload = data['type'] ?? '';
              
              // التحقق من وجود بيانات الدردشة سواء في المستوى الأعلى أو داخل خريطة data
              final String? chatId = data['chatId'] ?? data['data']?['chatId'];
              final String? senderName = data['senderName'] ?? data['data']?['senderName'];
              final String? senderId = data['senderId'] ?? data['data']?['senderId'];

              if (chatId != null) {
                payload = 'chatId:$chatId,userName:${senderName ?? ""},targetUserId:${senderId ?? ""}';
              }

              _showLocalNotification(
                title: data['title'] ?? 'إشعار جديد',
                body: data['body'] ?? '',
                payload: payload,
              );
              
              try {
                 Get.find<SoundManager>().playNotification();
              } catch (e) {
                debugPrint('❌ [NotificationService] Sound error: $e');
              }
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
          icon: '@mipmap/launcher_icon',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
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
      const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
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
      } catch (e) {
        debugPrint('❌ [NotificationService] Save token error: $e');
      }
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
            icon: '@mipmap/launcher_icon',
            playSound: true,
          ),
        ),
      );
    }
  }

  static void _handleBackgroundMessage(RemoteMessage message) {
    final data = message.data;
    if (data['chatId'] != null) {
      Get.toNamed('/chat/private', arguments: {
        'chatId': data['chatId'],
        'userName': data['senderName'] ?? 'محادثة',
        'userId': data['senderId']
      });
    } else if (data['type'] == 'new_request' || data['requestId'] != null) {
      Get.toNamed('/admin/requests');
    } else {
      Get.toNamed('/notifications');
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload ?? '';
    if (payload.isEmpty) {
      Get.toNamed('/notifications');
      return;
    }

    try {
      if (payload.contains('chatId')) {
        // Simple manual parsing or use jsonDecode if available
        // Expected format: chatId:xxx,userName:yyy,targetUserId:zzz
        final parts = payload.split(',');
        String? chatId, userName, targetUserId;
        for (var part in parts) {
           if (part.startsWith('chatId:')) chatId = part.split(':')[1];
           if (part.startsWith('userName:')) userName = part.split(':')[1];
           if (part.startsWith('targetUserId:')) targetUserId = part.split(':')[1];
        }
        
        if (chatId != null) {
          Get.toNamed('/chat/private', arguments: {
            'chatId': chatId,
            'userName': userName ?? 'محادثة',
            'userId': targetUserId
          });
          return;
        }
      }

      if (payload == 'new_request' || payload.contains('requestId')) {
        Get.toNamed('/admin/requests');
      } else {
        Get.toNamed('/notifications');
      }
    } catch (e) {
      debugPrint('❌ Notification Tap Error: $e');
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
    } catch (e) {
      debugPrint('❌ [NotificationService] scheduleMonthlyReminders error: $e');
    }
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
      // نسخ حقول البيانات الهامة إلى المستوى الأعلى لسهولة التنقل والوصول من المشغلات الخلفية
      if (data != null && data['chatId'] != null) 'chatId': data['chatId'],
      if (data != null && data['senderId'] != null) 'senderId': data['senderId'],
      if (data != null && data['senderName'] != null) 'senderName': data['senderName'],
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
    String? excludeUserId,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      // منع الزوار من البحث في قائمة العمال/المديرين (تجنباً لـ PERMISSION_DENIED)
      if (currentUser == null || currentUser.isAnonymous) {
        debugPrint('ℹ️ NotificationService: Skipping admin query for Guest/Unauthenticated user.');
        return;
      }

      debugPrint('🔔 NotificationService: Notifying all admins - $title');
      
      // نستخدم تنويعات متعددة لأسماء الأدوار لضمان التوافق مع البيانات القديمة والـ Enums الجديدة 
      final admins = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['admin', 'superAdmin', 'superadmin'])
          .where('isApproved', isEqualTo: true)
          .get();

      debugPrint('👥 NotificationService: Found ${admins.docs.length} admins to notify');
      
      for (var admin in admins.docs) {
        if (excludeUserId != null && admin.id == excludeUserId) continue;
        await sendNotification(userId: admin.id, type: type, title: title, body: body, data: data);
      }
    } catch (e) {
      debugPrint('❌ [NotificationService] notifyAllAdmins error: $e');
    }
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
    } catch (e) {
      debugPrint('❌ [NotificationService] notifyAllWorkers error: $e');
    }
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
    } catch (e) {
      debugPrint('❌ [NotificationService] markAllAsRead error: $e');
    }
  }

  Future<void> deleteNotification(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').doc(docId).delete();
    } catch (e) {
      debugPrint('❌ [NotificationService] deleteNotification error: $e');
    }
  }

  Future<void> deleteAllRead() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    try {
      final read = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: true)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in read.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('❌ [NotificationService] deleteAllRead error: $e');
    }
  }
}

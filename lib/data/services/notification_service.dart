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
import '../../features/auth/controllers/auth_controller.dart';
import '../models/user_model.dart';
import '../../firebase_options.dart';

class NotificationService extends GetxController {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final RxInt unreadCount = 0.obs;
  final List<StreamSubscription> _subscriptions = [];
  final Set<String> _processedIds = {}; // 🆕 تتبع معرفات التنبيهات المعالجة في الجلسة لمنع التكرار
  DateTime _sessionStartTime = DateTime.now().subtract(const Duration(seconds: 30)); // تقليل المدة الابتدائية

  @override
  void onInit() {
    super.onInit();
    
    final AuthController authController = Get.find<AuthController>();

    // الاشتراك الذكي: لا نعيد تشغيل المستمعين إلا إذا تغير المعرف أو الرتبة فعلياً
    // هذا يمنع التكرار اللانهائي الناتج عن تحديث النبضة القلبية (Heartbeat) في AuthController
    String? lastUid;
    UserRole? lastRole;

    ever(authController.currentUser, (UserModel? user) {
      if (user != null) {
        if (user.id != lastUid || user.role != lastRole) {
          debugPrint('🔄 NotificationService: User Identity Changed ($lastRole -> ${user.role}). Updating Listeners...');
          lastUid = user.id;
          lastRole = user.role;
          
          _cleanupSubscriptions();
          _initListeners();
          scheduleMonthlyReminders();
        }
      }
    });

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _cleanupSubscriptions();
        unreadCount.value = 0;
      }
    });
  }

  void _initListeners() {
    debugPrint('📡 NotificationService: Re-initializing Listeners...');
    _sessionStartTime = DateTime.now().subtract(const Duration(seconds: 5)); // تحديث وقت الجلسة عند كل إعادة تشغيل
    _startListeningToUnreadCount();
    _startListeningToNewNotifications();
  }

  void _cleanupSubscriptions() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _processedIds.clear(); // 🆕 تصفير المعرفات عند تبديل المستخدم أو تسجيل الخروج
  }

  void _startListeningToUnreadCount() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final AuthController authController = Get.find<AuthController>();
    final isAdmin = authController.currentUser.value?.role == UserRole.admin || 
                    authController.currentUser.value?.role == UserRole.superAdmin;

    final sub = FirebaseFirestore.instance
        .collection('notifications')
        .where(isAdmin 
          ? Filter.or(Filter('userId', isEqualTo: userId), Filter('targetRole', isEqualTo: 'admin'), Filter('targetRole', isEqualTo: 'all'))
          : Filter.or(Filter('userId', isEqualTo: userId), Filter('targetRole', isEqualTo: 'all')))
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      unreadCount.value = snapshot.docs.length;
    }, onError: (error) {
      debugPrint('❌ Firestore Unread Error: $error');
      Future.delayed(const Duration(seconds: 10), () => _startListeningToUnreadCount());
    });
    _subscriptions.add(sub);
  }

  void _startListeningToNewNotifications() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final AuthController authController = Get.find<AuthController>();
    final isAdmin = authController.currentUser.value?.role == UserRole.admin || 
                    authController.currentUser.value?.role == UserRole.superAdmin;

    // 1. الإشعارات الشخصية
    _listenToStream(FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(1));

    // 2. إشعارات المدراء (فقط للمدراء)
    if (isAdmin) {
      _listenToStream(FirebaseFirestore.instance
          .collection('notifications')
          .where('targetRole', isEqualTo: 'admin')
          .where('isRead', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(1));
    }

    // 3. الإشعارات العامة للجميع (مشاريع جديدة، إعلانات)
    _listenToStream(FirebaseFirestore.instance
        .collection('notifications')
        .where('targetRole', isEqualTo: 'all')
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(1));
  }


  void _listenToStream(Query query) {
    final subscription = query.snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final docId = change.doc.id;
          
          // 🆕 منع تكرار معالجة نفس التنبيه في نفس الجلسة
          if (_processedIds.contains(docId)) {
            continue;
          }

          final data = change.doc.data() as Map<String, dynamic>;
          final Timestamp? createdAt = data['createdAt'] as Timestamp?;
          
          if (createdAt != null && createdAt.toDate().isBefore(_sessionStartTime)) {
            continue;
          }

          debugPrint('🔔 New Notification: ${data['title']} (ID: $docId)');
          _processedIds.add(docId); // تعليم التنبيه كمعالج
          _processNotificationData(data);
        }
      }
    }, onError: (error) {
      debugPrint('❌ Notification Stream Error: $error');
    });

    _subscriptions.add(subscription);
  }

  void _processNotificationData(Map<String, dynamic> data) {
    String payload = data['type'] ?? '';
    
    final String? chatId = data['chatId'] ?? data['data']?['chatId'];
    final String? senderName = data['senderName'] ?? data['data']?['senderName'];
    final String? senderId = data['senderId'] ?? data['data']?['senderId'];

    if (chatId != null) {
      payload = 'chatId:$chatId,userName:${senderName ?? ""},targetUserId:${senderId ?? ""}';
    } else if (data['type'] == 'blood_emergency' || data['type'] == 'blood_encouragement') {
      final String? bloodType = data['bloodType'] ?? data['data']?['bloodType'];
      final String? hospital = data['hospital'] ?? data['data']?['hospital'];
      final String? requestId = data['requestId'] ?? data['data']?['requestId'];
      final String? phone = data['phone'] ?? data['data']?['phone'];
      final bool isGuest = (data['isGuest'] ?? data['data']?['isGuest']).toString() == 'true';
      payload = 'blood_emergency:reqId=$requestId,type=$bloodType,hosp=$hospital,ph=$phone,isGuest=$isGuest';
    } else if (data['type'] == 'donor_responding' || data['type'] == 'donor_confirmed') {
      final String? requestId = data['requestId'] ?? data['data']?['requestId'];
      final bool isGuest = (data['isGuest'] ?? data['data']?['isGuest']).toString() == 'true';
      payload = 'admin_request_detail:id=$requestId,isGuest=$isGuest';
    } else if (data['type'] == 'funeral_ghusl') {
      final String? requestId = data['requestId'] ?? data['data']?['requestId'];
      final String? gender = data['gender'] ?? data['data']?['gender'];
      final String? location = data['location'] ?? data['data']?['location'];
      final String? phone = data['phone'] ?? data['data']?['phone'];
      payload = 'funeral_ghusl:id=$requestId,gender=$gender,loc=$location,ph=$phone';
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

      // 6. محاولة جلب الرمز مع مهلة زمنية قصيرة (5 ثوانٍ) لمنع تعليق التطبيق في حال فشل خدمات جوجل
      try {
        final token = await FirebaseMessaging.instance.getToken().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('⚠️ [NotificationService] FCM Token fetch timed out.');
            return null;
          },
        );
        
        if (token != null) {
          debugPrint('🔑 Token Verified: $token');
          await _saveToken(token);
        } else {
          debugPrint('⚠️ [NotificationService] Could not retrieve FCM token (Google Play Services might be unavailable).');
        }
      } catch (e) {
        // معالجة خطأ SERVICE_NOT_AVAILABLE والتعامل معه بهدوء
        if (e.toString().contains('SERVICE_NOT_AVAILABLE')) {
          debugPrint('📶 [NotificationService] FCM Service not available on this device/connection. Continuing without token.');
        } else {
          debugPrint('❌ [NotificationService] Token Fetch Error: $e');
        }
      }

    } catch (e) {
      debugPrint('❌ Init Error: $e');
    }
  }

  static Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          if (user.isAnonymous) 'role': 'guest',
          if (user.isAnonymous) 'isApproved': true, // Guests are auto-approved for their limited scope
          'userId': user.uid,
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
    } else if (data['type'] == 'blood_emergency' || data['type'] == 'blood_encouragement') {
      Get.toNamed('/blood-emergency', arguments: {
        'requestId': data['requestId'],
        'bloodType': data['bloodType'],
        'hospital': data['hospital'],
        'phone': data['phone'],
        'isGuest': data['isGuest'] == 'true',
      });
    } else if (data['type'] == 'donor_responding' || data['type'] == 'donor_confirmed') {
      Get.toNamed('/admin/request-detail', arguments: {
        'requestId': data['requestId'],
        'isGuest': data['isGuest'] == 'true',
      });
    } else if (data['type'] == 'new_request' || (data['requestId'] != null && data['type'] != 'blood_emergency' && data['type'] != 'blood_encouragement')) {
      final AuthController auth = Get.find<AuthController>();
      if (auth.currentUser.value?.role == UserRole.admin || auth.currentUser.value?.role == UserRole.superAdmin) {
        Get.toNamed('/admin/requests');
      } else {
        Get.toNamed('/notifications');
      }
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

      if (payload.startsWith('blood_emergency:') || payload.startsWith('blood_encouragement:')) {
        final content = payload.split(':')[1];
        final parts = content.split(',');
        final map = <String, dynamic>{};
        for (var p in parts) {
          final kv = p.split('=');
          if (kv.length == 2) {
            if (kv[0] == 'reqId') map['requestId'] = kv[1];
            if (kv[0] == 'type') map['bloodType'] = kv[1];
            if (kv[0] == 'hosp') map['hospital'] = kv[1];
            if (kv[0] == 'ph') map['phone'] = kv[1];
            if (kv[0] == 'isGuest') map['isGuest'] = kv[1] == 'true';
          }
        }
        Get.toNamed('/blood-emergency', arguments: map);
        return;
      }

      if (payload.startsWith('admin_request_detail:')) {
        final content = payload.split(':')[1];
        final parts = content.split(',');
        final map = <String, dynamic>{};
        for (var p in parts) {
          final kv = p.split('=');
          if (kv.length == 2) {
             if (kv[0] == 'id') map['requestId'] = kv[1];
             if (kv[0] == 'isGuest') map['isGuest'] = kv[1] == 'true';
          }
        }
        Get.toNamed('/admin/request-detail', arguments: map);
        return;
      }

      final AuthController auth = Get.find<AuthController>();
      final bool isAdmin = auth.currentUser.value?.role == UserRole.admin || auth.currentUser.value?.role == UserRole.superAdmin;

      if ((payload == 'new_request' || payload.contains('requestId')) && isAdmin) {
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

  // إرسال إشعار عام للجميع (مثل إضافة مشروع جديد)
  static Future<void> notifyAll({
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'targetRole': 'all',
      'type': type,
      'title': title,
      'body': body,
      'data': data ?? {},
      if (data != null && data['requestId'] != null) 'requestId': data['requestId'],
      if (data != null && data['projectId'] != null) 'projectId': data['projectId'],
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
      
      // إذا كان المستخدم زائراً أو غير مسجل الدخول، سيرسل إشعاراً واحداً موجهاً "لكل الإدمن" (Broadcast)
      if (currentUser == null || currentUser.isAnonymous) {
        debugPrint('🔔 [Guest/NoAuth] NotificationService: Sending broadcast notification to admins');
        await FirebaseFirestore.instance.collection('notifications').add({
          'targetRole': 'admin', // موجه لكل من لديه رتبة إدمن
          'type': type,
          'title': title,
          'body': body,
          'data': data ?? {},
          'senderId': currentUser?.uid ?? 'guest',
          'senderName': data?['senderName'] ?? 'زائر',
          if (data != null && data['chatId'] != null) 'chatId': data['chatId'],
          if (data != null && data['requestId'] != null) 'requestId': data['requestId'],
          if (data != null && data['collection'] != null) 'collection': data['collection'],
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
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
      final AuthController authController = Get.find<AuthController>();
      final isAdmin = authController.currentUser.value?.role == UserRole.admin || 
                      authController.currentUser.value?.role == UserRole.superAdmin;

      final unread = await FirebaseFirestore.instance
          .collection('notifications')
          .where(isAdmin 
            ? Filter.or(Filter('userId', isEqualTo: userId), Filter('targetRole', isEqualTo: 'admin'), Filter('targetRole', isEqualTo: 'all'))
            : Filter.or(Filter('userId', isEqualTo: userId), Filter('targetRole', isEqualTo: 'all')))
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


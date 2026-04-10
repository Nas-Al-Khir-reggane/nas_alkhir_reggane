import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../features/auth/controllers/auth_controller.dart';
import '../models/user_model.dart';
import '../../firebase_options.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';

const String _notificationChannelId = 'nas_alkhair_v2';
const String _notificationChannelName = 'جمعية ناس الخير';

const String _chatChannelId = 'nas_alkhair_chats';
const String _chatChannelName = 'رسائل المحادثات';

const String _emergencyChannelId = 'nas_alkhair_emergency';
const String _emergencyChannelName = 'طوارئ واستغاثة';

class NotificationService extends GetxController {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static const String _notificationSoundName = 'notification';
  static const String _chatSoundName = 'new_message';
  static const String _emergencySoundName = 'siren';

  final RxInt unreadCount = 0.obs;
  final List<StreamSubscription> _subscriptions = [];
  final Set<String> _processedIds = {}; 
  final Set<String> _processedNotificationKeys = {}; 

  static UserRole? _currentUserRole() {
    try {
      return Get.find<AuthController>().currentUser.value?.role;
    } catch (_) {
      return null;
    }
  }

  static bool _isAdminRole(UserRole? role) {
    return role == UserRole.admin || role == UserRole.superAdmin;
  }

  static String? _roleTarget(UserRole? role) {
    return role?.name;
  }

  @override
  void onInit() {
    super.onInit();
    
    final AuthController authController = Get.find<AuthController>();

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
    _startListeningToUnreadCount();
  }

  void _cleanupSubscriptions() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _processedIds.clear(); 
    _processedNotificationKeys.clear();
  }

  void _startListeningToUnreadCount() {
    _startListeningToUnreadCountWithFallback();
  }

  void _startListeningToUnreadCountWithFallback({bool includeRoleTarget = true}) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final AuthController authController = Get.find<AuthController>();
    final role = authController.currentUser.value?.role;
    final roleTarget = _roleTarget(role);

    Query unreadQuery = FirebaseFirestore.instance.collection('notifications');
    final List<Filter> audienceFilters = <Filter>[
      Filter('userId', isEqualTo: userId),
      Filter('targetUserId', isEqualTo: userId),
      Filter('targetRole', isEqualTo: 'all'),
    ];

    if (includeRoleTarget) {
      if (role == UserRole.superAdmin) {
        audienceFilters.add(Filter('targetRole', isEqualTo: 'superAdmin'));
        audienceFilters.add(Filter('targetRole', isEqualTo: 'admin'));
      } else if (roleTarget != null && roleTarget.isNotEmpty) {
        audienceFilters.add(Filter('targetRole', isEqualTo: roleTarget));
      }
    }

    if (audienceFilters.length == 3) {
      unreadQuery = unreadQuery.where(
        Filter.or(audienceFilters[0], audienceFilters[1], audienceFilters[2]),
      );
    } else if (audienceFilters.length == 4) {
      unreadQuery = unreadQuery.where(
        Filter.or(audienceFilters[0], audienceFilters[1], audienceFilters[2], audienceFilters[3]),
      );
    } else {
      unreadQuery = unreadQuery.where(
        Filter.or(
          audienceFilters[0],
          audienceFilters[1],
          audienceFilters[2],
          audienceFilters[3],
          audienceFilters[4],
        ),
      );
    }

    final sub = unreadQuery
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      final visibleCount = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? const <String, dynamic>{};
        final excludedUserId = data['excludeUserId']?.toString();
        return excludedUserId == null || excludedUserId.isEmpty || excludedUserId != userId;
      }).length;
      unreadCount.value = visibleCount;
    }, onError: (error) {
      debugPrint('❌ Firestore Unread Error: $error');

      final message = error.toString().toLowerCase();
      final isPermissionDenied = message.contains('permission-denied') || message.contains('insufficient permissions');

      if (isPermissionDenied && includeRoleTarget) {
        debugPrint('⚠️ Falling back to unread query without role-target filter due to permissions.');
        Future.delayed(
          const Duration(seconds: 1),
          () => _startListeningToUnreadCountWithFallback(includeRoleTarget: false),
        );
        return;
      }

      Future.delayed(
        const Duration(seconds: 10),
        () => _startListeningToUnreadCountWithFallback(includeRoleTarget: includeRoleTarget),
      );
    });
    _subscriptions.add(sub);
  }



  @override
  void onClose() {
    _cleanupSubscriptions();
    super.onClose();
  }

  static Future<void> init() async {
    try {
      debugPrint('🚀 NotificationService: Global Init');
      
      await FirebaseMessaging.instance.requestPermission();

      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.requestNotificationsPermission();
      }

      if (Platform.isIOS) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }

      tz.initializeTimeZones(); 
      const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(android: androidInit, iOS: darwinInit);

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      // القناة العامة
      const AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
        _notificationChannelId,
        _notificationChannelName,
        description: 'إشعارات جمعية ناس الخير',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_notificationSoundName),
        enableVibration: true,
      );

      // قناة المحادثات (بالصوت الجديد)
      const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
        _chatChannelId,
        _chatChannelName,
        description: 'إشعارات الرسائل الجديدة في المحادثات',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_chatSoundName),
        enableVibration: true,
      );

      // قناة الطوارئ (بصوت صفارة الإنذار وأقصى أولوية)
      final AndroidNotificationChannel emergencyChannel = AndroidNotificationChannel(
        _emergencyChannelId,
        _emergencyChannelName,
        description: 'إشعارات الحالات الطارئة والتبرع بالدم',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_emergencySoundName),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]), // اهتزاز قوي
      );

      await androidPlugin?.createNotificationChannel(generalChannel);
      await androidPlugin?.createNotificationChannel(chatChannel);
      await androidPlugin?.createNotificationChannel(emergencyChannel);

      // ─── منع iOS من عرض إشعار نظامي في الـ Foreground ───
      // لأن الـ handler يعرض إشعاراً محلياً بنفسه (بتحكم كامل بالصوت والشكل)
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // مستمع تجديد التوكن: يُحدّث Firestore تلقائياً عند تجديد Firebase للتوكن
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 [NotificationService] FCM Token Refreshed - Saving...');
        saveCurrentDeviceToken();
      });

      try {
        final token = await FirebaseMessaging.instance.getToken().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('⚠️ [NotificationService] FCM Token fetch timed out.');
            return null;
          },
        );

        if (token != null) {
          debugPrint('🔑 Token fetched at init: ${token.substring(0, 20)}...');
          // يحفظ فقط إذا كان المستخدم مسجلاً − وإلا سيُستدعى من auth_controller بعد الدخول
          await saveCurrentDeviceToken();
        }
      } catch (e) {
        if (e.toString().contains('SERVICE_NOT_AVAILABLE')) {
          debugPrint('📶 [NotificationService] FCM Service not available.');
        } else {
          debugPrint('❌ [NotificationService] Token Fetch Error: $e');
        }
      }

    } catch (e) {
      debugPrint('❌ Init Error: $e');
    }
  }

  /// يجلب التوكن الحالي ثم يحفظه في Firestore – يُستدعى بعد تسجيل الدخول مباشرةً
  static Future<void> saveCurrentDeviceToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('⚠️ [NotificationService] saveCurrentDeviceToken: لا يوجد مستخدم مسجل.');
      return;
    }
    try {
      final token = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      if (token == null) {
        debugPrint('⚠️ [NotificationService] FCM Token is null − no token to save.');
        return;
      }
      debugPrint('🔑 [NotificationService] Saving FCM Token for user ${user.uid}');
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        // نحفظ المصفوفة فقط − السيرفر يقرأها. نتخلص من الحقل الفردي القديم لتفادي إرسال مزدوج
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
        'userId': user.uid,
      }, SetOptions(merge: true));
      debugPrint('✅ [NotificationService] Token saved successfully.');
    } catch (e) {
      debugPrint('❌ [NotificationService] saveCurrentDeviceToken error: $e');
    }
  }

  static Future<void> _saveToken(String token) => saveCurrentDeviceToken();

  static Future<String?> _downloadAndSaveImage(String url, String fileName) async {
    if (url.isEmpty) return null;
    try {
      final Directory directory = await getTemporaryDirectory();
      final String filePath = '${directory.path}/$fileName';
      final http.Response response = await http.get(Uri.parse(url));
      final File file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      return filePath;
    } catch (e) {
      debugPrint('❌ [NotificationService] Error downloading image: $e');
      return null;
    }
  }

  // ─── ذاكرة مؤقتة لمنع تكرار الإشعارات المحلية ───
  static final Set<String> _foregroundDedup = {};

  static void _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('🔔 [NotificationService] FCM Foreground Message Received');
    final notification = message.notification;
    final data = message.data;

    // ─── منع التكرار: استخدام notificationId كمفتاح فريد ───
    final String? notifId = data['notificationId'];
    if (notifId != null && notifId.isNotEmpty) {
      if (_foregroundDedup.contains(notifId)) {
        debugPrint('⏭️ [Foreground] تجاهل إشعار مكرر: $notifId');
        return;
      }
      _foregroundDedup.add(notifId);
      // تنظيف الذاكرة بعد دقيقة لمنع تسريب الذاكرة
      Future.delayed(const Duration(minutes: 1), () => _foregroundDedup.remove(notifId));
    }

    final String title = notification?.title ?? data['title'] ?? 'إشعار جديد';
    final String body = notification?.body ?? data['body'] ?? '';
    final String type = data['type']?.toString() ?? '';
    final String? imageUrl = data['imageUrl'] ?? data['data']?['imageUrl'];

    final bool isChat = type == 'new_message' || type == 'group_message' || type == 'guest_message';
    final bool isEmergency = type == 'blood_emergency' || type == 'sos_trigger' || type.contains('emergency');
    final String channelId = isEmergency ? _emergencyChannelId : (isChat ? _chatChannelId : _notificationChannelId);
    final String channelName = isEmergency ? _emergencyChannelName : (isChat ? _chatChannelName : _notificationChannelName);
    final String soundName = isEmergency ? _emergencySoundName : (isChat ? _chatSoundName : _notificationSoundName);

    // ─── ID ثابت للإشعار: يستبدل الإشعار القديم من نفس النوع بدل التراكم ───
    final int stableId = (notifId ?? '${title}_$body').hashCode & 0x7FFFFFFF;

    String? largeIconPath;
    BigPictureStyleInformation? bigPictureStyle;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      largeIconPath = await _downloadAndSaveImage(imageUrl, 'fground_notif_${stableId}.jpg');
      if (largeIconPath != null) {
        bigPictureStyle = BigPictureStyleInformation(
          FilePathAndroidBitmap(largeIconPath),
          largeIcon: FilePathAndroidBitmap(largeIconPath),
          contentTitle: title,
          summaryText: body,
        );
      }
    }

    _notificationsPlugin.show(
      id: stableId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/launcher_icon',
          largeIcon: largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
          styleInformation: bigPictureStyle,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(soundName),
          ticker: 'ناس الخير',
          enableVibration: true,
          showWhen: true,
          // tag يمنع تراكم الإشعارات من نفس المصدر
          tag: 'nas_${type}_$notifId',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: isChat ? '$_chatSoundName.wav' : '$_notificationSoundName.wav',
          attachments: largeIconPath != null ? [DarwinNotificationAttachment(largeIconPath)] : [],
        ),
      ),
      payload: _serializePayload(message.data),
    );
  }

  static String? _serializePayload(Map<String, dynamic> data) {
    if (data.isEmpty) return null;
    final String type = data['type']?.toString() ?? '';
    final String? requestId = data['requestId'] ?? data['data']?['requestId'];
    
    if (data['chatId'] != null) {
      return 'chatId:${data['chatId']},userName:${data['senderName'] ?? ""},targetUserId:${data['senderId'] ?? ""}';
    } else if (type == 'blood_emergency' || type == 'blood_encouragement') {
       return 'blood_emergency:reqId=$requestId,type=${data['bloodType']},hosp=${data['hospital']},ph=${data['phone']},isGuest=${data['isGuest'] == 'true'}';
    } else if (type == 'donor_responding') {
      return 'admin_request_detail:id=$requestId,isGuest=${data['isGuest'] == 'true'}';
    } else if (type == 'donor_response_withdrawn') {
      return requestId != null ? 'admin_request_detail:id=$requestId,isGuest=false' : 'admin_request_detail';
    } else if (type == 'donor_confirmed') {
      return 'blood_emergency:reqId=$requestId,type=${data['bloodType']},hosp=${data['hospital']},ph=${data['phone']},isGuest=false';
    } else if (type == 'blood_donation_completed') {
      return 'blood_donation_completed:id=$requestId';
    } else if (type == 'funeral_ghusl') {
      return 'funeral_ghusl:id=$requestId,gender=${data['gender']},loc=${data['location']},ph=${data['phone']}';
    } else if (type == 'request_update' || type == 'new_request' || type == 'status_change' || type == 'service_rating' || type == 'new_task') {
      return requestId != null ? 'request_update:id=$requestId' : 'request_update';
    } else if (type == 'new_donation') {
      final donationId = data['donationId'] ?? data['data']?['donationId'];
      return donationId != null ? 'new_donation:id=$donationId' : 'new_donation';
    }
    
    return data['type']?.toString();
  }

  static void _handleBackgroundMessage(RemoteMessage message) {
    final data = message.data;
    final isAdmin = _isAdminRole(_currentUserRole());

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
    } else if (data['type'] == 'donor_confirmed') {
      Get.toNamed('/blood-emergency', arguments: {
        'requestId': data['requestId'],
        'bloodType': data['bloodType'],
        'hospital': data['hospital'],
        'phone': data['phone'],
      });
    } else if (data['type'] == 'donor_responding') {
      Get.toNamed('/admin/request-detail', arguments: {
        'requestId': data['requestId'],
        'isGuest': data['isGuest'] == 'true',
      });
    } else if (data['type'] == 'request_update' || data['type'] == 'status_change' || data['type'] == 'service_rating' || data['type'] == 'new_task') {
      if (isAdmin && data['requestId'] != null) {
        Get.toNamed('/admin/request-detail', arguments: {
          'requestId': data['requestId'],
        });
      } else if (_currentUserRole() == UserRole.worker && data['requestId'] != null) {
        Get.toNamed('/worker/task-detail', arguments: {
          'requestId': data['requestId'],
        });
      } else {
        Get.toNamed('/notifications');
      }
    } else if (data['type'] == 'new_donation') {
      if (isAdmin) {
        Get.toNamed('/admin/donations');
      } else {
        Get.toNamed('/notifications');
      }
    } else if (data['type'] == 'new_request' || (data['requestId'] != null && data['type'] != 'blood_emergency' && data['type'] != 'blood_encouragement')) {
      if (isAdmin) {
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
    final isAdmin = _isAdminRole(_currentUserRole());

    if (payload.isEmpty) {
      Get.toNamed('/notifications');
      return;
    }

    try {
      if (payload.contains('chatId')) {
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

      if (payload.startsWith('request_update:')) {
        final content = payload.split(':')[1];
        final parts = content.split(',');
        String? requestId;
        for (var p in parts) {
          final kv = p.split('=');
          if (kv.length == 2 && kv[0] == 'id') {
            requestId = kv[1];
          }
        }
        if (isAdmin && requestId != null) {
          Get.toNamed('/admin/request-detail', arguments: {'requestId': requestId});
        } else if (_currentUserRole() == UserRole.worker && requestId != null) {
          Get.toNamed('/worker/task-detail', arguments: {'requestId': requestId});
        } else {
          Get.toNamed('/notifications');
        }
        return;
      }

      if (payload.startsWith('new_donation')) {
        if (isAdmin) {
          Get.toNamed('/admin/donations');
        } else {
          Get.toNamed('/notifications');
        }
        return;
      }

      if (payload.startsWith('blood_donation_completed:')) {
        Get.toNamed('/notifications');
        return;
      }

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
              android: AndroidNotificationDetails(
                'monthly_reminders',
                'التذكيرات',
                playSound: true,
                sound: RawResourceAndroidNotificationSound(_notificationSoundName),
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
                sound: 'notification.wav',
              ),
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

  // ======================================================
  // استدعاء سيرفر Vercel لإرسال FCM فوراً
  // ======================================================
  static const String _vercelBaseUrl = 'https://nas-alkhir-reggane.vercel.app';

  static Future<void> _triggerVercelFCM(String notificationId) async {
    try {
      final response = await http.post(
        Uri.parse('$_vercelBaseUrl/send-notification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'notificationId': notificationId}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        debugPrint('✅ [Vercel] FCM sent for $notificationId');
      } else {
        debugPrint('⚠️ [Vercel] Status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ [Vercel] FCM trigger failed: $e');
    }
  }

  static Future<void> sendNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null && currentUserId == userId) {
      debugPrint('🚫 [NotificationService] Skip self-notification for user $userId');
      return;
    }

    final docRef = await FirebaseFirestore.instance.collection('notifications').add({
      'userId': userId,
      'type': type,
      'title': title,
      'body': body,
      'data': data ?? {},
      if (data != null && data['excludeUserId'] != null) 'excludeUserId': data['excludeUserId'],
      if (data != null && data['chatId'] != null) 'chatId': data['chatId'],
      if (data != null && data['senderName'] != null) 'senderName': data['senderName'],
      if (data != null && data['requestId'] != null) 'requestId': data['requestId'],
      if (data != null && data['collection'] != null) 'collection': data['collection'],
      if (data != null && data['targetRole'] != null) 'targetRole': data['targetRole'],
      if (data != null && data['bloodType'] != null) 'bloodType': data['bloodType'],
      if (data != null && data['hospital'] != null) 'hospital': data['hospital'],
      if (data != null && data['phone'] != null) 'phone': data['phone'],
      if (data != null && data['patientName'] != null) 'patientName': data['patientName'],
      'senderId': data?['senderId'] ?? currentUserId,
      'isRead': false,
      'readBy': [],
      'createdAt': FieldValue.serverTimestamp(),
    });

    // استدعاء Vercel فوراً لإرسال FCM
    _triggerVercelFCM(docRef.id);
  }

  static Future<void> notifyRole({
    required String role,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? excludeUserId,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final payload = <String, dynamic>{
      'targetRole': role,
      'type': type,
      'title': title,
      'body': body,
      'data': data ?? {},
      'senderId': data?['senderId'] ?? currentUserId,
      'isRead': false,
      'readBy': [],
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (excludeUserId != null) payload['excludeUserId'] = excludeUserId;
    if (data != null && data['requestId'] != null) payload['requestId'] = data['requestId'];
    if (data != null && data['bloodType'] != null) payload['bloodType'] = data['bloodType'];
    if (data != null && data['hospital'] != null) payload['hospital'] = data['hospital'];
    if (data != null && data['phone'] != null) payload['phone'] = data['phone'];
    final docRef = await FirebaseFirestore.instance.collection('notifications').add(payload);

    // استدعاء Vercel فوراً لإرسال FCM
    _triggerVercelFCM(docRef.id);
  }

  static Future<void> notifyAll({
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? excludeUserId,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final effectiveExcludeUserId = excludeUserId ?? currentUserId;
    final requestId = data?['requestId'];
    final projectId = data?['projectId'];

    final payload = <String, dynamic>{
      'targetRole': 'all',
      'type': type,
      'title': title,
      'body': body,
      'data': data ?? {},
      'senderId': data?['senderId'] ?? currentUserId,
      'isRead': false,
      'readBy': [],
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (effectiveExcludeUserId != null) payload['excludeUserId'] = effectiveExcludeUserId;
    if (requestId != null) payload['requestId'] = requestId;
    if (projectId != null) payload['projectId'] = projectId;

    final docRef = await FirebaseFirestore.instance.collection('notifications').add(payload);

    // استدعاء Vercel فوراً لإرسال FCM
    _triggerVercelFCM(docRef.id);
  }

  static Future<void> notifyAllAdmins({
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? excludeUserId,
  }) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      debugPrint('🔔 NotificationService: notifyAllAdmins - $title');

      final payload = <String, dynamic>{
        'targetRole': 'admin',
        'type': type,
        'title': title,
        'body': body,
        'data': data ?? {},
        'senderId': data?['senderId'] ?? currentUserId ?? 'guest',
        'isRead': false,
        'readBy': [],
        'createdAt': FieldValue.serverTimestamp(),
      };

      // حقول اختيارية
      final optionalFields = ['chatId', 'requestId', 'collection', 'senderName',
                              'bloodType', 'hospital', 'phone', 'patientName', 'imageUrl'];
      for (final field in optionalFields) {
        if (data?[field] != null) payload[field] = data![field];
      }
      if (excludeUserId != null) payload['excludeUserId'] = excludeUserId;

      final docRef = await FirebaseFirestore.instance.collection('notifications').add(payload);

      // استدعاء Vercel فوراً لإرسال FCM
      _triggerVercelFCM(docRef.id);
    } catch (e) {
      debugPrint('❌ [NotificationService] notifyAllAdmins error: $e');
    }
  }

  static Future<void> notifyAllWorkers({required String title, required String body, Map<String, dynamic>? data}) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      debugPrint('🔔 NotificationService: notifyAllWorkers - $title');

      final payload = <String, dynamic>{
        'targetRole': 'worker',
        'type': 'announcement',
        'title': title,
        'body': body,
        'data': data ?? {},
        'senderId': currentUserId ?? 'system',
        'isRead': false,
        'readBy': [],
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (data?['requestId'] != null) payload['requestId'] = data!['requestId'];

      final docRef = await FirebaseFirestore.instance.collection('notifications').add(payload);

      // استدعاء Vercel فوراً لإرسال FCM
      _triggerVercelFCM(docRef.id);
    } catch (e) {
      debugPrint('❌ [NotificationService] notifyAllWorkers error: $e');
    }
  }

  Future<void> markAllAsRead() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    try {
      final AuthController authController = Get.find<AuthController>();
      final role = authController.currentUser.value?.role;

      Query unreadQuery = FirebaseFirestore.instance.collection('notifications');
      if (role == UserRole.admin) {
        unreadQuery = unreadQuery.where(Filter.or(
          Filter('userId', isEqualTo: userId),
          Filter('targetRole', isEqualTo: 'admin'),
          Filter('targetRole', isEqualTo: 'all'),
        ));
      } else if (role == UserRole.superAdmin) {
        unreadQuery = unreadQuery.where(Filter.or(
          Filter('userId', isEqualTo: userId),
          Filter('targetRole', isEqualTo: 'superAdmin'),
          Filter('targetRole', isEqualTo: 'admin'),
          Filter('targetRole', isEqualTo: 'all'),
        ));
      } else if (role == UserRole.worker) {
        unreadQuery = unreadQuery.where(Filter.or(
          Filter('userId', isEqualTo: userId),
          Filter('targetRole', isEqualTo: 'worker'),
          Filter('targetRole', isEqualTo: 'all'),
        ));
      } else if (role == UserRole.donor) {
        unreadQuery = unreadQuery.where(Filter.or(
          Filter('userId', isEqualTo: userId),
          Filter('targetRole', isEqualTo: 'donor'),
          Filter('targetRole', isEqualTo: 'all'),
        ));
      } else if (role == UserRole.beneficiary) {
        unreadQuery = unreadQuery.where(Filter.or(
          Filter('userId', isEqualTo: userId),
          Filter('targetRole', isEqualTo: 'beneficiary'),
          Filter('targetRole', isEqualTo: 'all'),
        ));
      } else if (role == UserRole.chatModerator) {
        unreadQuery = unreadQuery.where(Filter.or(
          Filter('userId', isEqualTo: userId),
          Filter('targetRole', isEqualTo: 'chatModerator'),
          Filter('targetRole', isEqualTo: 'all'),
        ));
      } else {
        unreadQuery = unreadQuery.where(Filter.or(
          Filter('userId', isEqualTo: userId),
          Filter('targetRole', isEqualTo: 'all'),
        ));
      }

      final unread = await unreadQuery
          .where('isRead', isEqualTo: false)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in unread.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readBy': FieldValue.arrayUnion([userId])
        });
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

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // ─── لا نعرض إشعاراً محلياً هنا ───
  // السبب: عندما يكون التطبيق في الخلفية أو مغلقاً تماماً،
  // نظام Android يعرض الإشعار تلقائياً من حقل `notification` في رسالة FCM.
  // إذا أضفنا إشعاراً محلياً هنا، سيظهر إشعاران (مزدوج).
  //
  // هذا الـ handler يُستخدم فقط لمعالجة البيانات في الخلفية إن لزم الأمر.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}

  debugPrint('📩 [BackgroundHandler] FCM message received: type=${message.data['type']}');
}

import 'dart:async';

import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../data/models/user_model.dart';

class ChatController extends GetxController {
  final RxInt totalUnreadCount = 0.obs;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chatSubscription;
  Worker? _userWorker;

  @override
  void onInit() {
    super.onInit();
    _bindAuthState();
    _bindRoleChanges();
  }

  void _bindAuthState() {
    _authSubscription = _auth.authStateChanges().listen((_) {
      _restartUnreadListener();
    });
    _restartUnreadListener();
  }

  void _bindRoleChanges() {
    final AuthController authController = Get.find<AuthController>();
    _userWorker = ever<UserModel?>(authController.currentUser, (_) {
      _restartUnreadListener();
    });
  }

  void _restartUnreadListener() {
    _chatSubscription?.cancel();

    final user = _auth.currentUser;
    if (user == null) {
      totalUnreadCount.value = 0;
      return;
    }

    final AuthController authController = Get.find<AuthController>();
    final role = authController.currentUser.value?.role;
    final isAdmin = role == UserRole.admin || role == UserRole.superAdmin;

    if (!isAdmin) {
      totalUnreadCount.value = 0;
      return;
    }

    Query<Map<String, dynamic>> query = _firestore.collection('chats');
    query = query.where(Filter.or(
      Filter('participants', arrayContains: user.uid),
      Filter('type', isEqualTo: 'guest'),
    ));

    _chatSubscription = query.snapshots().listen((snapshot) {
      int count = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final unreadMap = Map<String, dynamic>.from(data['unreadCount'] ?? {});
        int userUnread = _safeToInt(unreadMap[user.uid]);

        if (isAdmin && data['type'] == 'guest') {
          final guestUnread = _safeToInt(data['guestUnreadCount']);
          final participants = List<String>.from(data['participants'] ?? <String>[]);
          if (!participants.contains(user.uid)) {
            userUnread = guestUnread;
          }
        }

        count += userUnread;
      }

      totalUnreadCount.value = count;
    }, onError: (_) {
      totalUnreadCount.value = 0;
    });
  }

  int _safeToInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  @override
  void onClose() {
    _chatSubscription?.cancel();
    _authSubscription?.cancel();
    _userWorker?.dispose();
    super.onClose();
  }
}


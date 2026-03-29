import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../data/models/user_model.dart';

class ChatController extends GetxController {
  final RxInt totalUnreadCount = 0.obs;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void onInit() {
    super.onInit();
    _listenToUnreadCount();
  }

  void _listenToUnreadCount() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        final AuthController authController = Get.find<AuthController>();
        
        _firestore.collection('chats')
            .where(Filter.or(
              Filter('participants', arrayContains: user.uid),
              Filter('type', isEqualTo: 'guest'),
            ))
            .snapshots()
            .listen((snapshot) {
          
          final userModel = authController.currentUser.value;
          final isAdmin = userModel?.role == UserRole.admin || userModel?.role == UserRole.superAdmin;
          
          int count = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            
            // 1. Check direct unread count for this user
            final unreadMap = Map<String, dynamic>.from(data['unreadCount'] ?? {});
            int userUnread = (unreadMap[user.uid] ?? 0) as int;
            
            // 2. For admins, also count chats with new guest messages if they haven't joined yet
            if (isAdmin && data['type'] == 'guest' && data['hasUnreadGuestMessage'] == true) {
              final participants = List.from(data['participants'] ?? []);
              if (!participants.contains(user.uid)) {
                // If it's a new guest chat and this admin hasn't opened it yet
                userUnread = userUnread > 0 ? userUnread : 1; 
              }
            }
            
            count += userUnread;
          }
          totalUnreadCount.value = count;
        });
      } else {
        totalUnreadCount.value = 0;
      }
    });
  }
}

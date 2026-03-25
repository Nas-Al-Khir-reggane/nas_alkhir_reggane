import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' as intl;
import '../../../core/theme/app_theme.dart';
import '../../../data/services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService notificationService = Get.find<NotificationService>();
  final userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    // Mark all as read when opening the screen
    notificationService.markAllAsRead();
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return Scaffold(
        backgroundColor: AppTheme.darkBg,
        appBar: AppBar(title: const Text('الإشعارات')),
        body: Center(child: Text('يرجى تسجيل الدخول أولاً', style: TextStyle(color: AppTheme.textHint))),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('الإشعارات'),
        backgroundColor: AppTheme.darkSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () => notificationService.markAllAsRead(),
            tooltip: 'تحديد الكل كمقروء',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 80, color: AppTheme.textHint.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('لا توجد إشعارات حالياً', style: TextStyle(color: AppTheme.textHint)),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final data = notifications[index].data() as Map<String, dynamic>;
              final bool isRead = data['isRead'] ?? false;
              final DateTime date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isRead ? AppTheme.darkCard : AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: isRead ? null : Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getNotificationColor(data['type']).withValues(alpha: 0.15),
                    child: Icon(_getNotificationIcon(data['type']), color: _getNotificationColor(data['type']), size: 20),
                  ),
                  title: Text(
                    data['title'] ?? '',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['body'] ?? '', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        intl.DateFormat('yyyy/MM/dd HH:mm').format(date),
                        style: TextStyle(color: AppTheme.textHint, fontSize: 10),
                      ),
                    ],
                  ),
                  onTap: () {
                    if (!isRead) {
                      FirebaseFirestore.instance
                          .collection('notifications')
                          .doc(notifications[index].id)
                          .update({'isRead': true});
                    }
                    _handleNotificationTap(data);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'new_project': return Icons.folder_special;
      case 'request_update': return Icons.update;
      case 'request_approved': return Icons.check_circle;
      case 'request_rejected': return Icons.cancel;
      case 'new_donation': return Icons.volunteer_activism;
      case 'chat': return Icons.chat;
      default: return Icons.notifications;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'request_approved': return AppTheme.successColor;
      case 'request_rejected': return AppTheme.errorColor;
      case 'new_donation': return AppTheme.goldAccent;
      default: return AppTheme.primaryGreen;
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'];
    final payload = data['data'];

    if (type == 'new_project') {
      Get.toNamed('/donor/dashboard');
    } else if (type == 'request_approved' || type == 'request_rejected' || type == 'request_update') {
      Get.toNamed('/beneficiary/dashboard');
    } else if (type == 'chat') {
      Get.toNamed('/chat/group');
    }
  }
}

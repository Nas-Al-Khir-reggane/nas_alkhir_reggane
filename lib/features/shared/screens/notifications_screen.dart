import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:animate_do/animate_do.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final NotificationService notificationService = Get.find<NotificationService>();
  final userId = FirebaseAuth.instance.currentUser?.uid;
  late TabController _tabController;

  final List<String> _tabs = ['الكل', 'الطلبات', 'عام'];
  final List<String?> _tabTypes = [null, 'new_request', 'announcement'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    Future.microtask(() => notificationService.markAllAsRead());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: Text('يرجى تسجيل الدخول أولاً',
              style: TextStyle(color: AppTheme.textHint, fontFamily: 'Tajawal')),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // ─── Header ───
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🔔 الإشعارات',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('notifications')
                            .where('userId', isEqualTo: userId)
                            .where('isRead', isEqualTo: false)
                            .snapshots(),
                        builder: (context, snap) {
                          final count = snap.data?.docs.length ?? 0;
                          return Text(
                            count > 0 ? '$count غير مقروء' : 'لا توجد إشعارات جديدة',
                            style: TextStyle(
                                color: count > 0
                                    ? AppTheme.primaryGreen
                                    : AppTheme.textSecondary,
                                fontSize: 13,
                                fontFamily: 'Tajawal'),
                          );
                        },
                      ),
                    ],
                  ),
                  const Spacer(),
                  _buildMarkAllReadButton(),
                ],
              ),
            ),
          ),

          // ─── Tabs ───
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorPadding: const EdgeInsets.all(4),
              labelColor: Colors.black,
              unselectedLabelColor: AppTheme.textHint,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Tajawal', fontSize: 13),
              dividerColor: Colors.transparent,
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
          ),

          // ─── Content ───
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabTypes.map((type) => _NotificationList(
                userId: userId!,
                typeFilter: type,
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkAllReadButton() {
    return GestureDetector(
      onTap: () => notificationService.markAllAsRead(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.done_all_rounded, color: AppTheme.primaryGreen, size: 16),
            const SizedBox(width: 6),
            const Text('قراءة الكل',
                style: TextStyle(
                    color: AppTheme.primaryGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Tajawal')),
          ],
        ),
      ),
    );
  }
}

// ─── Individual Notification List ───────────────────────────────────────────

class _NotificationList extends StatelessWidget {
  final String userId;
  final String? typeFilter;

  const _NotificationList({required this.userId, this.typeFilter});

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    if (typeFilter != null) {
      query = query.where('type', isEqualTo: typeFilter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Check if it's an index error and show a graceful message
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: AppTheme.errorColor, size: 48),
                const SizedBox(height: 12),
                Text('تعذّر تحميل الإشعارات',
                    style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'Tajawal')),
              ],
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final bool isRead = data['isRead'] ?? false;
            final DateTime date =
                (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final docRef = docs[index].reference;

            return FadeInLeft(
              delay: Duration(milliseconds: index * 60),
              duration: const Duration(milliseconds: 350),
              child: _NotificationCard(
                data: data,
                isRead: isRead,
                date: date,
                docRef: docRef,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_off_outlined,
                size: 56, color: AppTheme.textHint.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          Text('لا توجد إشعارات',
              style: TextStyle(
                  color: AppTheme.textHint,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Tajawal')),
          const SizedBox(height: 6),
          Text('ستظهر الإشعارات هنا عند وصولها',
              style: TextStyle(
                  color: AppTheme.textHint.withValues(alpha: 0.6), fontSize: 13, fontFamily: 'Tajawal')),
        ],
      ),
    );
  }
}

// ─── Notification Card ───────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime date;
  final DocumentReference docRef;

  const _NotificationCard({
    required this.data,
    required this.isRead,
    required this.date,
    required this.docRef,
  });

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String?;
    final color = _typeColor(type);
    final icon = _typeIcon(type);
    final label = _typeLabel(type);

    return GestureDetector(
      onTap: () async {
        if (!isRead) {
          await docRef.update({'isRead': true});
        }
        _navigate(data);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isRead ? AppTheme.cardColor : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isRead
                ? AppTheme.glassBorder
                : color.withValues(alpha: 0.4),
            width: isRead ? 1 : 1.5,
          ),
          boxShadow: isRead ? [] : [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type label + unread dot
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Tajawal'),
                          ),
                        ),
                        const Spacer(),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: AppTheme.primaryGreen.withValues(alpha: 0.4),
                                    blurRadius: 4)
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Title
                    Text(
                      data['title'] ?? '',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                        fontSize: 14,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Body
                    Text(
                      data['body'] ?? '',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontFamily: 'Tajawal'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Time + action arrow
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 13, color: AppTheme.textHint),
                        const SizedBox(width: 4),
                        Text(
                          timeago.format(date, locale: 'ar'),
                          style: TextStyle(
                              color: AppTheme.textHint,
                              fontSize: 11,
                              fontFamily: 'Tajawal'),
                        ),
                        const Spacer(),
                        if (_canNavigate(data['type']))
                          Row(
                            children: [
                              Text(
                                'عرض',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Tajawal'),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.arrow_back_ios_rounded,
                                  color: color, size: 11),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canNavigate(String? type) {
    return type == 'new_request' ||
        type == 'request_update' ||
        type == 'request_approved' ||
        type == 'request_rejected' ||
        type == 'new_project' ||
        type == 'chat';
  }

  void _navigate(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final requestId = data['requestId'] as String?;
    
    switch (type) {
      case 'new_request':
        if (requestId != null) {
          // جلب بيانات الطلب لفتح صفحة التفاصيل
          FirebaseFirestore.instance
              .collection('service_requests')
              .doc(requestId)
              .get()
              .then((doc) {
            if (doc.exists) {
              final reqMap = doc.data()!;
              reqMap['id'] = doc.id;
              // ignore: invalid_use_of_protected_member
              Get.toNamed('/admin/request-detail', arguments: reqMap);
            } else {
              Get.toNamed('/admin/requests');
            }
          });
        } else {
          Get.toNamed('/admin/requests');
        }
        break;
      case 'request_update':
      case 'request_approved':
      case 'request_rejected':
        Get.toNamed('/beneficiary/dashboard');
        break;
      case 'new_project':
        Get.toNamed('/donor/dashboard');
        break;
      case 'chat':
        if (data['senderId'] != null) {
          Get.toNamed('/chat/private', arguments: {
            'userId': data['senderId'],
            'userName': data['senderName'] ?? 'رسالة جديدة'
          });
        } else {
          Get.toNamed('/chat/group');
        }
        break;
      default:
        break;
    }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'new_request': return AppTheme.primaryGreen;
      case 'request_approved': return AppTheme.successColor;
      case 'request_rejected': return AppTheme.errorColor;
      case 'request_update': return Colors.blue;
      case 'new_donation': return AppTheme.goldAccent;
      case 'new_project': return Colors.purple;
      case 'chat': return Colors.teal;
      case 'announcement': return AppTheme.warningColor;
      default: return AppTheme.primaryGreen;
    }
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'new_request': return Icons.assignment_add;
      case 'request_approved': return Icons.check_circle_rounded;
      case 'request_rejected': return Icons.cancel_rounded;
      case 'request_update': return Icons.update_rounded;
      case 'new_donation': return Icons.volunteer_activism;
      case 'new_project': return Icons.folder_special_rounded;
      case 'chat': return Icons.chat_bubble_rounded;
      case 'announcement': return Icons.campaign_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'new_request': return 'طلب جديد';
      case 'request_approved': return 'تمت الموافقة';
      case 'request_rejected': return 'مرفوض';
      case 'request_update': return 'تحديث طلب';
      case 'new_donation': return 'تبرع جديد';
      case 'new_project': return 'مشروع جديد';
      case 'chat': return 'رسالة';
      case 'announcement': return 'إعلان';
      default: return 'إشعار';
    }
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:animate_do/animate_do.dart';
import 'dart:ui' as ui;
import '../../../core/theme/app_theme.dart';
import '../../../data/services/notification_service.dart';
import '../../../core/animations/visual_effects.dart';
import '../../../core/animations/micro_interactions.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../data/models/user_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final NotificationService notificationService = Get.find<NotificationService>();
  final AuthController authController = Get.find<AuthController>();
  final String? userId = FirebaseAuth.instance.currentUser?.uid;
  
  late TabController _tabController;
  late List<String> _tabs;
  late List<List<String>?> _tabFilters;

  @override
  void initState() {
    super.initState();
    _initRoleBasedTabs();
    _tabController = TabController(length: _tabs.length, vsync: this);
    Future.microtask(() => notificationService.markAllAsRead());
  }

  void _initRoleBasedTabs() {
    final role = authController.currentUser.value?.role;
    
    if (role == UserRole.superAdmin || role == UserRole.admin) {
      _tabs = ['الكل', 'الطلبات', 'النظام'];
      _tabFilters = [
        null, // All
        ['new_request', 'request_update'], // Requests
        ['announcement', 'system'], // System
      ];
    } else if (role == UserRole.worker) {
      _tabs = ['الكل', 'المهام', 'متفرقات'];
      _tabFilters = [
        null,
        ['new_task', 'task_update', 'chat'],
        ['announcement', 'system'],
      ];
    } else {
      // Beneficiary / Guest / Others
      _tabs = ['الكل', 'تحديثات طلباتي', 'عام'];
      _tabFilters = [
        null,
        ['request_update', 'request_approved', 'request_rejected'],
        ['announcement', 'system', 'new_donation', 'new_project'],
      ];
    }
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
      body: VisualEffects.ambientBackground(
        isDark: Get.isDarkMode,
        child: Column(
          children: [
            // ─── Header ───
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_active_outlined, color: AppTheme.primaryGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الإشعارات',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textPrimary,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                          Obx(() {
                            final count = notificationService.unreadCount.value;
                            return Text(
                              count > 0 ? 'لديك $count إشعار جديد' : 'أنت على اطلاع دائم',
                              style: TextStyle(
                                  color: count > 0 ? AppTheme.primaryGreen : AppTheme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
                                  fontFamily: 'Tajawal'),
                            );
                          }),
                        ],
                      ),
                    ),
                    _buildHeaderActions(),
                  ],
                ),
              ),
            ),
            
            // ─── Floating Glassmorphic Tabs ───
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.darkCard.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.glassBorder),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppTheme.greenGlow,
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppTheme.textHint,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 13),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontFamily: 'Tajawal', fontSize: 13),
                    dividerColor: Colors.transparent,
                    physics: const BouncingScrollPhysics(),
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) => Colors.transparent),
                    tabs: _tabs.map((t) => Tab(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    )).toList(),
                  ),
                ),
              ),
            ),

            // ─── Content ───
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: _tabFilters.map((filters) => _NotificationList(
                  userId: userId!,
                  allowedTypes: filters,
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MicroInteractions.hoverScale(
          child: IconButton(
            onPressed: () {
              Get.dialog(
                AlertDialog(
                  title: const Text('حذف التنبيهات', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Tajawal')),
                  content: const Text('هل تريد حذف جميع الإشعارات المقروءة؟', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Tajawal')),
                  actions: [
                    TextButton(onPressed: () => Get.back(), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal'))),
                    TextButton(
                      onPressed: () {
                        notificationService.deleteAllRead();
                        Get.back();
                        Get.snackbar('تم', 'تم حذف الإشعارات المقروءة', backgroundColor: AppTheme.successColor.withValues(alpha: 0.2));
                      },
                      child: const Text('حذف الكل', style: TextStyle(color: AppTheme.errorColor, fontFamily: 'Tajawal')),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.delete_sweep_outlined, color: AppTheme.errorColor),
            tooltip: 'حذف المقروءة',
          ),
        ),
        const SizedBox(width: 4),
        _buildMarkAllReadButton(),
      ],
    );
  }

  Widget _buildMarkAllReadButton() {
    return MicroInteractions.hoverScale(
      child: GestureDetector(
        onTap: () {
          notificationService.markAllAsRead();
          Get.snackbar('تم', 'تم تحديد جميع الإشعارات كمقروءة',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
            colorText: AppTheme.successColor,
            duration: const Duration(seconds: 2));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.glassBorder),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.clear_all_rounded, color: AppTheme.textSecondary, size: 20),
              const SizedBox(width: 6),
              Text('مقروءة',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Tajawal')),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Individual Notification List ───────────────────────────────────────────

class _NotificationList extends StatelessWidget {
  final String userId;
  final List<String>? allowedTypes;

  const _NotificationList({required this.userId, this.allowedTypes});

  @override
  Widget build(BuildContext context) {
    // We only query by userId from the server.
    // Client-side filtering applies the type conditions to prevent composite index errors.
    Query query = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppTheme.errorColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 40),
                ),
                const SizedBox(height: 16),
                Text('تعذّر تحميل الإشعارات',
                    style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
        }

        List<DocumentSnapshot> docs = snapshot.data?.docs ?? [];
        
        // Client-side filtering & sorting
        if (allowedTypes != null && allowedTypes!.isNotEmpty) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final type = data['type'] as String?;
            return allowedTypes!.contains(type);
          }).toList();
        }

        docs.sort((a, b) {
          var dataA = a.data() as Map<String, dynamic>;
          var dataB = b.data() as Map<String, dynamic>;
          Timestamp? tA = dataA['createdAt'] as Timestamp?;
          Timestamp? tB = dataB['createdAt'] as Timestamp?;
          if (tA == null && tB == null) return 0;
          if (tA == null) return 1;
          if (tB == null) return -1;
          return tB.compareTo(tA);
        });

        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final bool isRead = data['isRead'] ?? false;
            final DateTime date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final docRef = docs[index].reference;

            return FadeInUp(
              delay: Duration(milliseconds: (index % 10) * 50),
              duration: const Duration(milliseconds: 400),
              child: Dismissible(
                key: Key(docs[index].id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) {
                  Get.find<NotificationService>().deleteNotification(docs[index].id);
                },
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                child: _NotificationCard(
                  data: data,
                  isRead: isRead,
                  date: date,
                  docRef: docRef,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return FadeIn(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.1), width: 2),
              ),
              child: const Icon(Icons.notifications_active_outlined,
                  size: 50, color: AppTheme.primaryGreen),
            ),
            const SizedBox(height: 24),
            Text('لم تصلك إشعارات بعد',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Tajawal')),
            const SizedBox(height: 8),
            Text('سوف تظهر التنبيهات المخصصة لك هنا',
                style: TextStyle(
                    color: AppTheme.textHint.withValues(alpha: 0.8), fontSize: 13, fontFamily: 'Tajawal')),
          ],
        ),
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

    return MicroInteractions.hoverScale(
      child: GestureDetector(
        onTap: () async {
        if (!isRead) {
          await docRef.update({'isRead': true});
        }
        _navigate(data);
      },
      onLongPress: () {
        Get.dialog(
          AlertDialog(
            title: const Text('حذف الإشعار', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Tajawal')),
            content: const Text('هل أنت متأكد من حذف هذا الإشعار؟', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Tajawal')),
            actions: [
              TextButton(onPressed: () => Get.back(), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal'))),
              TextButton(
                onPressed: () {
                  Get.find<NotificationService>().deleteNotification(docRef.id);
                  Get.back();
                },
                child: const Text('حذف', style: TextStyle(color: AppTheme.errorColor, fontFamily: 'Tajawal')),
              ),
            ],
          ),
        );
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
    ));
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

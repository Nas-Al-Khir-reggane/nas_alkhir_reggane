import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:animate_do/animate_do.dart';
import 'dart:ui' as ui;
import '../../../core/animations/visual_effects.dart';
import '../../../core/animations/micro_interactions.dart';
import '../../../data/services/notification_service.dart';
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
        ['announcement', 'system', 'new_donation', 'new_project', 'blood_emergency', 'blood_encouragement'],
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Text('يرجى تسجيل الدخول أولاً',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: 'Tajawal')),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.notifications_active_outlined, color: Theme.of(context).colorScheme.primary),
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
                              color: Theme.of(context).colorScheme.onSurface,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                          Obx(() {
                            final count = notificationService.unreadCount.value;
                            return Text(
                              count > 0 ? 'لديك $count إشعار جديد' : 'أنت على اطلاع دائم',
                              style: TextStyle(
                                  color: count > 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
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
                color: Theme.of(context).cardColor.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.75)),
                boxShadow: [
                  BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.75), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Theme.of(context).colorScheme.onPrimary,
                    unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
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
                        Get.snackbar('تم', 'تم حذف الإشعارات المقروءة', backgroundColor: Colors.green.withValues(alpha: 0.15));
                      },
                      child: Text('حذف الكل', style: TextStyle(color: Theme.of(context).colorScheme.error, fontFamily: 'Tajawal')),
                    ),
                  ],
                ),
              );
            },
            icon: Icon(Icons.delete_sweep_outlined, color: Theme.of(context).colorScheme.error),
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
            backgroundColor: Colors.green.withValues(alpha: 0.15),
            colorText: Colors.green,
            duration: const Duration(seconds: 2));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.75)),
            boxShadow: [
              BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.75), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.clear_all_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
              const SizedBox(width: 6),
              Text('مقروءة',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    final authController = Get.find<AuthController>();
    final role = authController.currentUser.value?.role;
    final isAdmin = role == UserRole.admin || role == UserRole.superAdmin;

    // We fetch notifications for the user, and if they are an admin, we also fetch broadcast notifications
    Query query = FirebaseFirestore.instance.collection('notifications');
    if (isAdmin) {
      query = query.where(
        Filter.or(
          Filter('userId', isEqualTo: userId),
          Filter('targetRole', isEqualTo: 'admin'),
          Filter('targetRole', isEqualTo: 'all'),
        )
      );
    } else {
      query = query.where(
        Filter.or(
          Filter('userId', isEqualTo: userId),
          Filter('targetRole', isEqualTo: 'all'),
        )
      );
    }

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
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.75), shape: BoxShape.circle),
                  child: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 40),
                ),
                const SizedBox(height: 16),
                Text('تعذّر تحميل الإشعارات',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
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
          return _buildEmptyState(context);
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
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.75),
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

  Widget _buildEmptyState(BuildContext context) {
    return FadeIn(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.75), width: 2),
              ),
              child: Icon(Icons.notifications_active_outlined,
                  size: 50, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text('لم تصلك إشعارات بعد',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Tajawal')),
            const SizedBox(height: 8),
            Text('سوف تظهر التنبيهات المخصصة لك هنا',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.75), fontSize: 13, fontFamily: 'Tajawal')),
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
    final color = _typeColor(context, type);
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
                child: Text('حذف', style: TextStyle(color: Theme.of(context).colorScheme.error, fontFamily: 'Tajawal')),
              ),
            ],
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isRead ? Theme.of(context).cardColor : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isRead
                ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)
                : color.withValues(alpha: 0.75),
            width: isRead ? 1 : 1.5,
          ),
          boxShadow: isRead ? [] : [
            BoxShadow(
              color: color.withValues(alpha: 0.75),
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
                  color: color.withValues(alpha: 0.75),
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
                            color: color.withValues(alpha: 0.75),
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
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
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
                        color: Theme.of(context).colorScheme.onSurface,
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                            size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          timeago.format(date, locale: 'ar'),
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        type == 'blood_emergency' ||
        type == 'blood_encouragement' ||
        type == 'blood_donation_complete' ||
        type == 'donor_confirmed' ||
        type == 'donor_responding' ||
        type == 'chat' ||
        type == 'new_message' ||
        type == 'guest_message';
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
      case 'new_message':
      case 'guest_message':
        if (data['senderId'] != null) {
          Get.toNamed('/chat/private', arguments: {
            'userId': data['senderId'],
            'userName': data['senderName'] ?? 'رسالة جديدة'
          });
        } else {
          Get.toNamed('/chat/group');
        }
        break;
      case 'blood_emergency':
      case 'blood_encouragement':
        final Map<String, dynamic> args = {
          'requestId': data['requestId'] ?? (data['data'] != null ? data['data']['requestId'] : null),
          'bloodType': data['bloodType'] ?? (data['data'] != null ? data['data']['bloodType'] : null),
          'hospital': data['hospital'] ?? (data['data'] != null ? data['data']['hospital'] : null),
          'phone': data['phone'] ?? (data['data'] != null ? data['data']['phone'] : null),
        };
        Get.toNamed('/blood-emergency', arguments: args);
        break;
      case 'blood_donation_complete':
        Get.toNamed('/blood-donor-profile');
        break;
      case 'donor_confirmed':
        if (data['requestId'] != null) {
          final Map<String, dynamic> args = {
            'requestId': data['requestId'],
            'bloodType': data['bloodType'],
            'hospital': data['hospital'],
            'phone': data['phone'],
          };
          Get.toNamed('/blood-emergency', arguments: args);
        }
        break;
      case 'donor_responding':
        if (data['requestId'] != null) {
          Get.toNamed('/admin/request-detail', arguments: {
            'requestId': data['requestId'],
            'isGuest': data['isGuest'] == 'true',
          });
        }
        break;
      default:
        break;
    }
  }

  Color _typeColor(BuildContext context, String? type) {
    switch (type) {
      case 'new_request': return Theme.of(context).colorScheme.primary;
      case 'request_approved': return Colors.green;
      case 'request_rejected': return Theme.of(context).colorScheme.error;
      case 'request_update': return Colors.blue;
      case 'new_donation': return Theme.of(context).colorScheme.primary;
      case 'new_project': return Colors.purple;
      case 'chat': return Colors.teal;
      case 'new_message': return Colors.teal;
      case 'guest_message': return Colors.teal;
      case 'announcement': return Colors.orange;
      case 'blood_emergency': return Theme.of(context).colorScheme.error;
      case 'blood_encouragement': return Colors.green;
      case 'blood_donation_complete': return Colors.green;
      case 'donor_confirmed': return Colors.green;
      case 'donor_responding': return Colors.orange;
      default: return Theme.of(context).colorScheme.primary;
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
      case 'new_message': return Icons.chat_bubble_rounded;
      case 'guest_message': return Icons.chat_bubble_rounded;
      case 'announcement': return Icons.campaign_rounded;
      case 'blood_emergency': return Icons.volunteer_activism;
      case 'blood_encouragement': return Icons.diversity_1_rounded;
      case 'blood_donation_complete': return Icons.military_tech_rounded;
      case 'donor_confirmed': return Icons.verified_rounded;
      case 'donor_responding': return Icons.directions_run_rounded;
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
      case 'new_message': return 'رسالة';
      case 'guest_message': return 'رسالة زائر';
      case 'announcement': return 'إعلان';
      case 'blood_emergency': return 'نداء استغاثة';
      case 'blood_encouragement': return 'فرصة تبرع';
      case 'blood_donation_complete': return 'إتمام تبرع';
      case 'donor_confirmed': return 'تأكيد متبرع';
      case 'donor_responding': return 'متبرع مستجيب';
      default: return 'إشعار';
    }
  }
}


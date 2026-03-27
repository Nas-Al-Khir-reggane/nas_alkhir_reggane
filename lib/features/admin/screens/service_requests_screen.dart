import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/service_request_model.dart';
import '../controllers/admin_controller.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:animate_do/animate_do.dart';

class ServiceRequestsScreen extends StatefulWidget {
  const ServiceRequestsScreen({super.key});

  @override
  State<ServiceRequestsScreen> createState() => _ServiceRequestsScreenState();
}

class _ServiceRequestsScreenState extends State<ServiceRequestsScreen> with SingleTickerProviderStateMixin {
  final AdminController adminController = Get.find<AdminController>();
  final TextEditingController searchController = TextEditingController();
  late TabController _tabController;

  final RxString selectedStatus = 'all'.obs;
  final RxString selectedServiceType = 'all'.obs;
  final RxString selectedUrgency = 'all'.obs;
  final RxString selectedWilaya = 'all'.obs;
  final RxString selectedCommune = 'all'.obs; // إضافة فلتر البلدية
  final RxString selectedPeriod = 'all'.obs;
  final RxString selectedWorker = 'all'.obs;
  final RxBool showFilters = false.obs;
  final RxBool showGuestRequests = false.obs;

  final List<String> tabs = ['الكل', 'معلق', 'جاري', 'مكتمل', 'مرفوض'];
  final List<String> tabValues = ['all', 'pending', 'in_progress', 'completed', 'rejected'];

  Map<String, int> countByStatus = {};
  int totalCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        selectedStatus.value = tabValues[_tabController.index];
      }
    });
    searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Query _buildQuery() {
    Query query = FirebaseFirestore.instance.collection(
        showGuestRequests.value ? 'guest_requests' : AppConstants.serviceRequestsCollection);

    if (selectedStatus.value != 'all') {
      query = query.where('status', isEqualTo: selectedStatus.value);
    }
    if (selectedServiceType.value != 'all') {
      query = query.where('type', isEqualTo: selectedServiceType.value);
    }
    if (selectedUrgency.value != 'all') {
      query = query.where('urgency', isEqualTo: selectedUrgency.value);
    }
    if (selectedWilaya.value != 'all') {
      query = query.where('wilaya', isEqualTo: selectedWilaya.value);
    }
    if (selectedCommune.value != 'all') {
      query = query.where('commune', isEqualTo: selectedCommune.value);
    }
    if (selectedWorker.value != 'all') {
      query = query.where('assignedTo', isEqualTo: selectedWorker.value);
    }

    return query.orderBy('createdAt', descending: true);
  }

  void clearAllFilters() {
    selectedServiceType.value = 'all';
    selectedUrgency.value = 'all';
    selectedWilaya.value = 'all';
    selectedCommune.value = 'all';
    selectedPeriod.value = 'all';
    selectedWorker.value = 'all';
  }

  bool get anyFilterActive =>
      selectedServiceType.value != 'all' ||
      selectedUrgency.value != 'all' ||
      selectedWilaya.value != 'all' ||
      selectedCommune.value != 'all' ||
      selectedPeriod.value != 'all' ||
      selectedWorker.value != 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📋 طلبات الخدمة',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textPrimary,
                              fontFamily: 'Tajawal')),
                      Obx(() => StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection(showGuestRequests.value ? 'guest_requests' : AppConstants.serviceRequestsCollection)
                            .where('status', whereNotIn: ['rejected'])
                            .snapshots(),
                        builder: (context, snapshot) {
                          int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                          totalCount = count;
                          return Text('$count طلب نشط',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13));
                        },
                      )),
                    ],
                  ),
                  const Spacer(),
                  Obx(() => GestureDetector(
                    onTap: () => showFilters.toggle(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: showFilters.value
                            ? AppTheme.primaryGreen.withOpacity(0.15)
                            : AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: showFilters.value
                                ? AppTheme.primaryGreen
                                : AppTheme.glassBorder),
                      ),
                      child: Icon(Icons.filter_list_rounded,
                          color: showFilters.value
                              ? AppTheme.primaryGreen
                              : AppTheme.textSecondary,
                          size: 20),
                    ),
                  )),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Obx(() => Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => showGuestRequests.value = false,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: !showGuestRequests.value ? AppTheme.primaryGradient : null,
                        color: showGuestRequests.value ? AppTheme.surfaceColor : null,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: !showGuestRequests.value ? Colors.transparent : AppTheme.glassBorder),
                        boxShadow: !showGuestRequests.value ? AppTheme.greenGlow : null,
                      ),
                      alignment: Alignment.center,
                      child: Text('طلبات الأعضاء',
                          style: TextStyle(
                              color: !showGuestRequests.value ? Colors.black : AppTheme.textSecondary,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => showGuestRequests.value = true,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: showGuestRequests.value ? AppTheme.primaryGradient : null,
                        color: !showGuestRequests.value ? AppTheme.surfaceColor : null,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: showGuestRequests.value ? Colors.transparent : AppTheme.glassBorder),
                        boxShadow: showGuestRequests.value ? AppTheme.greenGlow : null,
                      ),
                      alignment: Alignment.center,
                      child: Text('طلبات الزوار',
                          style: TextStyle(
                              color: showGuestRequests.value ? Colors.black : AppTheme.textSecondary,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            )),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: searchController,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: AppTheme.inputDecoration('ابحث بالاسم أو الهاتف أو المنطقة...', Icons.search_rounded),
            ),
          ),

          Obx(() => adminController.shouldShowSwipeHint.value
              ? FadeInDown(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppTheme.primaryGreen.withValues(alpha: 0.1), AppTheme.primaryGreen.withValues(alpha: 0.05)]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppTheme.primaryGreen, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'تلميحة: يمكنك سحب أي طلب لجهة اليمين لرفضه بسرعة.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close, color: AppTheme.textHint, size: 18),
                          onPressed: () => adminController.markSwipeHintAsShown(),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink()),

          Obx(() => showFilters.value
              ? AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 60,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildFilterChip('نوع الخدمة', selectedServiceType, ['الكل', ...AppConstants.defaultServiceTypes],
                            ['all', ...AppConstants.defaultServiceTypes]),
                        const SizedBox(width: 8),
                        _buildFilterChip('الاستعجال', selectedUrgency, ['الكل', 'عادي', 'مستعجل', 'طارئ'],
                            ['all', 'normal', 'urgent', 'emergency']),
                        const SizedBox(width: 8),
                        _buildFilterChip('الولاية', selectedWilaya, ['الكل', ...AppConstants.algeriaWilayas],
                            ['all', ...AppConstants.algeriaWilayas]),
                        const SizedBox(width: 8),
                        if (selectedWilaya.value != 'all')
                          _buildFilterChip('البلدية', selectedCommune, ['الكل', ...AppConstants.getCommunesForWilaya(selectedWilaya.value)],
                              ['all', ...AppConstants.getCommunesForWilaya(selectedWilaya.value)]),
                        const SizedBox(width: 8),
                        _buildFilterChip('الفترة', selectedPeriod, ['الكل', 'اليوم', 'الأسبوع', 'الشهر'],
                            ['all', 'today', 'week', 'month']),
                        const SizedBox(width: 8),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection(AppConstants.usersCollection)
                              .where('role', isEqualTo: 'worker')
                              .snapshots(),
                          builder: (context, snapshot) {
                            List<String> names = ['الكل'];
                            List<String> ids = ['all'];
                            if (snapshot.hasData) {
                              for (var doc in snapshot.data!.docs) {
                                names.add(doc['name']);
                                ids.add(doc.id);
                              }
                            }
                            return _buildFilterChip('العامل', selectedWorker, names, ids);
                          },
                        ),
                        if (anyFilterActive)
                          TextButton.icon(
                            onPressed: clearAllFilters,
                            icon: const Icon(Icons.clear_all, color: AppTheme.errorColor),
                            label: const Text('مسح الكل', style: TextStyle(color: AppTheme.errorColor)),
                          ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink()),

          Container(
            color: AppTheme.surfaceColor,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection(showGuestRequests.value ? 'guest_requests' : AppConstants.serviceRequestsCollection).snapshots(),
              builder: (context, snapshot) {
                countByStatus = {'الكل': 0, 'معلق': 0, 'جاري': 0, 'مكتمل': 0, 'مرفوض': 0};
                if (snapshot.hasError) return const Center(child: Text('خطأ في تحميل العدادات', style: TextStyle(color: AppTheme.errorColor)));
                if (!snapshot.hasData) return const Center(child: SizedBox(height: 2, child: LinearProgressIndicator(color: AppTheme.primaryGreen)));

                countByStatus['الكل'] = snapshot.data!.docs.length;
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  String status = data['status'] ?? 'pending';
                  if (status == 'pending') countByStatus['معلق'] = (countByStatus['معلق'] ?? 0) + 1;
                  if (status == 'in_progress') countByStatus['جاري'] = (countByStatus['جاري'] ?? 0) + 1;
                  if (status == 'completed') countByStatus['مكتمل'] = (countByStatus['مكتمل'] ?? 0) + 1;
                  if (status == 'rejected') countByStatus['مرفوض'] = (countByStatus['مرفوض'] ?? 0) + 1;
                }

                return TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppTheme.primaryGreen,
                  unselectedLabelColor: AppTheme.textHint,
                  indicator: const UnderlineTabIndicator(
                    borderSide: BorderSide(color: AppTheme.primaryGreen, width: 3),
                  ),
                  tabs: tabs.map((t) {
                    return Tab(
                      child: Row(
                        children: [
                          Text(t),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              countByStatus[t]?.toString() ?? '0',
                              style: const TextStyle(fontSize: 10, color: AppTheme.primaryGreen),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          Expanded(
            child: Obx(() {
              final status = selectedStatus.value;
              final isGuest = showGuestRequests.value;

              return StreamBuilder<QuerySnapshot>(
                stream: _buildQuery().snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: AppTheme.errorColor, size: 40),
                          const SizedBox(height: 16),
                          Text('حدث خطأ في عرض الطلبات', style: TextStyle(color: AppTheme.textPrimary)),
                          const SizedBox(height: 8),
                          Text('تأكد من اتصالك بالإنترنت', 
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          TextButton(onPressed: () => setState(() {}), child: const Text('إعادة المحاولة')),
                        ],
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  var filteredDocs = snapshot.data!.docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    if (status == 'all' && data['status'] == 'rejected') return false;
                    String queryText = searchController.text.trim().toLowerCase();
                    if (queryText.isEmpty) return true;
                    String rName = (data['requesterName'] ?? data['name'] ?? '').toString().toLowerCase();
                    String rPhone = (data['phone'] ?? '').toString();
                    String rWilaya = (data['wilaya'] ?? '').toString().toLowerCase();
                    String rCommune = (data['commune'] ?? '').toString().toLowerCase();
                    return rName.contains(queryText) || rPhone.contains(queryText) || rWilaya.contains(queryText) || rCommune.contains(queryText);
                  }).toList();

                  if (filteredDocs.isEmpty) return _buildEmptyState();

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 20),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      var doc = filteredDocs[index];
                      var request = ServiceRequestModel.fromMap({
                        ...doc.data() as Map<String, dynamic>,
                        'id': doc.id,
                        'isGuest': isGuest,
                      });
                      return _buildRequestCard(request);
                    },
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, RxString value, List<String> options, List<String> optionValues) {
    return Obx(() {
      int currentIndex = optionValues.indexOf(value.value);
      String currentLabel = currentIndex != -1 ? options[currentIndex] : label;

      return Container(
        margin: const EdgeInsets.only(right: 8),
        child: PopupMenuButton<String>(
          initialValue: value.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: value.value == 'all' ? Theme.of(context).cardColor : AppTheme.primaryGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: value.value == 'all' ? Colors.grey.withValues(alpha: 0.1) : AppTheme.primaryGreen),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentLabel,
                  style: TextStyle(
                    color: value.value == 'all' ? AppTheme.textSecondary : AppTheme.primaryGreen,
                    fontSize: 13,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: value.value == 'all' ? AppTheme.textHint : AppTheme.primaryGreen,
                  size: 18,
                ),
              ],
            ),
          ),
          itemBuilder: (context) => List.generate(
            options.length,
            (index) => PopupMenuItem(
              value: optionValues[index],
              child: Text(options[index]),
            ),
          ),
          onSelected: (v) {
            value.value = v;
            if (label == 'الولاية') selectedCommune.value = 'all';
          },
        ),
      );
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: AppTheme.textHint.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('لا توجد طلبات حالياً', style: TextStyle(color: AppTheme.textHint, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildRequestCard(ServiceRequestModel request) {
    Color urgencyColor = request.urgency == 'emergency'
        ? AppTheme.errorColor
        : (request.urgency == 'urgent' ? AppTheme.warningColor : AppTheme.primaryGreen);

    return GestureDetector(
      onTap: () => Get.toNamed('/admin/request-detail', arguments: request),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border(right: BorderSide(color: urgencyColor, width: 4)),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Dismissible(
          key: Key(request.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            final result = await Get.dialog<bool>(
              AlertDialog(
                backgroundColor: AppTheme.surfaceColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
                    SizedBox(width: 8),
                    Text('تأكيد الرفض', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                  ],
                ),
                content: const Text('هل أنت متأكد من رفض هذا الطلب؟ سيتم نقله إلى تبويب المرفوضات.',
                    style: TextStyle(fontFamily: 'Tajawal')),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(result: false),
                    child: const Text('إلغاء', style: TextStyle(color: AppTheme.textHint)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () => Get.back(result: true),
                    child: const Text('رفض الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              barrierDismissible: false,
            );
            return result ?? false;
          },
          onDismissed: (direction) {
            adminController.updateRequestStatus(request.id, 'rejected', isGuest: showGuestRequests.value);
          },
          background: Container(
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.only(right: 20),
            alignment: Alignment.centerRight,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('رفض سريع', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                const Icon(Icons.delete_outline, color: AppTheme.errorColor),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.volunteer_activism, color: AppTheme.primaryGreen, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppConstants.translateServiceType(request.typeName.isNotEmpty ? request.typeName : request.type),
                              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                          Text('#${request.id.substring(0, 8)}', style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
                        ],
                      ),
                    ),
                    _buildStatusBadge(request.urgency, isUrgency: true),
                    const SizedBox(width: 6),
                    _buildStatusBadge(request.status),
                  ],
                ),
                const Divider(color: Colors.white10, height: 20),
                (request.requesterId.isNotEmpty)
                    ? StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection(AppConstants.usersCollection).doc(request.requesterId).snapshots(),
                        builder: (context, snapshot) {
                          String name = request.requesterName.isNotEmpty ? request.requesterName : 'مستخدم';
                          String wilaya = request.wilaya.isNotEmpty ? request.wilaya : '—';
                          String commune = request.commune.isNotEmpty ? request.commune : '';
                          if (snapshot.hasData && snapshot.data!.exists) {
                            var userData = snapshot.data!.data() as Map<String, dynamic>;
                            if (name == 'مستخدم' || name.isEmpty) name = userData['name'] ?? 'مستخدم';
                            if (wilaya == '—' || wilaya.isEmpty) wilaya = userData['wilaya'] ?? '—';
                            if (commune.isEmpty) commune = userData['commune'] ?? '';
                          }
                          final location = commune.isNotEmpty ? '$wilaya - $commune' : wilaya;
                          return Row(
                            children: [
                              const Icon(Icons.person_outline, color: AppTheme.textHint, size: 16),
                              const SizedBox(width: 6),
                              Expanded(child: Text(name, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13), overflow: TextOverflow.ellipsis)),
                              const Icon(Icons.location_on_outlined, color: AppTheme.textHint, size: 16),
                              const SizedBox(width: 4),
                              Flexible(child: Text(location, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis)),
                            ],
                          );
                        },
                      )
                    : Row(
                        children: [
                          const Icon(Icons.person_outline, color: AppTheme.textHint, size: 16),
                          const SizedBox(width: 6),
                          Expanded(child: Text(request.requesterName.isNotEmpty ? request.requesterName : 'زائر', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13), overflow: TextOverflow.ellipsis)),
                          const Icon(Icons.location_on_outlined, color: AppTheme.textHint, size: 16),
                          const SizedBox(width: 4),
                          Flexible(child: Builder(builder: (ctx) {
                            final loc = [request.wilaya, request.commune].where((s) => s.isNotEmpty).join(' - ');
                            return Text(loc.isEmpty ? '—' : loc, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis);
                          })),
                        ],
                      ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: AppTheme.textHint, size: 16),
                    const SizedBox(width: 6),
                    Text(timeago.format(request.createdAt, locale: 'ar'),
                        style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                    const Spacer(),
                    if (request.assignedToName != null && request.assignedToName!.isNotEmpty)
                      Row(
                        children: [
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance.collection(AppConstants.usersCollection).doc(request.assignedTo).snapshots(),
                            builder: (context, snapshot) {
                              String? imageUrl;
                              if (snapshot.hasData && snapshot.data!.exists) {
                                imageUrl = (snapshot.data!.data() as Map<String, dynamic>)['profileImage'];
                              }
                              return CircleAvatar(
                                radius: 10,
                                backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                                backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
                                child: (imageUrl == null || imageUrl.isEmpty)
                                  ? Text(request.assignedToName![0], style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 10))
                                  : null,
                              );
                            }
                          ),
                          const SizedBox(width: 4),
                          Text(request.assignedToName!, style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 12)),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildActionButton(Icons.phone, 'اتصال', Colors.green, () => launchUrl(Uri.parse('tel:${request.phone}'))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        request.assignedTo == null ? Icons.assignment_ind_outlined : Icons.swap_horiz,
                        request.assignedTo == null ? 'إسناد عامل' : 'تغيير العامل',
                        request.assignedTo == null ? AppTheme.primaryGreen : AppTheme.warningColor,
                        () => _showAssignWorkerDialog(request),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(Icons.update, 'الحالة', AppTheme.warningColor, () => _showStatusUpdateSheet(request)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, {bool isUrgency = false}) {
    Color color = AppTheme.primaryGreen;
    String label = status;

    if (isUrgency) {
      switch (status) {
        case 'emergency': color = AppTheme.errorColor; label = 'طارئ'; break;
        case 'urgent': color = AppTheme.warningColor; label = 'مستعجل'; break;
        case 'normal': color = AppTheme.successColor; label = 'عادي'; break;
      }
    } else {
      switch (status) {
        case 'pending': color = AppTheme.warningColor; label = 'معلق'; break;
        case 'in_progress': color = Colors.blue; label = 'جاري'; break;
        case 'completed': color = AppTheme.successColor; label = 'مكتمل'; break;
        case 'rejected': color = AppTheme.errorColor; label = 'مرفوض'; break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _showAssignWorkerDialog(ServiceRequestModel request) {
    Get.bottomSheet(
      DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              Text('اختر العامل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن عامل...',
                    hintStyle: TextStyle(color: AppTheme.textHint),
                    prefixIcon: Icon(Icons.search, color: AppTheme.primaryGreen),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(AppConstants.usersCollection)
                      .where('role', isEqualTo: 'worker')
                      .where('isApproved', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    var workers = snapshot.data!.docs;
                    return ListView.builder(
                      controller: controller,
                      itemCount: workers.length,
                      itemBuilder: (context, index) {
                        var worker = workers[index].data() as Map<String, dynamic>;
                        String workerId = workers[index].id;
                        String? imageUrl = worker['profileImage'];

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                            backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
                            child: (imageUrl == null || imageUrl.isEmpty)
                              ? Text(worker['name'][0], style: const TextStyle(color: AppTheme.primaryGreen))
                              : null,
                          ),
                          title: Text(worker['name'], style: TextStyle(color: AppTheme.textPrimary)),
                          subtitle: Text(worker['phone'] ?? '', style: const TextStyle(color: AppTheme.textHint)),
                          onTap: () {
                            adminController.assignToWorker(request.id, workerId, workerName: worker['name'], isGuest: showGuestRequests.value);
                            Get.back();
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showAssignVehicleDialog(ServiceRequestModel request) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('إسناد سيارة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(AppConstants.vehiclesCollection)
                  .where('isAvailable', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                var vehicles = snapshot.data!.docs;
                if (vehicles.isEmpty) return Text('لا توجد سيارات متاحة', style: TextStyle(color: AppTheme.textHint));
                return Column(
                  children: vehicles.map((v) {
                    var data = v.data() as Map<String, dynamic>;
                    return ListTile(
                      leading: const Icon(Icons.airport_shuttle, color: AppTheme.primaryGreen),
                      title: Text(data['plateNumber'], style: TextStyle(color: AppTheme.textPrimary)),
                      subtitle: Text(data['type'], style: const TextStyle(color: AppTheme.textHint)),
                      onTap: () {
                        adminController.assignToVehicle(request.id, v.id, isGuest: showGuestRequests.value);
                        Get.back();
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusUpdateSheet(ServiceRequestModel request) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تغيير الحالة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            ...['pending', 'in_progress', 'completed', 'rejected'].map((status) {
              bool isSelected = request.status == status;
              Color statusColor = status == 'pending'
                  ? AppTheme.warningColor
                  : (status == 'in_progress' ? Colors.blue : (status == 'completed' ? AppTheme.successColor : AppTheme.errorColor));

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () {
                    if (!isSelected) {
                      adminController.updateRequestStatus(request.id, status, isGuest: showGuestRequests.value);
                      Get.back();
                    }
                  },
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  tileColor: isSelected ? statusColor.withValues(alpha: 0.15) : Theme.of(context).cardColor,
                  leading: Icon(
                    status == 'pending' ? Icons.timer : (status == 'in_progress' ? Icons.sync : (status == 'completed' ? Icons.check_circle : Icons.cancel)),
                    color: statusColor,
                  ),
                  title: Text(
                    status == 'pending' ? 'معلق' : (status == 'in_progress' ? 'جاري التنفيذ' : (status == 'completed' ? 'مكتمل' : 'مرفوض')),
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                  ),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.primaryGreen) : null,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

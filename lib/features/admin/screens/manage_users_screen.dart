import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import '../controllers/admin_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user_model.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/user_avatar.dart';
import '../../../core/animations/scroll_animations.dart';
import '../../../data/services/export_service.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final AdminController _adminCtl = Get.find<AdminController>();
  final TextEditingController _searchController = TextEditingController();
  
  int _currentIndex = 0; // 0 for Pending, 1 for All Users
  String _searchQuery = "";
  String? _selectedBloodType; // null for all
  String? _selectedService; // 🆕 فلتر الخدمة
  String? _selectedGenderFilter; // 🆕 فلتر الجنس
  String? _selectedExpertise; // 🆕 فلتر الخبرة (خبير/مساعد)

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header Section - Scrolls away to give more space
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildUserCounter(),
                  _buildCustomToggle(),
                  if (_currentIndex == 2) ...[
                    _buildSearchBar(),
                    _buildBloodTypeFilters(),
                    _buildWorkerFilters(),
                  ],
                ],
              ),
            ),
            
            // List Section - Takes the remaining space
            _currentIndex == 0 
                ? _buildPendingSliver() 
                : (_currentIndex == 1 ? _buildVerificationSliver() : _buildAllUsersSliver()),
            
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  color: AppTheme.textPrimary,
                  onPressed: () => Get.back(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إدارة المستخدمين', 
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w900),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('التحكم في حسابات وصلاحيات الأعضاء', 
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: _exportData,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.file_download_outlined, color: AppTheme.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    try {
      Get.dialog(const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)), barrierDismissible: false);
      
      var snapshot = await FirebaseFirestore.instance.collection(AppConstants.usersCollection).get();
      List<UserModel> allUsers = snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
      
      if (Get.isDialogOpen ?? false) Get.back(); // close loading
      
      await ExportService.exportUsersToExcel(allUsers);
      
    } catch(e) {
      if (Get.isDialogOpen ?? false) Get.back();
      debugPrint('Export Error: $e');
      Get.snackbar('خطأ', 'فشل تجهيز البيانات للتصدير', backgroundColor: Colors.red.withValues(alpha: 0.15), colorText: Colors.white);
    }
  }

  Widget _buildUserCounter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: FadeInDown(
        duration: const Duration(milliseconds: 600),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_pin_rounded, color: AppTheme.primaryGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text('إجمالي المشتركين المسجلين:', 
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontFamily: 'Tajawal'),
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis),
              ),
              const Spacer(),
              Obx(() => ScrollAnimations.numberCounter(
                value: _adminCtl.totalRegisteredUsers.value,
                style: TextStyle(
                  color: AppTheme.textPrimary, 
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              )),
              const SizedBox(width: 8),
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Row(
          children: [
            _buildToggleOption(0, 'طلبات التسجيل', Icons.person_add_rounded),
            _buildToggleOption(1, 'توثيق الهوية', Icons.vignette_rounded),
            _buildToggleOption(2, 'كل المستخدمين', Icons.group_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleOption(int index, String title, IconData icon) {
    bool isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.primaryGradient : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
            boxShadow: isSelected ? AppTheme.greenGlow : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.black : AppTheme.textHint, size: 16),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.black : AppTheme.textHint,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 5, 20, 10),
      child: FadeInDown(
        duration: const Duration(milliseconds: 300),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: AppTheme.inputDecoration('البحث بالاسم أو الهاتف...', Icons.search_rounded),
        ),
      ),
    );
  }

  Widget _buildBloodTypeFilters() {
    final List<String> bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    return FadeInDown(
      delay: const Duration(milliseconds: 100),
      child: Container(
        height: 45,
        margin: const EdgeInsets.only(bottom: 10),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _buildFilterChip('الكل', null),
            ...bloodTypes.map((type) => _buildFilterChip(type, type)),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerFilters() {
    final List<Map<String, dynamic>> workerServices = [
      {'id': 'funeral_transport', 'name': 'جنائز', 'icon': Icons.airport_shuttle_rounded},
      {'id': 'funeral_ghusl', 'name': 'تغسيل', 'icon': Icons.wash_rounded},
      {'id': 'medical_aid', 'name': 'إسعاف', 'icon': Icons.medical_services_rounded},
      {'id': 'food_aid', 'name': 'توزيع', 'icon': Icons.shopping_bag_rounded},
      {'id': 'construction', 'name': 'ترميم', 'icon': Icons.construction_rounded},
    ];

    return FadeInDown(
      delay: const Duration(milliseconds: 150),
      child: Column(
        children: [
          Container(
            height: 38,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildGenderFilterChip('الجميع', null),
                _buildGenderFilterChip('رجال', 'ذكر'),
                _buildGenderFilterChip('نساء', 'أنثى'),
              ],
            ),
          ),
          Container(
            height: 42,
            margin: const EdgeInsets.only(bottom: 10),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildServiceFilterChip('كل الخدمات', null, Icons.all_inclusive_rounded),
                ...workerServices.map((s) => _buildServiceFilterChip(s['name'], s['id'], s['icon'])),
              ],
            ),
          ),
          if (_selectedService == 'funeral_ghusl')
            FadeInLeft(
              child: Container(
                height: 38,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildExpertiseFilterChip('الكل', null),
                    _buildExpertiseFilterChip('خبراء فقط', 'expert'),
                    _buildExpertiseFilterChip('مساعدين فقط', 'assistant'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpertiseFilterChip(String label, String? expertise) {
    bool isSelected = _selectedExpertise == expertise;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.white : AppTheme.textSecondary, fontSize: 11)),
        selected: isSelected,
        onSelected: (val) => setState(() => _selectedExpertise = val ? expertise : null),
        selectedColor: Colors.orangeAccent.withValues(alpha: 0.15),
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildGenderFilterChip(String label, String? gender) {
    bool isSelected = _selectedGenderFilter == gender;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.black : AppTheme.textSecondary, fontSize: 12)),
        selected: isSelected,
        onSelected: (val) => setState(() => _selectedGenderFilter = val ? gender : null),
        selectedColor: Colors.blueAccent.withValues(alpha: 0.15),
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _buildServiceFilterChip(String label, String? serviceId, IconData icon) {
    bool isSelected = _selectedService == serviceId;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        avatar: Icon(icon, size: 14, color: isSelected ? Colors.black : AppTheme.primaryGreen),
        label: Text(label, style: TextStyle(color: isSelected ? Colors.black : AppTheme.textSecondary, fontSize: 12)),
        selected: isSelected,
        onSelected: (val) => setState(() => _selectedService = val ? serviceId : null),
        selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _buildFilterChip(String label, String? type) {
    bool isSelected = _selectedBloodType == type;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(
          color: isSelected ? Colors.black : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        )),
        selected: isSelected,
        onSelected: (val) => setState(() => _selectedBloodType = val ? type : null),
        selectedColor: AppTheme.primaryGreen,
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? AppTheme.primaryGreen : AppTheme.glassBorder),
        ),
      ),
    );
  }

  Widget _buildVerificationSliver() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .where('isVerified', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
              child: Center(
                  child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: SelectableText('حدث خطأ: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center),
          )));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
              child: Center(
                  child: Padding(
            padding: EdgeInsets.all(40.0),
            child: CircularProgressIndicator(color: AppTheme.primaryGreen),
          )));
        }

        var docs = snapshot.data?.docs.where((doc) {
          var data = doc.data();
          return data['nationalIdUrl'] != null &&
              data['nationalIdUrl'].toString().isNotEmpty;
        }).toList() ?? [];

        if (docs.isEmpty) {
          return SliverFillRemaining(
              child: _buildEmptyState('لا توجد طلبات توثيق بانتظار المراجعة'));
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                var data = docs[index].data();
                UserModel user = UserModel.fromMap(data, docs[index].id);

                return FadeInUp(
                  duration: const Duration(milliseconds: 400),
                  delay: Duration(milliseconds: 50 * (index % 10)),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.glassDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildAvatar(user),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.name,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppTheme.textPrimary)),
                                  Text(user.phone,
                                      style: TextStyle(
                                          color: AppTheme.textHint,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            _buildStatusBadge(
                                'بانتظار المراجعة', AppTheme.warningColor),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text("صورة بطاقة التعريف الوطنية:",
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => _showUserDetails(user),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 150,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundColor,
                                border: Border.all(color: AppTheme.glassBorder),
                              ),
                              child: Hero(
                                tag: 'id_card_${user.id}',
                                child: Image.network(
                                  user.nationalIdUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Center(
                                          child: Icon(Icons.error_outline,
                                              color: AppTheme.errorColor)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Obx(() => AppTheme.gradientButton(
                                text: "توثيق وتوليد رقم العضوية",
                                icon: Icons.verified_rounded,
                                isLoading: _adminCtl.isLoading.value,
                                onPressed: () =>
                                    _adminCtl.verifyUserIdentity(user.id),
                              )),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              onPressed: () => _showUserDetails(user),
                              icon: Icon(Icons.info_outline,
                                  color: AppTheme.goldAccent),
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    AppTheme.goldAccent.withValues(alpha: 0.1),
                                padding: const EdgeInsets.all(12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: docs.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingSliver() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(AppConstants.usersCollection).where('isApproved', isEqualTo: false).orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SliverToBoxAdapter(child: Center(child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: SelectableText('حدث خطأ: ${snapshot.error}', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
          )));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(child: Center(child: Padding(
            padding: EdgeInsets.all(40.0),
            child: CircularProgressIndicator(color: AppTheme.primaryGreen),
          )));
        }
        
        var docs = snapshot.data?.docs.where((doc) {
          var data = doc.data();
          if (data['role'] == 'rejected') return false; // Hide rejected
          return true;
        }).toList() ?? [];

        if (docs.isEmpty) return SliverFillRemaining(child: _buildEmptyState('لا توجد حسابات معلقة حالياً'));

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                var data = docs[index].data();
                UserModel user = UserModel.fromMap(data, docs[index].id);
                UserRole selectedRole = user.role;

                return FadeInUp(
                  duration: const Duration(milliseconds: 400),
                  delay: Duration(milliseconds: 50 * (index % 10)),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.glassDecoration,
                    child: StatefulBuilder(
                      builder: (context, setStateLocal) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildAvatar(user),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(user.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
                                    Text(DateFormat('yyyy-MM-dd').format(user.createdAt), style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
                                  ],
                                ),
                              ),
                              _buildStatusBadge('معلق', AppTheme.warningColor),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(color: AppTheme.glassBorder, height: 1),
                          ),
                          if (_adminCtl.currentUser?.role == UserRole.superAdmin) ...[
                            _buildUserInfoRow(Icons.phone_outlined, "الهاتف", user.phone),
                            const SizedBox(height: 8),
                            _buildUserInfoRow(Icons.location_on_outlined, "الولاية", user.wilaya),
                            const SizedBox(height: 8),
                            _buildUserInfoRow(Icons.map_outlined, "البلدية", user.commune),
                          ],
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.glassBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<UserRole>(
                                isExpanded: true,
                                dropdownColor: AppTheme.surfaceColor,
                                icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.primaryGreen),
                                value: selectedRole,
                                items: [
                                  DropdownMenuItem(value: UserRole.worker, child: Text(UserRole.worker.displayName, style: TextStyle(color: AppTheme.textPrimary))),
                                  DropdownMenuItem(value: UserRole.donor, child: Text(UserRole.donor.displayName, style: TextStyle(color: AppTheme.textPrimary))),
                                  DropdownMenuItem(value: UserRole.beneficiary, child: Text(UserRole.beneficiary.displayName, style: TextStyle(color: AppTheme.textPrimary))),
                                  DropdownMenuItem(value: UserRole.admin, child: Text(UserRole.admin.displayName, style: TextStyle(color: AppTheme.textPrimary))),
                                  if (_adminCtl.currentUser?.role == UserRole.superAdmin)
                                    DropdownMenuItem(value: UserRole.superAdmin, child: Text(UserRole.superAdmin.displayName, style: TextStyle(color: AppTheme.textPrimary))),
                                ],
                                onChanged: (val) => setStateLocal(() => selectedRole = val!),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: AppTheme.gradientButton(
                                  text: "قبول وتفعيل",
                                  icon: Icons.check_circle_outline,
                                  onPressed: () => _adminCtl.approveUser(user.id, selectedRole),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  side: const BorderSide(color: AppTheme.errorColor),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: () => _adminCtl.rejectUser(user.id),
                                icon: const Icon(Icons.close, color: AppTheme.errorColor, size: 20),
                                label: const Text("رفض", style: TextStyle(fontFamily: 'Tajawal', color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
              childCount: docs.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllUsersSliver() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(AppConstants.usersCollection).where('isApproved', isEqualTo: true).orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SliverToBoxAdapter(child: Center(child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: SelectableText('حدث خطأ: ${snapshot.error}', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
          )));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(child: Center(child: Padding(
            padding: EdgeInsets.all(40.0),
            child: CircularProgressIndicator(color: AppTheme.primaryGreen),
          )));
        }
        
        var docs = snapshot.data?.docs.where((doc) {
          var data = doc.data();
          UserModel user = UserModel.fromMap(data, doc.id);
          
          String rName = user.name.toLowerCase();
          String rPhone = user.phone;
          String? bType = user.bloodType;
          String rGender = user.gender;
          List<String> services = user.volunteerServices;

          bool matchesSearch = rName.contains(_searchQuery) || rPhone.contains(_searchQuery);
          bool matchesBlood = _selectedBloodType == null || bType == _selectedBloodType;
          bool matchesGender = _selectedGenderFilter == null || rGender.contains(_selectedGenderFilter!);
          bool matchesService = _selectedService == null || services.contains(_selectedService);
          bool matchesExpertise = _selectedExpertise == null || user.ghuslExpertise == _selectedExpertise;
          
          return matchesSearch && matchesBlood && matchesGender && matchesService && matchesExpertise;
        }).toList() ?? [];

        if (docs.isEmpty) return SliverFillRemaining(child: _buildEmptyState('لا توجد مستخدمين يطابقون البحث'));

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                UserModel user = UserModel.fromMap(docs[index].data(), docs[index].id);
                bool isSuperAdmin = _adminCtl.currentUser?.role == UserRole.superAdmin;

                return FadeInUp(
                  duration: const Duration(milliseconds: 300),
                  delay: Duration(milliseconds: 30 * (index % 15)),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: AppTheme.glassDecoration,
                    child: Row(
                      children: [
                        _buildAvatar(user),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // Role Badge
                                  _buildBadge(
                                    text: user.role.displayName,
                                    icon: Icons.shield_outlined,
                                    color: AppTheme.primaryGreen,
                                  ),

                                  // Blood Type Badge
                                  if (isSuperAdmin && user.bloodType != null) 
                                    _buildBloodTypeBadge(user),

                                  // Verification / Member ID Badge
                                  if (user.isVerified) 
                                    _buildBadge(
                                      text: user.memberId ?? 'موثق',
                                      icon: Icons.verified_user_rounded,
                                      color: Colors.blue,
                                    ),

                                  // Phone Badge
                                  if (isSuperAdmin)
                                    _buildBadge(
                                      text: user.phone,
                                      icon: Icons.phone_outlined,
                                      color: AppTheme.textHint,
                                    ),
                                ],
                              )
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          color: AppTheme.surfaceColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: AppTheme.glassBorder)),
                          icon: Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
                          onSelected: (val) {
                            if (val == 'disable') _adminCtl.rejectUser(user.id);
                            if (val == 'change_role') _showChangeRoleDialog(user);
                            if (val == 'view_details') _showUserDetails(user);
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'view_details', child: Row(children: [Icon(Icons.info_outline, color: AppTheme.goldAccent, size: 18), const SizedBox(width: 8), Text("تفاصيل العضو", style: TextStyle(color: AppTheme.textPrimary))])),
                            if (isSuperAdmin)
                              PopupMenuItem(value: 'change_role', child: Row(children: [Icon(Icons.edit_outlined, color: AppTheme.primaryGreen, size: 18), const SizedBox(width: 8), Text("تغيير الصلاحية", style: TextStyle(color: AppTheme.textPrimary))])),
                            PopupMenuItem(value: 'disable', child: Row(children: [Icon(Icons.block_flipped, color: AppTheme.errorColor, size: 18), const SizedBox(width: 8), Text("إيقاف الحساب", style: TextStyle(color: AppTheme.errorColor))])),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: docs.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return FadeIn(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off_outlined, size: 80, color: AppTheme.textHint.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: AppTheme.textHint, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(UserModel user) {
    return UserAvatar(
      user: user,
      size: 44,
      showBadge: true,
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildBadge({required String text, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
        ],
      ),
    );
  }

  Widget _buildBloodTypeBadge(UserModel user) {
    bool isAvailable = user.isDonorAvailable;
    Color color = isAvailable ? AppTheme.errorColor : AppTheme.textHint;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bloodtype_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(user.bloodType ?? '?', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
          if (!isAvailable && user.lastDonatedAt != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.timer_outlined, size: 12, color: color),
          ],
        ],
      ),
    );
  }

  Widget _buildUserInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textHint, size: 18),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
        Expanded(
          child: Text(
            value, 
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showChangeRoleDialog(UserModel user) {
    UserRole selectedRole = user.role;
    List<String> selectedAdditionalRoles = List.from(user.additionalRoles);
    bool canManageSabil = user.canManageDarSabil;
    bool isAuthorizedToGrantSuperAdmin = _adminCtl.currentUser?.role == UserRole.superAdmin;

    Get.bottomSheet(
      StatefulBuilder(builder: (context, setSheetState) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.15), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20)],
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("تغيير صلاحيات '${user.name}'", style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.glassBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<UserRole>(
                        isExpanded: true,
                        dropdownColor: AppTheme.surfaceColor,
                        value: selectedRole,
                        style: TextStyle(color: AppTheme.textPrimary),
                        items: UserRole.values.map((role) {
                          if (role == UserRole.superAdmin && !isAuthorizedToGrantSuperAdmin) return null;
                          return DropdownMenuItem(
                            value: role, 
                            child: Row(
                              children: [
                                Text(role.displayName),
                                if (role == UserRole.superAdmin) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.stars_rounded, color: AppTheme.goldAccent, size: 18),
                                ],
                              ],
                            ),
                          );
                        }).whereType<DropdownMenuItem<UserRole>>().toList(),
                        onChanged: (val) => setSheetState(() => selectedRole = val!),
                      ),
                    ),
                  ),
                  if (selectedRole == UserRole.superAdmin && user.role != UserRole.superAdmin)
                    FadeInDown(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.goldAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: AppTheme.goldAccent, size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                "تنبيه: أنت الآن تمنح هذا المستخدم كامل صلاحيات 'المنسق العام' (Super Admin).",
                                style: TextStyle(color: AppTheme.goldAccent, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text("صلاحيات إضافية (اختياري)", style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    title: Text("صلاحية التبرع (دم / مال)", style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                    value: selectedAdditionalRoles.contains('canDonate'),
                    activeColor: AppTheme.primaryGreen,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setSheetState(() {
                        if (val == true) {
                          selectedAdditionalRoles.add('canDonate');
                        } else {
                          selectedAdditionalRoles.remove('canDonate');
                        }
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: Text("صلاحية طلب خدمة (مستفيد)", style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                    value: selectedAdditionalRoles.contains('canRequestService'),
                    activeColor: AppTheme.primaryGreen,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setSheetState(() {
                        if (val == true) {
                          selectedAdditionalRoles.add('canRequestService');
                        } else {
                          selectedAdditionalRoles.remove('canRequestService');
                        }
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: Text("صلاحية إدارة دار السبيل 🏠", style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                    subtitle: Text("تمكن المستخدم من الوصول لشاشة إدارة النزلاء والمهام", style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    value: canManageSabil,
                    activeColor: AppTheme.goldAccent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setSheetState(() {
                        canManageSabil = val ?? false;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            side: const BorderSide(color: AppTheme.glassBorder),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Get.back(),
                          child: Text("إلغاء", style: TextStyle(color: AppTheme.textPrimary)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppTheme.gradientButton(
                          text: "حفظ التغييرات",
                          icon: Icons.save_rounded,
                          onPressed: () {
                            _adminCtl.approveUser(
                              user.id, 
                              selectedRole, 
                              additionalRoles: selectedAdditionalRoles,
                              canManageDarSabil: canManageSabil,
                            );
                            Get.back();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      }),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
    );
  }

  void _showUserDetails(UserModel user) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAvatar(user),
              const SizedBox(height: 16),
              Text(user.name, style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              if (_adminCtl.currentUser?.role == UserRole.superAdmin) ...[
                _buildUserInfoRow(Icons.phone_outlined, "رقم الهاتف", user.phone),
                const SizedBox(height: 12),
                _buildUserInfoRow(Icons.location_on_outlined, "الولاية", user.wilaya),
                const SizedBox(height: 12),
                _buildUserInfoRow(Icons.map_outlined, "البلدية", user.commune),
                const SizedBox(height: 12),
                _buildUserInfoRow(Icons.home_outlined, "العنوان", user.address),
                const SizedBox(height: 12),
              ],
              _buildUserInfoRow(Icons.badge_outlined, "الرتبة الأساسية", user.role.displayName),
              if (user.additionalRoles.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildUserInfoRow(
                  Icons.playlist_add_check_circle_rounded, 
                  "صلاحيات إضافية", 
                  user.additionalRoles.map((r) => r == 'canDonate' ? 'التبرع' : r == 'canRequestService' ? 'الاستفادة' : r).join('، ')
                ),
              ],
              if (user.canManageDarSabil) ...[
                const SizedBox(height: 12),
                _buildUserInfoRow(Icons.home_work_rounded, "إدارة دار السبيل", "مُفوض ✅"),
              ],
              const SizedBox(height: 12),
              _buildUserInfoRow(Icons.male_rounded, "الجنس", user.gender),
              if (_adminCtl.currentUser?.role == UserRole.superAdmin) ...[
                const SizedBox(height: 12),
                _buildUserInfoRow(Icons.bloodtype_outlined, "فصيلة الدم", user.bloodType ?? "غير محدد"),
              ],
              if (user.role == UserRole.worker) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                _buildUserInfoRow(Icons.volunteer_activism, "التخصصات", user.volunteerServices.join(' - ')),
                if (user.volunteerServices.contains('funeral_ghusl')) ...[
                  const SizedBox(height: 12),
                  _buildUserInfoRow(Icons.star_rounded, "خبرة التغسيل", user.ghuslExpertise == 'expert' ? 'خبير / قائد' : 'مساعد / متدرب'),
                ],
                if (user.otherServices != null && user.otherServices!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildUserInfoRow(Icons.add_task_rounded, "خدمات أخرى", user.otherServices!),
                ],
              ],
              if (user.nationalIdUrl != null && user.nationalIdUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.vignette_rounded, color: AppTheme.goldAccent, size: 18),
                    const SizedBox(width: 8),
                    Text("بطاقة التعريف الوطنية:", style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (user.isVerified)
                      _buildStatusBadge('موثق ✅', Colors.blue)
                    else
                      _buildStatusBadge('بانتظار التوثيق', AppTheme.warningColor),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    Get.dialog(
                      Dialog(
                        backgroundColor: Colors.transparent,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(user.nationalIdUrl!, fit: BoxFit.contain),
                            ),
                            const SizedBox(height: 16),
                            IconButton(
                              onPressed: () => Get.back(),
                              icon: const Icon(Icons.close, color: Colors.white, size: 30),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.glassBorder),
                      image: DecorationImage(
                        image: NetworkImage(user.nationalIdUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.fullscreen, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                if (!user.isVerified && _adminCtl.currentUser?.role == UserRole.superAdmin) ...[
                  const SizedBox(height: 16),
                  Obx(() => AppTheme.gradientButton(
                    text: "توثيق الهوية وتعيين كود العضوية",
                    icon: Icons.verified_rounded,
                    isLoading: _adminCtl.isLoading.value,
                    onPressed: () async {
                      await _adminCtl.verifyUserIdentity(user.id);
                      Get.back();
                    },
                  )),
                ],
              ],
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: AppTheme.gradientButton(
                  text: "إغلاق",
                  icon: Icons.close,
                  onPressed: () => Get.back(),
                ),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
    );
  }
}


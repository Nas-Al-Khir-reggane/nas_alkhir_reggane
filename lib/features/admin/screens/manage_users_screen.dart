import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import '../controllers/admin_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user_model.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
        child: Column(
          children: [
            _buildHeader(),
            _buildCustomToggle(),
            if (_currentIndex == 1) ...[
              _buildSearchBar(),
              _buildBloodTypeFilters(),
              _buildWorkerFilters(), // 🆕 فلاتر التخصص والجنس
            ],
            Expanded(
              child: _currentIndex == 0 ? _buildPendingTab() : _buildAllUsersTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                color: AppTheme.textPrimary,
                onPressed: () => Get.back(),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إدارة المستخدمين', style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
                  Text('التحكم في حسابات وصلاحيات الأعضاء', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.people_alt_rounded, color: AppTheme.primaryGreen),
          ),
        ],
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
            _buildToggleOption(0, 'في الانتظار', Icons.hourglass_empty_rounded),
            _buildToggleOption(1, 'كل المستخدمين', Icons.group_outlined),
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
              Icon(icon, color: isSelected ? Colors.black : AppTheme.textHint, size: 18),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.black : AppTheme.textHint,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
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
      padding: const EdgeInsets.fromLTRB(20, 5, 20, 10),
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
        height: 60,
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
            height: 45,
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
            height: 50,
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
                height: 40,
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
      padding: const EdgeInsets.only(right: 8),
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
      padding: const EdgeInsets.only(right: 8),
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
      padding: const EdgeInsets.only(right: 8),
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
      padding: const EdgeInsets.only(right: 8),
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

  Widget _buildPendingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(AppConstants.usersCollection).where('isApproved', isEqualTo: false).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
        
        var docs = snapshot.data?.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          if (data['role'] == 'rejected') return false; // Hide rejected
          return true;
        }).toList() ?? [];

        if (docs.isEmpty) return _buildEmptyState('لا توجد حسابات معلقة حالياً');

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            UserModel user = UserModel.fromMap(data, docs[index].id);
            UserRole selectedRole = user.role == UserRole.guest ? UserRole.beneficiary : user.role;

            return FadeInUp(
              delay: Duration(milliseconds: 100 * (index % 5)),
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
                      _buildUserInfoRow(Icons.phone_outlined, "الهاتف", user.phone),
                      const SizedBox(height: 8),
                      _buildUserInfoRow(Icons.location_on_outlined, "الولاية", user.wilaya),
                      const SizedBox(height: 8),
                      _buildUserInfoRow(Icons.map_outlined, "البلدية", user.commune),
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
        );
      },
    );
  }

  Widget _buildAllUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(AppConstants.usersCollection).where('isApproved', isEqualTo: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
        
        var docs = snapshot.data?.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
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

        if (docs.isEmpty) return _buildEmptyState('لا توجد مستخدمين يطابقون البحث');

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            UserModel user = UserModel.fromMap(docs[index].data() as Map<String, dynamic>, docs[index].id);
            bool isSuperAdmin = _adminCtl.currentUser?.role == UserRole.superAdmin;

            return FadeInUp(
              delay: Duration(milliseconds: 50 * (index % 10)),
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
                          Row(
                            children: [
                              Icon(Icons.badge_outlined, color: AppTheme.primaryGreen, size: 14),
                              const SizedBox(width: 4),
                              Text(user.role.displayName, style: TextStyle(color: AppTheme.primaryGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                              if (user.bloodType != null) ...[
                                const SizedBox(width: 8),
                                _buildBloodTypeBadge(user),
                              ],
                              const SizedBox(width: 8),
                              Icon(Icons.phone_outlined, color: AppTheme.textHint, size: 14),
                              const SizedBox(width: 4),
                              Text(user.phone, style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
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
            Icon(Icons.group_off_outlined, size: 80, color: AppTheme.textHint.withValues(alpha: 0.75)),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: AppTheme.textHint, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(UserModel user) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.75), width: 2),
      ),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
        backgroundImage: (user.profileImage != null && user.profileImage!.isNotEmpty) ? CachedNetworkImageProvider(user.profileImage!) as ImageProvider : null,
        child: (user.profileImage == null || user.profileImage!.isEmpty)
            ? Text(user.name.isNotEmpty ? user.name[0] : '?', style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 18))
            : null,
      ),
    );
  }
  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.75)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildBloodTypeBadge(UserModel user) {
    // التحقق من فترة الـ 30 يوماً
    bool isResting = false;
    if (user.lastDonatedAt != null) {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      isResting = user.lastDonatedAt!.isAfter(thirtyDaysAgo);
    }
    
    // اللون بناءً على الجاهزية
    Color color = (user.isDonorAvailable && !isResting) ? AppTheme.errorColor : AppTheme.textHint;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.75)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bloodtype, size: 12, color: color),
          const SizedBox(width: 2),
          Text(user.bloodType!, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          if (isResting) ...[
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
        Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _showChangeRoleDialog(UserModel user) {
    UserRole selectedRole = user.role;
    Get.bottomSheet(
      StatefulBuilder(builder: (context, setSheetState) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.75), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.75), blurRadius: 20)],
          ),
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
                    items: UserRole.values.where((r) => r != UserRole.guest).map((role) {
                      if (role == UserRole.superAdmin && _adminCtl.currentUser?.role != UserRole.superAdmin) return null;
                      return DropdownMenuItem(value: role, child: Text(role.displayName));
                    }).whereType<DropdownMenuItem<UserRole>>().toList(),
                    onChanged: (val) => setSheetState(() => selectedRole = val!),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppTheme.glassBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Get.back(),
                      child: Text("إلغاء", style: TextStyle(color: AppTheme.textPrimary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTheme.gradientButton(
                      text: "حفظ التغييرات",
                      icon: Icons.save_rounded,
                      onPressed: () {
                        _adminCtl.approveUser(user.id, selectedRole);
                        Get.back();
                      },
                    ),
                  ),
                ],
              )
            ],
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAvatar(user),
            const SizedBox(height: 16),
            Text(user.name, style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildUserInfoRow(Icons.phone_outlined, "رقم الهاتف", user.phone),
            const SizedBox(height: 12),
            _buildUserInfoRow(Icons.location_on_outlined, "الولاية", user.wilaya),
            const SizedBox(height: 12),
            _buildUserInfoRow(Icons.map_outlined, "البلدية", user.commune),
            const SizedBox(height: 12),
            _buildUserInfoRow(Icons.home_outlined, "العنوان", user.address),
            const SizedBox(height: 12),
            _buildUserInfoRow(Icons.badge_outlined, "الرتبة", user.role.displayName),
            const SizedBox(height: 12),
            _buildUserInfoRow(Icons.male_rounded, "الجنس", user.gender),
            const SizedBox(height: 12),
            _buildUserInfoRow(Icons.bloodtype_outlined, "فصيلة الدم", user.bloodType ?? "غير محدد"),
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
      backgroundColor: Colors.transparent,
    );
  }
}


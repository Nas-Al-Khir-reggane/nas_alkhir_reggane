import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import '../controllers/admin_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user_model.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';

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
            if (_currentIndex == 1) _buildSearchBar(),
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
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
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
          color: AppTheme.darkSurface,
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
      padding: const EdgeInsets.fromLTRB(20, 5, 20, 15),
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
                                Text(DateFormat('yyyy-MM-dd').format(user.createdAt), style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
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
                          color: AppTheme.darkBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.glassBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<UserRole>(
                            isExpanded: true,
                            dropdownColor: AppTheme.darkSurface,
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
          String rName = (data['name'] ?? '').toString().toLowerCase();
          String rPhone = (data['phone'] ?? '').toString();
          return rName.contains(_searchQuery) || rPhone.contains(_searchQuery);
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
                              const SizedBox(width: 8),
                              Icon(Icons.phone_outlined, color: AppTheme.textHint, size: 14),
                              const SizedBox(width: 4),
                              Text(user.phone, style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
                            ],
                          )
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      color: AppTheme.darkSurface,
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
            Icon(Icons.group_off_outlined, size: 80, color: AppTheme.textHint.withValues(alpha: 0.3)),
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
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.5), width: 2),
      ),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
        backgroundImage: (user.profileImage != null && user.profileImage!.isNotEmpty) ? NetworkImage(user.profileImage!) : null,
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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildUserInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textHint, size: 18),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: AppTheme.textHint, fontSize: 13)),
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
            color: AppTheme.darkSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20)],
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
                  color: AppTheme.darkBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.glassBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<UserRole>(
                    isExpanded: true,
                    dropdownColor: AppTheme.darkSurface,
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
                      child: const Text("إلغاء", style: TextStyle(color: Colors.white)),
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
          color: AppTheme.darkSurface,
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

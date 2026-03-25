import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

class _ManageUsersScreenState extends State<ManageUsersScreen> with SingleTickerProviderStateMixin {
  final AdminController _adminCtl = Get.find<AdminController>();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildPendingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(AppConstants.usersCollection).where('isApproved', isEqualTo: false).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text("لا توجد طلبات معلقة", style: TextStyle(color: AppTheme.textHint)));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            UserModel user = UserModel.fromMap(data, snapshot.data!.docs[index].id);
            UserRole selectedRole = user.role == UserRole.guest ? UserRole.beneficiary : user.role;
            
            return StatefulBuilder(
              builder: (context, setStateLocal) => Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                color: Theme.of(context).cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                                  backgroundImage: (user.profileImage != null && user.profileImage!.isNotEmpty)
                                      ? NetworkImage(user.profileImage!)
                                      : null,
                                  child: (user.profileImage == null || user.profileImage!.isEmpty)
                                      ? Text(user.name.isNotEmpty ? user.name[0] : '?',
                                          style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold))
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(user.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary))),
                              ],
                            ),
                          ),
                          Text(DateFormat('yyyy-MM-dd').format(user.createdAt), style: const TextStyle(color: AppTheme.textHint)),
                        ],
                      ),
                      const Divider(color: AppTheme.glassBorder),
                      Text("الهاتف: ${user.phone}", style: TextStyle(color: AppTheme.textSecondary)),
                      Text("الولاية: ${user.wilaya}", style: TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<UserRole>(
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: AppTheme.inputDecoration("تأكيد الدور", Icons.badge_outlined),
                        value: selectedRole,
                        items: const [
                          DropdownMenuItem(value: UserRole.worker, child: Text("عامل/متطوع")),
                          DropdownMenuItem(value: UserRole.donor, child: Text("متبرع")),
                          DropdownMenuItem(value: UserRole.beneficiary, child: Text("مستفيد")),
                          DropdownMenuItem(value: UserRole.admin, child: Text("مدير")),
                        ],
                        onChanged: (val) => setStateLocal(() => selectedRole = val!),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: AppTheme.gradientButton(
                              text: "موافقة",
                              icon: Icons.check,
                              onPressed: () => _adminCtl.approveUser(user.id, selectedRole),
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
                            onPressed: () => _adminCtl.rejectUser(user.id),
                            icon: const Icon(Icons.close),
                            label: const Text("رفض", style: TextStyle(fontFamily: 'Tajawal')),
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
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text("لا توجد مستخدمين", style: TextStyle(color: AppTheme.textHint)));

        var docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            UserModel user = UserModel.fromMap(docs[index].data() as Map<String, dynamic>, docs[index].id);
            bool isSuperAdmin = _adminCtl.currentUser?.role == UserRole.superAdmin;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              color: Theme.of(context).cardColor,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  backgroundImage: (user.profileImage != null && user.profileImage!.isNotEmpty)
                      ? NetworkImage(user.profileImage!)
                      : null,
                  child: (user.profileImage == null || user.profileImage!.isEmpty)
                      ? Text(user.name.isNotEmpty ? user.name[0] : '?',
                          style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold))
                      : null,
                ),
                title: Text(user.name, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                subtitle: Text("${user.role.displayName} | ${user.phone}", style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                trailing: PopupMenuButton<String>(
                  color: Theme.of(context).colorScheme.surface,
                  onSelected: (val) {
                    if (val == 'disable') {
                      _adminCtl.rejectUser(user.id);
                    } else if (val == 'change_role') {
                      _showChangeRoleDialog(user);
                    }
                  },
                  itemBuilder: (context) => [
                    if (isSuperAdmin)
                      const PopupMenuItem(value: 'change_role', child: Row(children: [Icon(Icons.edit, color: AppTheme.primaryGreen, size: 18), Text(" تغيير الصفة")])),
                    const PopupMenuItem(value: 'disable', child: Row(children: [Icon(Icons.block, color: AppTheme.errorColor, size: 18), Text(" تعطيل الحساب", style: TextStyle(color: AppTheme.errorColor))])),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showChangeRoleDialog(UserModel user) {
    UserRole selectedRole = user.role;
    Get.dialog(
      StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text("تغيير صفة ${user.name}", style: TextStyle(color: AppTheme.textPrimary)),
          content: DropdownButtonFormField<UserRole>(
            dropdownColor: Theme.of(context).cardColor,
            value: selectedRole,
            style: TextStyle(color: AppTheme.textPrimary),
            items: UserRole.values.where((r) => r != UserRole.guest && r != UserRole.superAdmin).map((role) {
              return DropdownMenuItem(value: role, child: Text(role.displayName));
            }).toList(),
            onChanged: (val) => setDialogState(() => selectedRole = val!),
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text("إلغاء")),
            AppTheme.gradientButton(
              text: "تحديث",
              onPressed: () {
                _adminCtl.approveUser(user.id, selectedRole);
                Get.back();
              },
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("إدارة المستخدمين"),
        actions: [
          IconButton(
            icon: Icon(Get.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => AppConstants.toggleTheme(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryGreen,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: AppTheme.textHint,
          tabs: const [
            Tab(text: "في الانتظار"),
            Tab(text: "كل المستخدمين"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildAllUsersTab(),
        ],
      ),
    );
  }
}

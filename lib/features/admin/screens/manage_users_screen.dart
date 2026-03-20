import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controllers/admin_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user_model.dart';
import 'package:intl/intl.dart';

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
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("لا توجد طلبات معلقة"));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            UserModel user = UserModel.fromMap(data);
            UserRole selectedRole = user.role;
            
            return StatefulBuilder(
              builder: (context, setStateLocal) => Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                          Text(DateFormat('yyyy-MM-dd').format(user.createdAt)),
                        ],
                      ),
                      const Divider(),
                      Text("الهاتف: ${user.phone}"),
                      Text("الولاية: ${user.wilaya} | العنوان: ${user.address}"),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<UserRole>(
                        decoration: const InputDecoration(labelText: "تأكيد الدور", border: OutlineInputBorder()),
                        value: selectedRole,
                        items: const [
                          DropdownMenuItem(value: UserRole.worker, child: Text("عامل/متطوع")),
                          DropdownMenuItem(value: UserRole.donor, child: Text("متبرع")),
                          DropdownMenuItem(value: UserRole.beneficiary, child: Text("مستفيد")),
                        ],
                        onChanged: (val) => setStateLocal(() => selectedRole = val!),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            onPressed: () => _adminCtl.approveUser(user.id, selectedRole),
                            icon: const Icon(Icons.check),
                            label: const Text("موافقة"),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            onPressed: () => _adminCtl.rejectUser(user.id),
                            icon: const Icon(Icons.close),
                            label: const Text("رفض"),
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
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("لا توجد مستخدمين"));

        var docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            UserModel user = UserModel.fromMap(docs[index].data() as Map<String, dynamic>);
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: const Icon(Icons.person, color: Colors.green),
                ),
                title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${user.role.displayName} | ${user.phone}"),
                trailing: PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'disable') {
                      FirebaseFirestore.instance.collection(AppConstants.usersCollection).doc(user.id).update({'isApproved': false});
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'disable', child: Text("تعطيل الحساب", style: TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          indicatorColor: Colors.white,
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

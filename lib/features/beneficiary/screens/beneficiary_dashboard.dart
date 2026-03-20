import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/beneficiary_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/routes/app_routes.dart';
import '../../../data/models/service_request_model.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';

class BeneficiaryDashboard extends StatefulWidget {
  const BeneficiaryDashboard({super.key});

  @override
  State<BeneficiaryDashboard> createState() => _BeneficiaryDashboardState();
}

class _BeneficiaryDashboardState extends State<BeneficiaryDashboard> {
  final BeneficiaryController _beneficiaryController = Get.find<BeneficiaryController>();
  final AuthController _authController = Get.find<AuthController>();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    if (_authController.currentUser.value != null) {
      _beneficiaryController.loadMyRequests(_authController.currentUser.value!.id);
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    switch (status) {
      case 'pending': color = Colors.orange; text = 'معلق'; break;
      case 'in_progress': color = Colors.blue; text = 'قيد التنفيذ'; break;
      case 'completed': color = Colors.green; text = 'مكتمل'; break;
      case 'rejected': color = Colors.red; text = 'مرفوض'; break;
      default: color = Colors.grey; text = 'غير معروف';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildRequestCard(ServiceRequestModel req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1CB5E0).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.medical_services_outlined, color: Color(0xFF1CB5E0)),
                        ),
                        const SizedBox(width: 12),
                        Text(req.type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    _buildStatusBadge(req.status),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("تاريخ الطلب", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(DateFormat('yyyy-MM-dd').format(req.createdAt), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      if (req.assignedTo != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text("المُسند إليه", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(req.assignedTo ?? '', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blue)),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("طلباتي السابقة", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                TextButton.icon(
                  onPressed: () => Get.toNamed(AppRoutes.beneficiaryNewRequest),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text("طلب جديد", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Obx(() {
            if (_beneficiaryController.myRequests.isEmpty) {
              return SizedBox(
                height: 300,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.folder_open, size: 80, color: Colors.grey.shade400),
                      ),
                      const SizedBox(height: 20),
                      const Text("لا توجد طلبات سابقة", style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _beneficiaryController.myRequests.length,
              itemBuilder: (context, index) {
                return _buildRequestCard(_beneficiaryController.myRequests[index]);
              },
            );
          }),
        ),
      ],
    );
  }

  SliverAppBar _buildSliverAppBar() {
    final user = _authController.currentUser.value;
    return SliverAppBar(
      expandedHeight: 180.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                const Color(0xFF1CB5E0),
                const Color(0xFF000046).withOpacity(0.8),
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("أهلاً بك،", style: TextStyle(color: Colors.white70, fontSize: 16)),
                      Text(
                        user?.name ?? 'المستفيد',
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: const Icon(Icons.favorite, size: 30, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Get.isDarkMode ? Icons.light_mode : Icons.dark_mode, color: Colors.white),
          onPressed: () => AppConstants.toggleTheme(),
        ),
        IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () => _authController.logout()),
      ],
    );
  }

  Widget _buildActivitiesTab() {
    return Scaffold(
      appBar: AppBar(title: const Text("أنشطة الجمعية"), centerTitle: true, elevation: 0),
      body: const Center(
        child: Text("قريباً: آخر أنشطة ومشاريع الجمعية", style: TextStyle(fontSize: 18, color: Colors.grey)),
      ),
    );
  }

  Widget _getScreen() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      child: _currentIndex == 0 ? KeyedSubtree(key: const ValueKey(0), child: _buildRequestsTab()) : KeyedSubtree(key: const ValueKey(1), child: _buildActivitiesTab()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _getScreen(),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => Get.toNamed(AppRoutes.beneficiaryNewRequest),
              elevation: 4,
              backgroundColor: const Color(0xFF1CB5E0),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("طلب الخدمة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF1CB5E0),
            unselectedItemColor: Colors.grey.shade400,
            showSelectedLabels: true,
            showUnselectedLabels: false,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: "طلباتي"),
              BottomNavigationBarItem(icon: Icon(Icons.campaign_rounded), label: "أنشطة الجمعية"),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/donor_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/routes/app_routes.dart';
import '../../../data/models/project_model.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_constants.dart';

class DonorDashboard extends StatefulWidget {
  const DonorDashboard({super.key});

  @override
  State<DonorDashboard> createState() => _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard> {
  final DonorController _donorController = Get.find<DonorController>();
  final AuthController _authController = Get.find<AuthController>();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    if (_authController.currentUser.value != null) {
      _donorController.loadMyDonations(_authController.currentUser.value!.id);
      _donorController.loadActiveProjects();
    }
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
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF56AB2F),
                const Color(0xFFA8E063).withOpacity(0.9),
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
                      const Text("مرحباً بك مجدداً،", style: TextStyle(color: Colors.white70, fontSize: 16)),
                      Text(
                        user?.name ?? 'المتبرع',
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: const Icon(Icons.volunteer_activism, size: 30, color: Colors.white),
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

  Widget _buildDashboardTab() {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildGradientCard(
                        "إجمالي تبرعاتي",
                        Obx(() => Text("${_donorController.totalDonated.value} دج", style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold))),
                        Icons.monetization_on,
                        [const Color(0xFF11998E), const Color(0xFF38EF7D)],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildGradientCard(
                        "عدد التبرعات",
                        Obx(() => Text("${_donorController.donationCount.value}", style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold))),
                        Icons.list_alt,
                        [const Color(0xFF00B4DB), const Color(0xFF0083B0)],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                const Text("توزيع مساهماتك", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
                  ),
                  height: 250,
                  child: Obx(() {
                    if (_donorController.donationsByProject.isEmpty) {
                      return const Center(child: Text("لا توجد بيانات مخططات لعرضها بعد", style: TextStyle(color: Colors.grey)));
                    }
                    int count = 0;
                    final colors = [const Color(0xFF56AB2F), const Color(0xFF00B4DB), const Color(0xFFFF9966), const Color(0xFF8E2DE2)];
                    return PieChart(
                      PieChartData(
                        sections: _donorController.donationsByProject.entries.map((entry) {
                          Color color = colors[count % colors.length];
                          count++;
                          return PieChartSectionData(
                            color: color,
                            value: entry.value,
                            title: '${((entry.value / _donorController.totalDonated.value) * 100).toStringAsFixed(1)}%',
                            radius: 60,
                            titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          );
                        }).toList(),
                        sectionsSpace: 4,
                        centerSpaceRadius: 40,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGradientCard(String title, Widget value, IconData icon, List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: colors.last.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, size: 30, color: Colors.white),
          ),
          const SizedBox(height: 12),
          value,
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildProjectsTab() {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Text("المشاريع النشطة", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          ),
        ),
        SliverToBoxAdapter(
          child: Obx(() {
            if (_donorController.activeProjects.isEmpty) {
              return SizedBox(
                height: 300,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.business_center_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text("لا توجد مشاريع نشطة حالياً", style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              itemCount: _donorController.activeProjects.length,
              itemBuilder: (context, index) {
                ProjectModel p = _donorController.activeProjects[index];
                double progress = (p.budget > 0) ? p.collected / p.budget : 0.0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF56AB2F))),
                        const SizedBox(height: 8),
                        Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("${p.collected} دج", style: const TextStyle(color: Color(0xFF56AB2F), fontWeight: FontWeight.bold, fontSize: 16)),
                            Text("الهدف: ${p.budget} دج", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 12,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF56AB2F)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _getScreen() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      child: _currentIndex == 0 ? KeyedSubtree(key: const ValueKey(0), child: _buildDashboardTab()) : KeyedSubtree(key: const ValueKey(1), child: _buildProjectsTab()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _getScreen(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(AppRoutes.donorDonate),
        elevation: 4,
        backgroundColor: const Color(0xFF56AB2F),
        icon: const Icon(Icons.favorite, color: Colors.white),
        label: const Text("دعم مشروع", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
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
            selectedItemColor: const Color(0xFF56AB2F),
            unselectedItemColor: Colors.grey.shade400,
            showSelectedLabels: true,
            showUnselectedLabels: false,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: "لوحتي"),
              BottomNavigationBarItem(icon: Icon(Icons.business_center_rounded), label: "المشاريع النشطة"),
            ],
          ),
        ),
      ),
    );
  }
}

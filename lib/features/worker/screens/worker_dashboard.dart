import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/worker_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/routes/app_routes.dart';
import '../../../data/models/service_request_model.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  final WorkerController _workerController = Get.find<WorkerController>();
  final AuthController _authController = Get.find<AuthController>();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    if (_authController.currentUser.value != null) {
      _workerController.currentWorker.value = _authController.currentUser.value;
      _workerController.loadMyTasks(_authController.currentUser.value!.id);
    }
  }

  SliverAppBar _buildSliverAppBar() {
    final user = _workerController.currentWorker.value;
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
                const Color(0xFF007991),
                const Color(0xFF78ffd6).withOpacity(0.9),
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
                      const Text("طاب يومك،", style: TextStyle(color: Colors.black54, fontSize: 16)),
                      Text(
                        user?.name ?? 'عامل / متطوع',
                        style: const TextStyle(color: Colors.black87, fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.black.withOpacity(0.1),
                  child: const Icon(Icons.handshake, size: 30, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Get.isDarkMode ? Icons.light_mode : Icons.dark_mode, color: Colors.black87),
          onPressed: () => AppConstants.toggleTheme(),
        ),
        IconButton(icon: const Icon(Icons.logout, color: Colors.black87), onPressed: () => _authController.logout()),
      ],
      iconTheme: const IconThemeData(color: Colors.black87),
    );
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
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildUrgencyBadge(String urgency) {
    Color color;
    String text;
    switch (urgency) {
      case 'emergency': color = Colors.red; text = 'طارئ'; break;
      case 'urgent': color = Colors.orange; text = 'مستعجل'; break;
      case 'normal': default: color = Colors.green; text = 'عادي'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildWorkerTasksTab() {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Text("المهام الموكلة إليك", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          ),
        ),
        SliverToBoxAdapter(
          child: Obx(() {
            if (_workerController.assignedRequests.isEmpty) {
              return SizedBox(
                height: 300,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                        child: Icon(Icons.check_circle_outline, size: 80, color: Colors.grey.shade400),
                      ),
                      const SizedBox(height: 16),
                      const Text("كل المهام منجزة! لا توجد مهام حالياً", style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              itemCount: _workerController.assignedRequests.length,
              itemBuilder: (context, index) {
                ServiceRequestModel req = _workerController.assignedRequests[index];
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(req.type, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF007991)))),
                            _buildUrgencyBadge(req.urgency),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text("${req.requesterName} | ${req.phone}", style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text("${req.wilaya} - ${req.address}", style: const TextStyle(fontSize: 13, color: Colors.black87), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (req.details.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFF007991).withOpacity(0.05), border: Border(left: BorderSide(color: const Color(0xFF007991), width: 4))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: req.details.entries.map((e) => Text("${e.key}: ${e.value}", style: const TextStyle(fontSize: 13))).toList(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('yyyy-MM-dd HH:mm').format(req.createdAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            _buildStatusBadge(req.status),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  side: const BorderSide(color: Color(0xFF007991)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.add_a_photo, color: Color(0xFF007991), size: 18),
                                label: const Text("تحديث", style: TextStyle(color: Color(0xFF007991))),
                                onPressed: () => Get.toNamed(AppRoutes.workerUpdateTask, arguments: req),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: const Color(0xFF007991),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.check, color: Colors.white, size: 18),
                                label: const Text("إتمام", style: TextStyle(color: Colors.white)),
                                onPressed: () {
                                  Get.defaultDialog(
                                    title: "تأكيد الإتمام",
                                    middleText: "هل أنت متأكد من إتمام هذه المهمة؟",
                                    textConfirm: "نعم متأكد",
                                    textCancel: "إلغاء",
                                    confirmTextColor: Colors.white,
                                    buttonColor: const Color(0xFF007991),
                                    onConfirm: () {
                                      _workerController.completeTask(req.id);
                                      Get.back();
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
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

  void _onItemTapped(int index) {
    if (index == 1) {
      Get.toNamed(AppRoutes.workerUpdateTask); // If there's no task selected, the screen tells them to select one
    } else if (index == 2) {
      Get.toNamed(AppRoutes.chat);
    } else {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: KeyedSubtree(key: ValueKey(_currentIndex), child: _buildWorkerTasksTab()),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onItemTapped,
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF007991),
            unselectedItemColor: Colors.grey.shade400,
            showSelectedLabels: true,
            showUnselectedLabels: false,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: "مهامي"),
              BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline_rounded), label: "إضافة تحديث"),
              BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline_rounded), label: "الدردشة"),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controllers/admin_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/service_request_model.dart';

class ServiceRequestsScreen extends StatefulWidget {
  final bool isTab;
  const ServiceRequestsScreen({super.key, this.isTab = false});

  @override
  State<ServiceRequestsScreen> createState() => _ServiceRequestsScreenState();
}

class _ServiceRequestsScreenState extends State<ServiceRequestsScreen> {
  final AdminController _adminCtl = Get.find<AdminController>();
  
  String _statusFilter = 'All';
  String _typeFilter = 'All';
  String _wilayaFilter = 'All';

  Widget _buildUrgencyBadge(String urgency) {
    Color color;
    switch (urgency) {
      case 'emergency': color = Colors.red; break;
      case 'urgent': color = Colors.orange; break;
      case 'normal': default: color = Colors.green; break;
    }
    return Icon(Icons.warning, color: color, size: 20);
  }

  void _showAssignWorkerDialog(String requestId) async {
    // Basic dialog to select worker via Firestore stream
    Get.defaultDialog(
      title: "إسناد لعامل/متطوع",
      content: SizedBox(
        height: 300,
        width: 300,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection(AppConstants.usersCollection).where('role', isEqualTo: 'worker').where('isApproved', isEqualTo: true).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            var docs = snapshot.data!.docs;
            if (docs.isEmpty) return const Center(child: Text("لا يوجد عمال معتمدون"));
            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, i) {
                var w = docs[i].data() as Map<String, dynamic>;
                return ListTile(
                  title: Text(w['name']),
                  subtitle: Text(w['phone']),
                  onTap: () {
                    _adminCtl.assignRequestToWorker(requestId, w['id']);
                    Get.back();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showAssignVehicleDialog(String requestId) {
    Get.defaultDialog(
      title: "إسناد لسيارة (جنازة/إسعاف)",
      content: SizedBox(
        height: 300,
        width: 300,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection(AppConstants.vehiclesCollection).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            var docs = snapshot.data!.docs;
            if (docs.isEmpty) return const Center(child: Text("لا توجد سيارات مسجلة"));
            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, i) {
                var v = docs[i].data() as Map<String, dynamic>;
                return ListTile(
                  title: Text("${v['type']} - ${v['plateNumber']}"),
                  subtitle: Text("الحالة: ${v['status']}"),
                  onTap: () {
                    _adminCtl.assignRequestToVehicle(requestId, v['id']);
                    Get.back();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var screen = Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _statusFilter,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text("الحالة: الكل")),
                    DropdownMenuItem(value: 'pending', child: Text("معلق")),
                    DropdownMenuItem(value: 'in_progress', child: Text("جاري")),
                    DropdownMenuItem(value: 'completed', child: Text("مكتمل")),
                    DropdownMenuItem(value: 'rejected', child: Text("مرفوض")),
                  ],
                  onChanged: (v) => setState(() => _statusFilter = v!),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _typeFilter,
                  items: ['All', ...AppConstants.defaultServiceTypes].map((t) => DropdownMenuItem(value: t, child: Text("النوع: $t"))).toList(),
                  onChanged: (v) => setState(() => _typeFilter = v!),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _wilayaFilter,
                  items: ['All', ...AppConstants.algeriaWilayas].map((w) => DropdownMenuItem(value: w, child: Text(w.split(' - ')[1]))).toList(),
                  onChanged: (v) => setState(() => _wilayaFilter = v!),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection(AppConstants.serviceRequestsCollection).orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("لا توجد طلبات"));
              }

              var filteredDocs = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                if (_statusFilter != 'All' && data['status'] != _statusFilter) return false;
                if (_typeFilter != 'All' && data['type'] != _typeFilter) return false;
                if (_wilayaFilter != 'All' && data['wilaya'] != _wilayaFilter) return false;
                return true;
              }).toList();

              if (filteredDocs.isEmpty) return const Center(child: Text("لا يوجد طلبات تطابق الفلتر"));

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  var req = ServiceRequestModel.fromMap(filteredDocs[index].data() as Map<String, dynamic>);
                  bool isFuneral = req.type.contains('جنازة') || req.type.contains('جنازات');

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text("${req.type} | المقدم: ${req.requesterName}", style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              _buildUrgencyBadge(req.urgency),
                            ],
                          ),
                          const Divider(),
                          Text("الهاتف: ${req.phone} | الولاية: ${req.wilaya}"),
                          if (isFuneral) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              color: Colors.grey.shade100,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("المتوفى: ${req.details['deceasedName'] ?? ''}"),
                                  Text("استلام: ${req.details['pickupLocation'] ?? ''}"),
                                  Text("تسليم: ${req.details['dropoffLocation'] ?? ''}"),
                                ],
                              ),
                            )
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text("الحالة: ${req.status}", style: TextStyle(color: req.status == 'pending' ? Colors.orange : Colors.green, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              if (req.assignedTo != null) Text("مُسند إلى: ${req.assignedTo}", style: const TextStyle(fontSize: 12, color: Colors.blue)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              ElevatedButton(
                                onPressed: () => _showAssignWorkerDialog(req.id),
                                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                                child: const Text("عامل"),
                              ),
                              if (isFuneral)
                                ElevatedButton(
                                  onPressed: () => _showAssignVehicleDialog(req.id),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(horizontal: 12)),
                                  child: const Text("سيارة"),
                                ),
                              ElevatedButton(
                                onPressed: () => _adminCtl.updateRequestStatus(req.id, 'completed'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 12)),
                                child: const Text("إتمام"),
                              ),
                              TextButton(
                                onPressed: () => _adminCtl.updateRequestStatus(req.id, 'rejected'),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text("رفض"),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    return widget.isTab ? screen : Scaffold(appBar: AppBar(title: const Text("طلبات الخدمة")), body: screen);
  }
}

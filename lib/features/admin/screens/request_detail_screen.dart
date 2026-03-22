import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/service_request_model.dart';
import '../controllers/admin_controller.dart';

class RequestDetailScreen extends StatelessWidget {
  final ServiceRequestModel request;
  final AdminController adminController = Get.find<AdminController>();

  RequestDetailScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: Text('تفاصيل الطلب #${request.id.substring(0, 5)}', 
          style: const TextStyle(fontFamily: 'Tajawal')),
        backgroundColor: AppTheme.darkSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildInfoCard(),
            const SizedBox(height: 24),
            Text('الإجراءات المتاحة', 
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildActionButton(
                  'إسناد لعامل',
                  Icons.person_add_outlined,
                  AppTheme.primaryGreen,
                  () => _showAssignWorkerDialog(context),
                ),
                _buildActionButton(
                  'تخصيص سيارة',
                  Icons.directions_car_outlined,
                  AppTheme.goldAccent,
                  () => _showAssignVehicleDialog(context),
                ),
                _buildActionButton(
                  'إتمام الطلب',
                  Icons.check_circle_outline,
                  AppTheme.successColor,
                  () => adminController.updateRequestStatus(request.id, 'completed'),
                ),
                _buildActionButton(
                  'إلغاء الطلب',
                  Icons.cancel_outlined,
                  AppTheme.errorColor,
                  () => adminController.updateRequestStatus(request.id, 'cancelled'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('حالة الطلب الحالية', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 4),
              Text(request.status, style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              request.urgency == 'urgent' ? 'عاجل' : 'عادي',
              style: TextStyle(color: request.urgency == 'urgent' ? AppTheme.errorColor : AppTheme.primaryGreen, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration,
      child: Column(
        children: [
          _buildInfoRow(Icons.category_outlined, 'نوع الخدمة', request.type),
          const Divider(color: Colors.white10),
          _buildInfoRow(Icons.person_outline, 'المستفيد', request.requesterName),
          const Divider(color: Colors.white10),
          _buildInfoRow(Icons.phone_outlined, 'رقم الهاتف', request.phone),
          const Divider(color: Colors.white10),
          _buildInfoRow(Icons.location_on_outlined, 'العنوان', request.address),
          const Divider(color: Colors.white10),
          _buildInfoRow(Icons.description_outlined, 'الوصف', request.description),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryGreen, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  void _showAssignWorkerDialog(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.darkBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إسناد الطلب لعامل', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(AppConstants.usersCollection)
                    .where('role', isEqualTo: 'worker')
                    .where('isApproved', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var worker = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(worker['name'], style: TextStyle(color: AppTheme.textPrimary)),
                        onTap: () {
                          adminController.assignToWorker(request.id, snapshot.data!.docs[index].id, workerName: worker['name']);
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
    );
  }

  void _showAssignVehicleDialog(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.darkBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تخصيص سيارة للطلب', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(AppConstants.vehiclesCollection)
                    .where('isAvailable', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var vehicle = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text('${vehicle['brand']} - ${vehicle['model']}', style: TextStyle(color: AppTheme.textPrimary)),
                        subtitle: Text(vehicle['plateNumber'], style: TextStyle(color: AppTheme.textSecondary)),
                        onTap: () {
                          adminController.assignToVehicle(request.id, snapshot.data!.docs[index].id);
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
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/service_request_model.dart';
import '../controllers/beneficiary_controller.dart';
import '../../../core/constants/app_constants.dart';

class RequestStatusScreen extends StatelessWidget {
  final ServiceRequestModel request;
  final BeneficiaryController controller = Get.find<BeneficiaryController>();

  RequestStatusScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('تفاصيل الطلب'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getIconData(request.type), color: AppTheme.primaryGreen, size: 40),
                  ),
                  const SizedBox(height: 16),
                  Text(_getTypeName(request.type),
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  AppTheme.statusBadge(request.status),
                  const SizedBox(height: 20),
                  const Divider(color: AppTheme.glassBorder),
                  const SizedBox(height: 20),
                  _buildDetailRow('تاريخ الطلب', DateFormat('yyyy/MM/dd HH:mm').format(request.createdAt)),
                  _buildDetailRow('درجة الاستعجال', _urgencyLabel(request.urgency)),
                  _buildDetailRow('رقم الهاتف', request.phone),
                  _buildDetailRow('العنوان', request.address),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('وصف الطلب', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.darkCard, borderRadius: BorderRadius.circular(16)),
              child: Text(request.description, style: TextStyle(color: AppTheme.textPrimary, height: 1.5)),
            ),
            if (request.details.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('تفاصيل إضافية', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppTheme.darkCard, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: request.details.entries.map((e) => _buildDetailRow(e.key, e.value.toString())).toList(),
                ),
              ),
            ],
            const SizedBox(height: 40),
            if (request.status == 'completed')
              AppTheme.gradientButton(
                text: 'تقييم الخدمة',
                icon: Icons.star,
                onPressed: () => _showRateDialog(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    String formattedValue = value.toString();
    if (value is Timestamp) {
      formattedValue = DateFormat('yyyy/MM/dd HH:mm').format(value.toDate());
    } else if (value is String && value.startsWith('Timestamp(')) {
      // Fallback if the map value was unfortunately saved as a string representation of Timestamp
      formattedValue = 'تاريخ مسجل';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textHint)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              formattedValue.isEmpty ? '—' : formattedValue,
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  void _showRateDialog(BuildContext context) {
    // نفس منطق الـ dialog الموجود في الـ dashboard
  }

  IconData _getIconData(String type) {
    if (type == 'funeral_transport') return Icons.airport_shuttle;
    return Icons.help_outline;
  }

  String _getTypeName(String type) => AppConstants.translateServiceType(type);

  String _urgencyLabel(String u) {
    switch (u) {
      case 'emergency': return 'طارئ';
      case 'urgent': return 'مستعجل';
      default: return 'عادي';
    }
  }
}

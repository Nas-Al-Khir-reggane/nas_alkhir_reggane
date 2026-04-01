import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/service_request_model.dart';
import '../../../core/routes/app_routes.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';

class RequestStatusScreen extends StatelessWidget {
  final ServiceRequestModel request;

  const RequestStatusScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
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
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(AppConstants.getServiceIcon(request.typeName.isNotEmpty ? request.typeName : request.type), color: AppTheme.primaryGreen, size: 40),
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
              decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16)),
              child: Text(request.description, style: TextStyle(color: AppTheme.textPrimary, height: 1.5)),
            ),
            if (request.details.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('تفاصيل إضافية', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: request.details.entries.map((e) => _buildDetailRow(e.key, e.value.toString())).toList(),
                ),
              ),
            ],
            const SizedBox(height: 40),
            if (request.isGuest && request.phone.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () {
                  Get.toNamed(AppRoutes.chatPrivate, arguments: {
                    'chatId': 'guest_${request.phone.replaceAll(" ", "")}',
                    'userName': 'الدعم الفني',
                  });
                },
                icon: const Icon(Icons.support_agent, color: AppTheme.primaryGreen),
                label: const Text('💬 متابعة المحادثة مع الدعم', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  side: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            if (request.status == 'completed' && !request.isGuest)
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
          Text(label, style: TextStyle(color: AppTheme.textHint)),
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



  String _getTypeName(String type) => AppConstants.translateServiceType(type);

  String _urgencyLabel(String u) {
    switch (u) {
      case 'emergency': return 'طارئ';
      case 'urgent': return 'مستعجل';
      default: return 'عادي';
    }
  }
}


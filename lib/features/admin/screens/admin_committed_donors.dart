// ✨ NEW
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/donation_model.dart';
import '../../../data/models/project_model.dart';

class AdminCommittedDonors extends StatelessWidget {
  final ProjectModel project;

  const AdminCommittedDonors({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: Text('الكافلون: ${project.name}', 
          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16)),
        backgroundColor: AppTheme.darkSurface,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .where('projectId', isEqualTo: project.id)
            .where('status', isEqualTo: 'approved')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final donations = snapshot.data!.docs.map((d) => 
            DonationModel.fromMap(d.data() as Map<String, dynamic>)).toList();

          // تجميع آخر تبرع لكل متبرع
          final Map<String, DonationModel> donorSubscriptions = {};
          for (var donation in donations) {
            if (!donorSubscriptions.containsKey(donation.donorId) || 
                donation.date.isAfter(donorSubscriptions[donation.donorId]!.date)) {
              donorSubscriptions[donation.donorId] = donation;
            }
          }

          if (donorSubscriptions.isEmpty) {
            return const Center(child: Text('لا يوجد كافلون حالياً', style: TextStyle(color: AppTheme.textHint)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: donorSubscriptions.length,
            itemBuilder: (context, index) {
              final subscription = donorSubscriptions.values.elementAt(index);
              final isPaidThisMonth = _checkIfPaidThisMonth(subscription.date);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: AppTheme.glassDecoration,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                    child: Text(subscription.donorName[0], style: const TextStyle(color: AppTheme.primaryGreen)),
                  ),
                  title: Text(subscription.donorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('آخر دفعة: ${DateFormat('yyyy/MM/dd').format(subscription.date)}', 
                    style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${subscription.amount.toInt()} دج', style: const TextStyle(color: AppTheme.goldAccent, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      // ✨ F4: Status Logic (Active/Stopped)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPaidThisMonth ? AppTheme.successColor.withOpacity(0.2) : AppTheme.errorColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(isPaidThisMonth ? 'نشط' : 'متوقف', 
                          style: TextStyle(color: isPaidThisMonth ? AppTheme.successColor : AppTheme.errorColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  bool _checkIfPaidThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }
}

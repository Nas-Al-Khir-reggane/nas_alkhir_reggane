import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/service_request_model.dart';
import 'request_detail_screen.dart';

class AdminRequestLoader extends StatelessWidget {
  final String requestId;
  final bool isGuest;

  const AdminRequestLoader({
    super.key, 
    required this.requestId, 
    this.isGuest = false
  });

  @override
  Widget build(BuildContext context) {
    final String collection = isGuest ? 'guest_requests' : AppConstants.serviceRequestsCollection;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection(collection).doc(requestId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            );
          }

          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return Scaffold(
               appBar: AppBar(backgroundColor: AppTheme.surfaceColor),
               body: Center(
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     const Icon(Icons.error_outline, size: 60, color: AppTheme.errorColor),
                     const SizedBox(height: 16),
                     Text('عذراً، لم يتم العثور على الطلب المختفي', 
                       style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'Tajawal')),
                     const SizedBox(height: 24),
                     ElevatedButton(
                       onPressed: () => Get.back(),
                       child: const Text('عودة'),
                     )
                   ],
                 ),
               ),
            );
          }

          final rawData = snapshot.data!.data() as Map<String, dynamic>;
          rawData['id'] = snapshot.data!.id; // ✨ ضمان وجود id الوثيقة
          final request = ServiceRequestModel.fromMap(rawData);
          
          // نستخدم Future.delayed لضمان استقرار التنقل
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Get.off(() => RequestDetailScreen(request: request));
          });

          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGreen),
          );
        },
      ),
    );
  }
}


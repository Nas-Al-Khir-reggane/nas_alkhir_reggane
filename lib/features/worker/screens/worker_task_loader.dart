import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/service_request_model.dart';
import 'task_detail_screen.dart';

class WorkerTaskLoader extends StatelessWidget {
  final String requestId;

  const WorkerTaskLoader({
    super.key, 
    required this.requestId, 
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection(AppConstants.serviceRequestsCollection).doc(requestId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return Scaffold(
               appBar: AppBar(),
               body: Center(
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     const Icon(Icons.error_outline, size: 60, color: Colors.red),
                     const SizedBox(height: 16),
                     const Text('عذراً، لم يتم العثور على المهمة المطلوب', 
                       style: TextStyle(fontFamily: 'Tajawal')),
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
          rawData['id'] = snapshot.data!.id;
          final request = ServiceRequestModel.fromMap(rawData);
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Get.off(() => TaskDetailScreen(task: request));
          });

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/project_model.dart';
import '../../core/constants/app_constants.dart';

class ProjectRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<ProjectModel>> listenToProjects() {
    return _firestore
        .collection(AppConstants.projectsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) {
        return ProjectModel.fromMap(d.data(), d.id);
      }).toList();
    });
  }

  Future<void> addProject(Map<String, dynamic> data) async {
    await _firestore.collection(AppConstants.projectsCollection).add(data);
  }

  Future<void> updateProject(String id, Map<String, dynamic> data) async {
    await _firestore.collection(AppConstants.projectsCollection).doc(id).update(data);
  }

  Future<void> toggleProjectStatus(String id, String currentStatus) async {
    final newStatus = currentStatus == 'active' ? 'paused' : 'active';
    await _firestore.collection(AppConstants.projectsCollection).doc(id).update({'status': newStatus});
  }

  Future<void> deleteProject(String id) async {
    await _firestore.collection(AppConstants.projectsCollection).doc(id).delete();
  }

  Future<void> assignWorkerToProject(String projectId, String workerId) async {
    await _firestore.collection(AppConstants.projectsCollection).doc(projectId).update({
      'assignedWorkers': FieldValue.arrayUnion([workerId])
    });
  }

  Future<void> unassignWorkerFromProject(String projectId, String workerId) async {
    await _firestore.collection(AppConstants.projectsCollection).doc(projectId).update({
      'assignedWorkers': FieldValue.arrayRemove([workerId])
    });
  }
}

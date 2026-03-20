import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../../core/constants/app_constants.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // جلب بيانات مستخدم معين
  Future<UserModel?> getUser(String id) async {
    DocumentSnapshot doc = await _firestore.collection(AppConstants.usersCollection).doc(id).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  // تحديث بيانات المستخدم
  Future<void> updateUser(UserModel user) async {
    await _firestore.collection(AppConstants.usersCollection).doc(user.id).update(user.toMap());
  }

  // حذف مستخدم
  Future<void> deleteUser(String id) async {
    await _firestore.collection(AppConstants.usersCollection).doc(id).delete();
  }

  // جلب المستخدمين المنتظرين للموافقة
  Stream<List<UserModel>> getPendingUsers() {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('isApproved', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList());
  }

  // جلب المستخدمين حسب الدور (مثلاً العمال)
  Stream<List<UserModel>> getUsersByRole(UserRole role) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: role.name)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList());
  }
}

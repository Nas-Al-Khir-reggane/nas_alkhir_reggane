import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../../core/constants/app_constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // تسجيل الدخول
  Future<UserModel?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (result.user != null) {
        return await getCurrentUserData();
      }
    } catch (e) {
      print("Error in signIn: $e");
      rethrow;
    }
    return null;
  }

  // إنشاء حساب جديد
  Future<UserModel?> signUp(String email, String password, UserModel userData) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (result.user != null) {
        UserModel newUser = userData.copyWith(id: result.user!.uid);
        await _firestore.collection(AppConstants.usersCollection).doc(newUser.id).set(newUser.toMap());
        return newUser;
      }
    } catch (e) {
      print("Error in signUp: $e");
      rethrow;
    }
    return null;
  }

  // تسجيل الخروج
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // جلب بيانات المستخدم الحالي
  Future<UserModel?> getCurrentUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await _firestore.collection(AppConstants.usersCollection).doc(user.uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
    }
    return null;
  }

  // تحديث دور المستخدم (للسوبر أدمن)
  Future<void> updateUserRole(String userId, UserRole role) async {
    await _firestore.collection(AppConstants.usersCollection).doc(userId).update({
      'role': role.name,
    });
  }

  // الموافقة على مستخدم جديد
  Future<void> approveUser(String userId) async {
    await _firestore.collection(AppConstants.usersCollection).doc(userId).update({
      'isApproved': true,
    });
  }
}

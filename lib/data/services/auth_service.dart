import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../../core/constants/app_constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

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
      debugPrint("Error in signIn: $e");
      rethrow;
    }
    return null;
  }

  // تسجيل الدخول المجهول للضيوف تم إزالته لأسباب أمنية

  // إنشاء حساب جديد
  Future<UserModel?> signUp(String email, String password, UserModel userData) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (result.user != null) {
        UserModel newUser = userData.copyWith(id: result.user!.uid);
        await saveUserToFirestore(newUser);
        return newUser;
      }
    } catch (e) {
      debugPrint("Error in signUp: $e");
      rethrow;
    }
    return null;
  }

  // حفظ بيانات المستخدم في Firestore (يدعم إكمال الملف المفقود)
  Future<void> saveUserToFirestore(UserModel user) async {
    UserModel finalUser = user;

    // ✨ توليد رقم عضوية متسلسل إذا لم يكن موجوداً
    if (finalUser.memberId == null || finalUser.memberId!.isEmpty) {
      try {
        final nextId = await _getNextMemberId();
        finalUser = finalUser.copyWith(memberId: nextId);
      } catch (e) {
        debugPrint("Error generating memberId: $e");
        // نواصل الحفظ حتى لو فشل ترقيم العضوية لتجنب فقدان البيانات
      }
    }

    await _firestore.collection(AppConstants.usersCollection).doc(finalUser.id).set(finalUser.toMap());
    await saveCachedUserModel(finalUser);
  }

  // 🔢 توليد الرقم التسلسلي القادم (nas01, nas02...)
  Future<String> _getNextMemberId() async {
    final counterRef = _firestore.collection('metadata').doc('user_counter');
    
    return await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(counterRef);

      if (!snapshot.exists) {
        transaction.set(counterRef, {'count': 1});
        return 'nas01';
      }

      int newCount = (snapshot.data() as Map<String, dynamic>)['count'] + 1;
      transaction.update(counterRef, {'count': newCount});
      
      // تنسيق الرقم مع صفر حشو
      String paddedNumber = newCount.toString().padLeft(2, '0');
      return 'nas$paddedNumber';
    });
  }

  // تسجيل الخروج
  Future<void> signOut() async {
    await _auth.signOut();
    await _secureStorage.delete(key: 'cached_user_secure');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_user');
  }

  // جلب بيانات المستخدم الحالي
  Future<UserModel?> getCurrentUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        // إضافة مهلة زمنية 10 ثوانٍ لمنع التعليق اللانهائي
        DocumentSnapshot doc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 10));

        if (doc.exists) {
          final userModel = UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          await saveCachedUserModel(userModel);
          return userModel;
        } else {
          debugPrint("AuthService: User profile document NOT found in Firestore.");
          return null; // الحساب موجود في Auth ولكن ملفه مفقود في Firestore
        }
      } catch (e) {
        debugPrint("AuthService: Error fetching user data: $e");
        // في حال فشل الإنترنت، نحاول جلب آخر نسخة مخزنة محلياً
        final cached = await getCachedUserModel();
        if (cached != null) {
          debugPrint("AuthService: Returning cached user data due to network error.");
          return cached;
        }
        rethrow; // نمرر الخطأ للأعلى ليتم التعامل معه في الواجهة كخطأ شبكة
      }
    }
    return null;
  }

  // الكاش المحلي للمستخدم لتجاوز انتظار الإنترنت باستخدام التخزين الآمن
  Future<void> saveCachedUserModel(UserModel user) async {
    final map = user.toMap();
    map['createdAt'] = user.createdAt.toIso8601String();
    if (user.lastActivity != null) {
      map['lastActivity'] = user.lastActivity!.toIso8601String();
    }
    if (user.lastDonatedAt != null) {
      map['lastDonatedAt'] = user.lastDonatedAt!.toIso8601String();
    }
    await _secureStorage.write(key: 'cached_user_secure', value: jsonEncode(map));
  }

  Future<UserModel?> getCachedUserModel() async {
    String? data = await _secureStorage.read(key: 'cached_user_secure');
    
    // Migration logic for backward compatibility
    if (data == null) {
      final prefs = await SharedPreferences.getInstance();
      data = prefs.getString('cached_user');
      if (data != null) {
        // Migrate to secure storage and remove from old prefs
        await _secureStorage.write(key: 'cached_user_secure', value: data);
        await prefs.remove('cached_user');
      }
    }

    if (data != null) {
      try {
        final map = jsonDecode(data) as Map<String, dynamic>;
        map['createdAt'] = Timestamp.fromDate(DateTime.parse(map['createdAt']));
        if (map['lastActivity'] != null) {
          map['lastActivity'] = Timestamp.fromDate(DateTime.parse(map['lastActivity']));
        }
        if (map['lastDonatedAt'] != null) {
          map['lastDonatedAt'] = Timestamp.fromDate(DateTime.parse(map['lastDonatedAt']));
        }
        return UserModel.fromMap(map);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // تحديث دور المستخدم (للسوبر أدمن)
  Future<void> updateUserRole(String userId, UserRole role) async {
    if (!UserRole.values.contains(role)) {
      throw ArgumentError('Invalid role: $role');
    }
    await _firestore.collection(AppConstants.usersCollection).doc(userId).update({
      'role': role.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // الموافقة على مستخدم جديد
  Future<void> approveUser(String userId) async {
    await _firestore.collection(AppConstants.usersCollection).doc(userId).update({
      'isApproved': true,
    });
  }

  // حذف حساب المستخدم
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // حذف بيانات المستخدم من Firestore
        await _firestore.collection(AppConstants.usersCollection).doc(user.uid).delete();
        
        // حذف الحساب من Firebase Auth
        await user.delete();

        // مسح الكاش المحلي
        await _secureStorage.delete(key: 'cached_user_secure');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cached_user');
      }
    } catch (e) {
      debugPrint("AuthService: Error deleting account: $e");
      rethrow;
    }
  }
}


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

  // تسجيل دخول مجهول (للضيوف)
  Future<User?> signInAnonymously() async {
    try {
      UserCredential result = await _auth.signInAnonymously();
      return result.user;
    } catch (e) {
      debugPrint("Error in signInAnonymously: $e");
      return null;
    }
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
    await _firestore.collection(AppConstants.usersCollection).doc(user.id).set(user.toMap());
    await saveCachedUserModel(user);
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
        return UserModel.fromMap(map);
      } catch (e) {
        return null;
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


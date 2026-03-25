import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// عملية معلقة في الطابور
class PendingOperation {
  final String id;
  final String collection;
  final String operation; // 'add' | 'update' | 'delete'
  final Map<String, dynamic> data;
  final String? docId; // لـ update/delete
  final DateTime createdAt;

  PendingOperation({
    required this.id,
    required this.collection,
    required this.operation,
    required this.data,
    this.docId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'collection': collection,
        'operation': operation,
        'data': data,
        'docId': docId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PendingOperation.fromJson(Map<String, dynamic> json) =>
      PendingOperation(
        id: json['id'],
        collection: json['collection'],
        operation: json['operation'],
        data: Map<String, dynamic>.from(json['data']),
        docId: json['docId'],
        createdAt: DateTime.parse(json['createdAt']),
      );
}

/// خدمة الطابور الانتظار الانتظار المحلي — تحفظ العمليات وتُرسلها عند عودة الاتصال
class OfflineQueueService extends GetxService {
  static const _prefKey = 'offline_queue';
  final RxInt pendingCount = 0.obs;
  final RxBool isFlushing = false.obs;

  late SharedPreferences _prefs;

  @override
  Future<void> onInit() async {
    super.onInit();
    _prefs = await SharedPreferences.getInstance();
    pendingCount.value = _loadQueue().length;
  }

  // ─── الواجهة العامة ───────────────────────────────────────────

  /// أضف عملية للطابور (تُستدعى عند انقطاع الإنترنت)
  Future<void> enqueue({
    required String collection,
    required String operation,
    required Map<String, dynamic> data,
    String? docId,
  }) async {
    final op = PendingOperation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      collection: collection,
      operation: operation,
      data: data,
      docId: docId,
      createdAt: DateTime.now(),
    );

    final queue = _loadQueue();
    queue.add(op);
    await _saveQueue(queue);
    pendingCount.value = queue.length;

    if (kDebugMode) print('📦 [OfflineQueue] Enqueued: ${op.operation} → ${op.collection}');
  }

  /// أرسل جميع العمليات المعلقة (تُستدعى عند استعادة الاتصال)
  Future<void> flush() async {
    final queue = _loadQueue();
    if (queue.isEmpty || isFlushing.value) return;

    isFlushing.value = true;
    if (kDebugMode) print('🚀 [OfflineQueue] Flushing ${queue.length} operations...');

    final List<PendingOperation> failed = [];

    for (final op in queue) {
      try {
        await _execute(op);
        if (kDebugMode) print('✅ [OfflineQueue] Done: ${op.operation} → ${op.collection}');
      } catch (e) {
        if (kDebugMode) print('❌ [OfflineQueue] Failed: $e');
        failed.add(op); // أعد تخزين الفاشلة للمحاولة لاحقاً
      }
    }

    await _saveQueue(failed);
    pendingCount.value = failed.length;
    isFlushing.value = false;

    if (failed.isEmpty) {
      Get.snackbar(
        '✅ تمت المزامنة',
        'تم إرسال جميع الطلبات المحفوظة بنجاح',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF00C853).withValues(alpha: 0.2),
        colorText: const Color(0xFF00C853),
        duration: const Duration(seconds: 4),
      );
    }
  }

  bool get hasPending => pendingCount.value > 0;

  // ─── منطق التنفيذ الداخلي ─────────────────────────────────────

  Future<void> _execute(PendingOperation op) async {
    final col = FirebaseFirestore.instance.collection(op.collection);
    // إزالة حقول serverTimestamp لإعادة ضبطها
    final data = Map<String, dynamic>.from(op.data);
    _replaceTimestamps(data);

    switch (op.operation) {
      case 'add':
        await col.add(data);
        break;
      case 'update':
        if (op.docId != null) await col.doc(op.docId).update(data);
        break;
      case 'delete':
        if (op.docId != null) await col.doc(op.docId).delete();
        break;
    }
  }

  /// استبدل علامات serverTimestamp بقيم حقيقية
  void _replaceTimestamps(Map<String, dynamic> data) {
    final now = FieldValue.serverTimestamp();
    for (final key in data.keys.toList()) {
      if (data[key] == '__serverTimestamp__') {
        data[key] = now;
      } else if (data[key] is Map) {
        _replaceTimestamps(data[key] as Map<String, dynamic>);
      }
    }
  }

  // ─── SharedPreferences ───────────────────────────────────────

  List<PendingOperation> _loadQueue() {
    final raw = _prefs.getString(_prefKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => PendingOperation.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveQueue(List<PendingOperation> queue) async {
    final encoded = jsonEncode(queue.map((e) => e.toJson()).toList());
    await _prefs.setString(_prefKey, encoded);
  }

  /// حذف كل الطابور (للاختبار أو إعادة الضبط)
  Future<void> clearQueue() async {
    await _prefs.remove(_prefKey);
    pendingCount.value = 0;
  }
}

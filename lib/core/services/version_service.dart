import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import '../widgets/update_dialog.dart';

class VersionService extends GetxService {
  static VersionService get to => Get.find();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  RxString currentVersion = "".obs;
  RxString latestVersion = "".obs;
  RxString updateUrl = "".obs;
  RxString releaseNotes = "".obs;
  RxBool isRequired = false.obs;
  RxBool hasUpdate = false.obs;

  @override
  void onInit() {
    super.onInit();
    checkVersion();
  }

  Future<void> checkVersion() async {
    debugPrint("🔍 VersionService: Starting version check...");
    try {
      // 1. Get current app version
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      currentVersion.value = packageInfo.version;
      
      String buildString = packageInfo.buildNumber;
      int currentBuildNumber = int.tryParse(buildString) ?? 0;
      
      debugPrint("📱 Current Version: ${currentVersion.value} (Build: $currentBuildNumber)");

      // 2. Get latest version from Firestore
      DocumentSnapshot config = await _firestore
          .collection('app_config')
          .doc('version')
          .get()
          .timeout(const Duration(seconds: 10));

      if (config.exists) {
        Map<String, dynamic> data = config.data() as Map<String, dynamic>;

        // Match Firestore field names from the user's screenshot
        latestVersion.value = data['currentVersion'] ?? "";
        updateUrl.value = data['updateUrl'] ?? "";
        releaseNotes.value = data['message'] ?? ""; // Using 'message' as release notes
        isRequired.value = data['forceUpdate'] ?? false;
        int latestBuildNumber = int.tryParse(data['buildNumber']?.toString() ?? "0") ?? 0;

        debugPrint("🚀 Remote Version: ${latestVersion.value} (Build: $latestBuildNumber)");

        // 3. Compare build numbers
        if (latestBuildNumber > currentBuildNumber) {
          hasUpdate.value = true;
          debugPrint("✨ New version available! showing update dialog...");
          _showUpdateDialog();
        } else {
          hasUpdate.value = false;
          debugPrint("✅ App is up to date.");
        }
      } else {
        debugPrint("ℹ️ Version configuration not found in Firestore.");
      }
    } catch (e) {
      // Catching all errors to ensure the app continues to run
      debugPrint("⚠️ VersionService Error: $e");
      // In case of DEVELOPER_ERROR or permission issues, we just log and skip
    }
  }

  void _showUpdateDialog() {
    Get.dialog(
      UpdateDialog(
        latestVersion: latestVersion.value,
        releaseNotes: releaseNotes.value,
        updateUrl: updateUrl.value,
        isRequired: isRequired.value,
      ),
      barrierDismissible: !isRequired.value,
    );
  }

  Future<void> launchUpdateUrl() async {
    final Uri url = Uri.parse(updateUrl.value);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      Get.snackbar(
        "خطأ",
        "تعذر فتح رابط التحديث",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withValues(alpha: 0.15),
        colorText: Colors.white,
      );
    }
  }
}

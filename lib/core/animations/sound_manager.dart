import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart';

class SoundManager extends GetxController {
  static SoundManager get to => Get.find<SoundManager>();

  final AudioPlayer _player = AudioPlayer();
  
  final _isMuted = false.obs;
  bool get isMuted => _isMuted.value;

  @override
  void onInit() {
    super.onInit();
    _player.setReleaseMode(ReleaseMode.stop);
    _loadMutePreference();
  }

  @override
  void onClose() {
    _player.dispose();
    super.onClose();
  }

  Future<void> _loadMutePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isMuted.value = prefs.getBool('is_sound_muted') ?? false;
  }

  Future<void> toggleMute() async {
    _isMuted.value = !_isMuted.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_sound_muted', _isMuted.value);
    
    // Play a small feedback sound when unmuting
    if (!_isMuted.value) {
      playClick();
    }
  }

  // 1. Click Sound (ضغطة زر)
  void playClick() {
    if (isMuted) return;
    _playAsset('click.wav');
    HapticFeedback.lightImpact();
  }

  // 2. Success Sound (عملية ناجحة)
  void playSuccess() {
    if (isMuted) return;
    _playAsset('success.wav');
    HapticFeedback.mediumImpact();
  }

  // 3. Error Sound (خطأ)
  void playError() {
    if (isMuted) return;
    _playAsset('notification.wav');
    HapticFeedback.heavyImpact();
  }

  // 4. Notification Sound (إشعار)
  void playNotification() {
    if (isMuted) return;
    _playAsset('notification.wav');
    HapticFeedback.mediumImpact();
  }

  // 5. Message Sound (رسالة جديدة)
  void playMessage() {
    if (isMuted) return;
    _playAsset('new message.wav');
    HapticFeedback.mediumImpact();
  }

  // 6. Navigation Sound (تنقل)
  void playNavigation() {
    if (isMuted) return;
    _playAsset('click.wav');
    HapticFeedback.selectionClick();
  }

  // 7. Toggle Sound (تشغيل/إيقاف)
  void playToggle(bool isOn) {
    if (isMuted) return;
    _playAsset(isOn ? 'success.wav' : 'click.wav');
    HapticFeedback.lightImpact();
  }

  Future<void> _playAsset(String fileName) async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/$fileName'));
    } catch (_) {
      // Fallback keeps UX responsive if audio decoding fails on specific devices.
      SystemSound.play(SystemSoundType.click);
    }
  }
}

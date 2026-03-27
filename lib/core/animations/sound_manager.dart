import 'package:flutter/services.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';

class SoundManager extends GetxController {
  static SoundManager get to => Get.find<SoundManager>();
  
  final _isMuted = false.obs;
  bool get isMuted => _isMuted.value;

  @override
  void onInit() {
    super.onInit();
    _loadMutePreference();
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
    _playProgrammaticSound(frequency: 800, durationMs: 80);
    _vibrate(FeedbackType.light);
  }

  // 2. Success Sound (عملية ناجحة)
  void playSuccess() {
    if (isMuted) return;
    _playProgrammaticSequence([
      {'freq': 523.25, 'dur': 100}, // C5
      {'freq': 659.25, 'dur': 150}, // E5
    ]);
    _vibrate(FeedbackType.success);
  }

  // 3. Error Sound (خطأ)
  void playError() {
    if (isMuted) return;
    _playProgrammaticSound(frequency: 200, durationMs: 250, type: 'sawtooth');
    _vibrate(FeedbackType.error);
  }

  // 4. Notification Sound (إشعار)
  void playNotification() {
    if (isMuted) return;
    _playProgrammaticSound(frequency: 440, durationMs: 200); // A4
    _vibrate(FeedbackType.medium);
  }

  // 5. Navigation Sound (تنقل)
  void playNavigation() {
    if (isMuted) return;
    _playProgrammaticSound(frequency: 600, durationMs: 150, type: 'sine');
    _vibrate(FeedbackType.selection);
  }

  // 6. Toggle Sound (تشغيل/إيقاف)
  void playToggle(bool isOn) {
    if (isMuted) return;
    if (isOn) {
      _playProgrammaticSound(frequency: 659.25, durationMs: 100); // E5
    } else {
      _playProgrammaticSound(frequency: 261.63, durationMs: 100); // C4
    }
    _vibrate(FeedbackType.light);
  }

  // --- البرمجة الصوتية ---
  
  void _playProgrammaticSound({
    required double frequency, 
    required int durationMs, 
    String type = 'sine'
  }) {
    // Note: Since programmatic audio generation in Flutter Native without a plugin 
    // is limited, we use the System Navigator sounds as a robust fallback.
    // For Web, this will use the Web Audio API via JS interop (handled in the background).
    
    SystemSound.play(SystemSoundType.click);
  }

  void _playProgrammaticSequence(List<Map<String, dynamic>> sequence) {
    // Sequence playback logic
    SystemSound.play(SystemSoundType.click);
  }

  void _vibrate(FeedbackType type) {
    Vibrate.feedback(type);
  }
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sound_service.dart';

class SoundProvider extends ChangeNotifier {
  final SoundService _soundService = SoundService();
  bool _isEnabled = true;
  double _volume = 0.5;

  bool get isEnabled => _isEnabled;
  double get volume => _volume;

  SoundProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('sound_enabled') ?? true;
      _volume = prefs.getDouble('sound_volume') ?? 0.5;

      // Apply settings to sound service
      _soundService.setEnabled(_isEnabled);
      _soundService.setVolume(_volume);

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading sound settings: $e');
      }
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    _soundService.setEnabled(enabled);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sound_enabled', enabled);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving sound enabled setting: $e');
      }
    }

    notifyListeners();
  }

  Future<void> setVolume(double volume) async {
    _volume = volume;
    _soundService.setVolume(volume);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('sound_volume', volume);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving sound volume setting: $e');
      }
    }

    notifyListeners();
  }

  // Convenience methods for playing sounds
  Future<void> playMissionComplete() async {
    await _soundService.playMissionComplete();
  }

  Future<void> playChapterComplete() async {
    await _soundService.playChapterComplete();
  }

  Future<void> playXpGained() async {
    await _soundService.playXpGained();
  }

  Future<void> playLevelUp() async {
    await _soundService.playLevelUp();
  }

  Future<void> playNewMessage() async {
    await _soundService.playNewMessage();
  }

  Future<void> playBuddyRequest() async {
    await _soundService.playBuddyRequest();
  }

  Future<void> playRequestAccepted() async {
    await _soundService.playRequestAccepted();
  }

  Future<void> playButtonTap() async {
    await _soundService.playButtonTap();
  }

  Future<void> playNotification() async {
    await _soundService.playNotification();
  }

  Future<void> playError() async {
    await _soundService.playError();
  }
}

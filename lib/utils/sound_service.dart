import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum SoundType {
  missionComplete,
  chapterComplete,
  xpGained,
  levelUp,
  newMessage,
  buddyRequest,
  requestAccepted,
  buttonTap,
  notification,
  error,
}

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isEnabled = true;
  double _volume = 0.5;

  // Sound file mappings
  static const Map<SoundType, String> _soundFiles = {
    SoundType.missionComplete: 'sounds/mission_complete.mp3',
    SoundType.chapterComplete: 'sounds/chapter_complete.mp3',
    SoundType.xpGained: 'sounds/xp_gained.mp3',
    SoundType.levelUp: 'sounds/level_up.mp3',
    SoundType.newMessage: 'sounds/new_message.mp3',
    SoundType.buddyRequest: 'sounds/buddy_request.mp3',
    SoundType.requestAccepted: 'sounds/request_accepted.mp3',
    SoundType.buttonTap: 'sounds/button_tap.mp3',
    SoundType.notification: 'sounds/notification.mp3',
    SoundType.error: 'sounds/error.mp3',
  };

  // Getter for sound enabled state
  bool get isEnabled => _isEnabled;
  double get volume => _volume;

  // Enable/disable sound effects
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      _audioPlayer.stop();
    }
  }

  // Set volume (0.0 to 1.0)
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
  }

  // Play a sound effect
  Future<void> playSound(SoundType soundType) async {
    if (!_isEnabled) return;

    try {
      final soundFile = _soundFiles[soundType];
      if (soundFile != null) {
        await _audioPlayer.play(AssetSource(soundFile));
        await _audioPlayer.setVolume(_volume);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error playing sound $soundType: $e');
      }
    }
  }

  // Play mission completion sound
  Future<void> playMissionComplete() async {
    await playSound(SoundType.missionComplete);
  }

  // Play chapter completion sound
  Future<void> playChapterComplete() async {
    await playSound(SoundType.chapterComplete);
  }

  // Play XP gained sound
  Future<void> playXpGained() async {
    await playSound(SoundType.xpGained);
  }

  // Play level up sound
  Future<void> playLevelUp() async {
    await playSound(SoundType.levelUp);
  }

  // Play new message sound
  Future<void> playNewMessage() async {
    await playSound(SoundType.newMessage);
  }

  // Play buddy request sound
  Future<void> playBuddyRequest() async {
    await playSound(SoundType.buddyRequest);
  }

  // Play request accepted sound
  Future<void> playRequestAccepted() async {
    await playSound(SoundType.requestAccepted);
  }

  // Play button tap sound
  Future<void> playButtonTap() async {
    await playSound(SoundType.buttonTap);
  }

  // Play notification sound
  Future<void> playNotification() async {
    await playSound(SoundType.notification);
  }

  // Play error sound
  Future<void> playError() async {
    await playSound(SoundType.error);
  }

  // Dispose resources
  void dispose() {
    _audioPlayer.dispose();
  }
}

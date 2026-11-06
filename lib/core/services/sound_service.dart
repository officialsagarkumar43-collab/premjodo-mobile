import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  AudioPlayer? _callPlayer;
  AudioPlayer? _messagePlayer;

  // Ultra-reliable, high quality preview sound tracks for call & chat
  static const String _outgoingCallSound =
      'https://assets.mixkit.co/active_storage/sfx/1359/1359-preview.mp3';
  static const String _incomingRingtoneSound =
      'https://assets.mixkit.co/active_storage/sfx/582/582-preview.mp3';
  static const String _incomingRingtoneAsset = 'sounds/incoming_ring.mp3';
  static const String _messageReceivedSound =
      'https://assets.mixkit.co/active_storage/sfx/2354/2354-preview.mp3';
  static const String _messageSentSound =
      'https://assets.mixkit.co/active_storage/sfx/2358/2358-preview.mp3';

  static const String _outgoingRingAsset = 'sounds/outgoing_ring.mp3';
  static const String _messageReceivedAsset = 'sounds/message_received.mp3';
  static const String _messageSentAsset = 'sounds/message_sent.mp3';

  Future<void> _setCallAudioContext({bool isRingtone = false}) async {
    try {
      final audioContext = AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: isRingtone ? AndroidContentType.music : AndroidContentType.speech,
          usageType: isRingtone ? AndroidUsageType.notificationRingtone : AndroidUsageType.voiceCommunication,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playAndRecord,
          options: const {
            AVAudioSessionOptions.defaultToSpeaker,
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      );
      await AudioPlayer.global.setAudioContext(audioContext);
    } catch (_) {}
  }

  Future<void> playOutgoingCallTone() async {
    try {
      await stopCallSounds();
      await _setCallAudioContext(isRingtone: false);
      _callPlayer = AudioPlayer();
      await _callPlayer!.setReleaseMode(ReleaseMode.loop);
      await _callPlayer!.setVolume(1.0);
      try {
        await _callPlayer!.play(AssetSource(_outgoingRingAsset));
      } catch (_) {
        await _callPlayer!.play(UrlSource(_outgoingCallSound));
      }
    } catch (e) {
      debugPrint('⚠️ [SoundService] Outgoing ring error: $e');
    }
  }

  Future<void> playIncomingRingtone() async {
    try {
      await stopCallSounds();
      await _setCallAudioContext(isRingtone: true);
      _callPlayer = AudioPlayer();
      await _callPlayer!.setReleaseMode(ReleaseMode.loop);
      await _callPlayer!.setVolume(1.0);
      try {
        await _callPlayer!.play(AssetSource(_incomingRingtoneAsset));
      } catch (_) {
        await _callPlayer!.play(UrlSource(_incomingRingtoneSound));
      }
    } catch (e) {
      debugPrint('⚠️ [SoundService] Ringtone error: $e');
    }
  }

  Future<void> stopCallSounds() async {
    try {
      if (_callPlayer != null) {
        await _callPlayer!.stop();
        await _callPlayer!.dispose();
        _callPlayer = null;
      }
    } catch (e) {
      debugPrint('⚠️ [SoundService] Stop call sound error: $e');
      _callPlayer = null;
    }
  }

  Future<void> playMessageReceived() async {
    try {
      _messagePlayer?.dispose();
      _messagePlayer = AudioPlayer();
      await _messagePlayer!.setVolume(0.8);
      try {
        await _messagePlayer!.play(AssetSource(_messageReceivedAsset));
      } catch (_) {
        await _messagePlayer!.play(UrlSource(_messageReceivedSound));
      }
    } catch (e) {
      debugPrint('⚠️ [SoundService] Message received sound error: $e');
    }
  }

  Future<void> playMessageSent() async {
    try {
      _messagePlayer?.dispose();
      _messagePlayer = AudioPlayer();
      await _messagePlayer!.setVolume(0.8);
      try {
        await _messagePlayer!.play(AssetSource(_messageSentAsset));
      } catch (_) {
        await _messagePlayer!.play(UrlSource(_messageSentSound));
      }
    } catch (e) {
      debugPrint('⚠️ [SoundService] Message sent sound error: $e');
    }
  }
}

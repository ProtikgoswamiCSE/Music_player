import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/media_track.dart';

class AudioPlayerProvider extends ChangeNotifier {
  AudioPlayerProvider() {
    _bindStreams();
    _configureSession();
  }

  final AudioPlayer _player = AudioPlayer();
  AudioPlayer get player => _player;

  MediaTrack? _current;
  MediaTrack? get currentTrack => _current;

  void _bindStreams() {
    _player.playbackEventStream.listen((_) => notifyListeners());
    _player.playerStateStream.listen((_) => notifyListeners());
    _player.positionStream.listen((_) => notifyListeners());
    _player.durationStream.listen((_) => notifyListeners());
  }

  Future<void> _configureSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  Future<void> playTrack(MediaTrack track) async {
    _current = track;
    notifyListeners();

    await _player.setAudioSource(
      AudioSource.uri(
        Uri.file(track.path),
        tag: MediaItem(
          id: track.path,
          title: track.title,
          album: track.kind == MediaKind.video
              ? 'Video · শুধু অডিও'
              : 'লোকাল অডিও',
        ),
      ),
    );
    await _player.play();
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.play();
  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> stop() async {
    await _player.stop();
    _current = null;
    notifyListeners();
  }

  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

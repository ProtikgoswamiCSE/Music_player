import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/audio_player_provider.dart';
import 'providers/media_library_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.music_player.audio',
    androidNotificationChannelName: 'Music playback',
    androidNotificationOngoing: true,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioPlayerProvider()),
        ChangeNotifierProvider(create: (_) => MediaLibraryProvider()),
      ],
      child: const MusicPlayerApp(),
    ),
  );
}

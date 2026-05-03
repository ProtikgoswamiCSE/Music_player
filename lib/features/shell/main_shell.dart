import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/audio_player_provider.dart';
import '../../providers/media_library_provider.dart';
import '../../widgets/aurora_background.dart';
import '../../widgets/mini_player_bar.dart';
import '../audio/audio_library_screen.dart';
import '../home/home_screen.dart';
import '../video/video_library_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _titles = ['Home', 'Audio', 'Video'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final lib = context.read<MediaLibraryProvider>();
      await Future.wait<void>([
        lib.loadDeviceMusic(),
        lib.loadDeviceVideos(),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: IndexedStack(
            index: _index,
            children: const [
              HomeScreen(),
              AudioLibraryScreen(),
              VideoLibraryScreen(),
            ],
          ),
        ),
        bottomNavigationBar: Consumer<AudioPlayerProvider>(
          builder: (context, audio, _) {
            final showMini = audio.currentTrack != null;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showMini) const MiniPlayerBar(),
                NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.home_outlined),
                      selectedIcon: const Icon(Icons.home_rounded),
                      label: _titles[0],
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.library_music_outlined),
                      selectedIcon: const Icon(Icons.library_music_rounded),
                      label: _titles[1],
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.movie_outlined),
                      selectedIcon: const Icon(Icons.movie_rounded),
                      label: _titles[2],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

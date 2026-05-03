import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/app.dart';
import 'package:music_player/providers/audio_player_provider.dart';
import 'package:music_player/providers/media_library_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('home shows app title', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AudioPlayerProvider()),
          ChangeNotifierProvider(create: (_) => MediaLibraryProvider()),
        ],
        child: const MusicPlayerApp(),
      ),
    );
    await tester.pump();
    expect(find.text('Music Player'), findsWidgets);
  });
}

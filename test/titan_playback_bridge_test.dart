import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/engine/moai_engine_player.dart';
import 'package:moai3/features/movies/titan_playback_bridge.dart';

void main() {
  TitanPlaybackBridge bridge(String url) =>
      TitanPlaybackBridge(streamUrl: url, programName: 'p1');

  test('sólo trabaja con el proxy local de Ranger', () {
    expect(bridge('http://127.0.0.1:42085/vod/0/x.m3u8').active, isTrue);
    expect(bridge('http://localhost:8080/vod/0/x.m3u8').active, isTrue);
    expect(bridge('https://cdn.example.com/x.m3u8').active, isFalse);
  });

  test('con otro stream no hace nada ni falla', () async {
    final b = bridge('https://cdn.example.com/x.m3u8');
    b.onEngineEvent(const MoaiEngineEvent(state: MoaiEngineState.ready));
    b.onPosition(const Duration(minutes: 1), const Duration(minutes: 2));
    b.onPause();
    b.onResume();
    await b.beforeSeek(const Duration(minutes: 5));
    b.reset();
    b.close();
  });
}

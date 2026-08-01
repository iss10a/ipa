import 'package:flutter_test/flutter_test.dart';
import 'package:pvo/domain/entities/download_settings.dart';
import 'package:pvo/domain/entities/download_task.dart';

void main() {
  group('DownloadSettings', () {
    test('throughput no longer depends on the priority the user picked', () {
      const low = DownloadSettings(priority: DownloadPriority.low);
      const high = DownloadSettings(priority: DownloadPriority.high);
      expect(low.effectiveParallel, high.effectiveParallel);
      expect(low.effectiveConnections, high.effectiveConnections);
    });

    test('runs several files at once', () {
      const settings = DownloadSettings();
      expect(settings.effectiveParallel, greaterThan(1));
    });

    test('survives a serialisation round trip', () {
      const original = DownloadSettings(
        priority: DownloadPriority.high,
        connections: 12,
        maxParallelDownloads: 6,
        engineMode: EngineMode.turbo,
        wifiOnly: false,
      );
      final restored = DownloadSettings.fromJson(original.toJson());
      expect(restored.priority, original.priority);
      expect(restored.engineMode, original.engineMode);
      expect(restored.wifiOnly, original.wifiOnly);
    });
  });
}

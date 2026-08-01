import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/di/providers.dart';

/// In-app player.
///
/// Backed by libmpv through media_kit rather than AVPlayer, because the files
/// this app downloads are routinely mkv or raw ts, which AVPlayer refuses.
/// Used for downloaded media (offline) and, later, for live channels.
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({
    super.key,
    required this.title,
    required this.source,
    this.resumeId,
    this.isLive = false,
  });

  /// Absolute file path for downloaded media, or a URL for a live stream.
  final String source;
  final String title;

  /// When set, playback position is remembered under this key.
  final String? resumeId;

  final bool isLive;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);

  StreamSubscription<Duration>? _positionSub;
  Timer? _saveTimer;
  Duration _position = Duration.zero;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Both orientations while watching; the app is portrait-only elsewhere.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _open();
  }

  Future<void> _open() async {
    try {
      await _player.open(Media(widget.source), play: true);

      if (!widget.isLive && widget.resumeId != null) {
        final saved = ref.read(localStoreProvider).readPosition(widget.resumeId!);
        if (saved > 5) {
          await _player.seek(Duration(seconds: saved));
        }
      }

      _positionSub = _player.stream.position.listen((value) {
        _position = value;
      });

      // Persisting every frame would hammer the box; once every five seconds is
      // enough to make a resume feel exact.
      if (!widget.isLive && widget.resumeId != null) {
        _saveTimer = Timer.periodic(
            const Duration(seconds: 5), (_) => _savePosition());
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذّر تشغيل هذا الملف.');
    }
  }

  void _savePosition() {
    final id = widget.resumeId;
    if (id == null || widget.isLive) return;

    final duration = _player.state.duration;
    // Near the end, clear the marker so the next play starts fresh.
    if (duration.inSeconds > 0 &&
        _position.inSeconds >= duration.inSeconds - 15) {
      unawaited(ref.read(localStoreProvider).clearPosition(id));
      return;
    }
    unawaited(ref.read(localStoreProvider).writePosition(id, _position.inSeconds));
  }

  @override
  void dispose() {
    _savePosition();
    _saveTimer?.cancel();
    unawaited(_positionSub?.cancel());
    unawaited(_player.dispose());
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        // The light theme paints titles and icons dark, which would vanish
        // against the player's black chrome.
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 44, color: Colors.white54),
                    const SizedBox(height: 16),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white70, height: 1.6)),
                  ],
                ),
              )
            : Video(
                controller: _controller,
                controls: AdaptiveVideoControls,
              ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Reusable SDUI video primitive with init / error / dispose lifecycle.
class SduiVideoPlayer extends StatefulWidget {
  const SduiVideoPlayer({
    super.key,
    required this.url,
    this.height = 200,
    this.width,
    this.autoplay = false,
    this.looping = true,
    this.muted = true,
    this.fit = BoxFit.cover,
    this.radius = 12,
  });

  final String url;
  final double height;
  final double? width;
  final bool autoplay;
  final bool looping;
  final bool muted;
  final BoxFit fit;
  final double radius;

  @override
  State<SduiVideoPlayer> createState() => _SduiVideoPlayerState();
}

class _SduiVideoPlayerState extends State<SduiVideoPlayer> {
  VideoPlayerController? _controller;
  Object? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant SduiVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _init();
    }
  }

  Future<void> _init() async {
    if (widget.url.isEmpty) {
      setState(() => _error = 'Missing video url');
      return;
    }
    final uri = Uri.tryParse(widget.url);
    if (uri == null) {
      setState(() => _error = 'Invalid video url');
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(widget.looping);
      await controller.setVolume(widget.muted ? 0 : 1);
      if (widget.autoplay) {
        await controller.play();
      }
      if (!mounted) return;
      setState(() {
        _ready = true;
        _error = null;
      });
    } catch (e, st) {
      debugPrint('[SDUI][Video] init failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e;
        _ready = false;
      });
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _ready = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: ColoredBox(color: Colors.black26, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return const Center(
        child: Icon(Icons.videocam_off_outlined, color: Colors.white54),
      );
    }
    if (!_ready || _controller == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final controller = _controller!;
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: widget.fit,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              iconSize: 20,
              color: Colors.white,
              icon: Icon(
                controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
              onPressed: () {
                setState(() {
                  if (controller.value.isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}

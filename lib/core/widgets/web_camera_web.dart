// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

html.MediaStream? _currentWebStream;
html.VideoElement? _currentVideoElement;
int _viewCounter = 0;

Widget getPlatformWebCameraView({Key? key, bool isFrontCamera = true}) {
  return WebCameraWidget(key: key, isFrontCamera: isFrontCamera);
}

void stopPlatformWebCamera() {
  try {
    _currentWebStream?.getTracks().forEach((track) => track.stop());
    _currentWebStream = null;
    if (_currentVideoElement != null) {
      _currentVideoElement?.srcObject = null;
      _currentVideoElement = null;
    }
  } catch (_) {}
}

class WebCameraWidget extends StatefulWidget {
  final bool isFrontCamera;
  const WebCameraWidget({super.key, this.isFrontCamera = true});

  @override
  State<WebCameraWidget> createState() => _WebCameraWidgetState();
}

class _WebCameraWidgetState extends State<WebCameraWidget> {
  late final String _viewType;
  html.VideoElement? _videoElement;

  @override
  void initState() {
    super.initState();
    _viewType = 'web-camera-view-${_viewCounter++}';
    _setupCamera();
  }

  void _setupCamera() {
    _videoElement = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.transform = widget.isFrontCamera ? 'scaleX(-1)' : 'none';

    _currentVideoElement = _videoElement;

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _videoElement!,
    );

    _startStream();
  }

  Future<void> _startStream() async {
    try {
      final mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': {
          'facingMode': widget.isFrontCamera ? 'user' : 'environment',
        },
        'audio': false,
      });

      if (mediaStream != null && mounted) {
        _currentWebStream = mediaStream;
        _videoElement?.srcObject = mediaStream;
        setState(() {});
      }
    } catch (e) {
      debugPrint('Web Camera Access Error: $e');
    }
  }

  @override
  void didUpdateWidget(covariant WebCameraWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFrontCamera != widget.isFrontCamera) {
      _videoElement?.style.transform = widget.isFrontCamera ? 'scaleX(-1)' : 'none';
    }
  }

  @override
  void dispose() {
    stopPlatformWebCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

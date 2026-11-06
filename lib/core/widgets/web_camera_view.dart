import 'package:flutter/material.dart';
import 'web_camera_stub.dart'
    if (dart.library.html) 'web_camera_web.dart' as platform_cam;

class WebCameraView extends StatelessWidget {
  final bool isFrontCamera;
  const WebCameraView({super.key, this.isFrontCamera = true});

  @override
  Widget build(BuildContext context) {
    return platform_cam.getPlatformWebCameraView(key: key, isFrontCamera: isFrontCamera);
  }

  static void stopCamera() {
    platform_cam.stopPlatformWebCamera();
  }
}

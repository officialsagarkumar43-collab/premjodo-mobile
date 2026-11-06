import 'package:flutter/material.dart';

Widget getPlatformWebCameraView({Key? key, bool isFrontCamera = true}) {
  return Container(
    color: const Color(0xFF1E1226),
    child: const Center(
      child: Icon(Icons.videocam_rounded, color: Colors.white38, size: 48),
    ),
  );
}

void stopPlatformWebCamera() {}

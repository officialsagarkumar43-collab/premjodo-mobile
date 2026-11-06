import 'dart:io';

class ImageHelper {
  static const String cloudinaryBase = 'https://res.cloudinary.com';
  static const String backendBase = 'https://prem-jodo-backend.onrender.com';

  /// Resolves any relative or absolute image URL (Cloudinary path, backend upload, local file, or full URL)
  static String resolveImageUrl(dynamic input) {
    if (input == null) return '';

    if (input is List) {
      for (var item in input) {
        final res = resolveImageUrl(item);
        if (res.isNotEmpty) return res;
      }
      return '';
    }

    String raw = '';
    if (input is String) {
      raw = input.trim();
    } else if (input is Map) {
      final urlCandidate = input['url'] ?? input['secure_url'] ?? input['path'] ?? input['fileUrl'];
      if (urlCandidate != null) {
        raw = urlCandidate.toString().trim();
      }
    }

    if (raw.isEmpty || raw == 'null' || raw == 'undefined') return '';

    // Replace localhost or emulator loops with production backend URL
    if (raw.contains('localhost:5000') ||
        raw.contains('10.0.2.2:5000') ||
        raw.contains('127.0.0.1:5000') ||
        raw.contains('localhost:3000')) {
      raw = raw
          .replaceAll('http://localhost:5000', backendBase)
          .replaceAll('http://10.0.2.2:5000', backendBase)
          .replaceAll('http://127.0.0.1:5000', backendBase)
          .replaceAll('https://localhost:5000', backendBase)
          .replaceAll('http://localhost:3000', backendBase);
    }

    // Enforce HTTPS for backend uploads to comply with Android cleartext security
    if (raw.startsWith('http://prem-jodo-backend.onrender.com')) {
      raw = raw.replaceFirst('http://', 'https://');
    }

    // If it's already an absolute web URL or base64 data
    if (raw.startsWith('http://') ||
        raw.startsWith('https://') ||
        raw.startsWith('data:') ||
        raw.startsWith('blob:')) {
      return raw;
    }

    if (raw.startsWith('//')) {
      return 'https:$raw';
    }

    // If it's a local filesystem path on Android/iOS/Desktop
    if (raw.startsWith('/data/') ||
        raw.startsWith('/storage/') ||
        raw.startsWith('/var/') ||
        raw.startsWith('/private/') ||
        raw.startsWith('file:') ||
        raw.contains('com.example') ||
        raw.contains('image_picker') ||
        raw.contains('cache') ||
        raw.startsWith('C:') ||
        raw.startsWith('D:')) {
      return raw;
    }

    try {
      if (File(raw).existsSync()) {
        return raw;
      }
    } catch (_) {}

    // Cloudinary full path relative
    if (raw.contains('image/upload/') && !raw.startsWith('http')) {
      final clean = raw.startsWith('/') ? raw : '/$raw';
      return '$cloudinaryBase$clean';
    }

    // If it's a relative backend upload
    if (raw.startsWith('/uploads') || raw.startsWith('uploads/')) {
      final clean = raw.startsWith('/') ? raw : '/$raw';
      return '$backendBase$clean';
    }

    // If it's a direct filename or relative path
    final cleanPath = raw.startsWith('/') ? raw : '/$raw';
    if (!raw.contains('/')) {
      return '$backendBase/uploads$cleanPath';
    }
    return '$backendBase$cleanPath';
  }
}


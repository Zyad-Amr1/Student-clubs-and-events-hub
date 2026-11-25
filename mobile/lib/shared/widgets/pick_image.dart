import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

Future<String?> pickImage() async {
  final bytes = await const MethodChannel('campusconnect/images')
      .invokeMethod<Uint8List>('pick');
  return bytes == null ? null : base64Encode(bytes);
}

class UploadedImage extends StatelessWidget {
  const UploadedImage(this.source, {this.size = 72, super.key});
  final String? source;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(Icons.account_circle_outlined, size: size);
    const prefix = 'data:image/jpeg;base64,';
    final value = source;
    if (value == null || !value.startsWith(prefix)) return fallback;
    try {
      return ClipOval(
        child: Image.memory(
          base64Decode(value.substring(prefix.length)),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      );
    } on FormatException {
      return fallback;
    }
  }
}

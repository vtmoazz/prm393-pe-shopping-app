import 'dart:io';

import 'package:flutter/material.dart';

/// Shows a product image from a URL or a local file, with a placeholder.
class ProductImage extends StatelessWidget {
  const ProductImage({super.key, this.source, this.size, this.height});

  final String? source;
  final double? size;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final width = size;
    final h = height ?? size;
    final placeholder = Container(
      width: width,
      height: h,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, size: 32),
    );

    final src = source?.trim();
    if (src == null || src.isEmpty) return placeholder;

    final isUrl = src.startsWith('http://') || src.startsWith('https://');
    final image = isUrl
        ? Image.network(src, width: width, height: h, fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) => progress == null ? child : placeholder,
            errorBuilder: (_, _, _) => placeholder)
        : Image.file(File(src), width: width, height: h, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => placeholder);
    return ClipRRect(borderRadius: BorderRadius.circular(8), child: image);
  }
}

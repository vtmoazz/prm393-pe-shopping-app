import 'dart:io';

import 'package:flutter/material.dart';

/// Shows a product image from a URL or a local file, with a placeholder.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    this.source,
    this.size,
    this.height,
    this.radius = 8,
  });

  final String? source;
  final double? size;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final width = size;
    final h = height ?? size;
    final placeholder = Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        size: 32,
        color: Theme.of(context).colorScheme.primary,
      ),
    );

    final src = source?.trim();
    if (src == null || src.isEmpty) return placeholder;

    final isUrl = src.startsWith('http://') || src.startsWith('https://');
    final image = isUrl
        ? Image.network(
            src,
            width: width,
            height: h,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : placeholder,
            errorBuilder: (_, _, _) => placeholder,
          )
        : Image.file(
            File(src),
            width: width,
            height: h,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => placeholder,
          );
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }
}

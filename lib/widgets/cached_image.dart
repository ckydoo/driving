import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Optimized cached image widget with built-in placeholder and error handling
/// Uses memory caching to reduce RAM usage and improve performance
class CachedImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData placeholderIcon;
  final IconData errorIcon;
  final Color? iconColor;
  final double? iconSize;
  final BorderRadius? borderRadius;

  const CachedImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.person,
    this.errorIcon = Icons.broken_image,
    this.iconColor,
    this.iconSize,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? Theme.of(context).iconTheme.color;
    final effectiveIconSize = iconSize ?? 40.0;

    // If no image URL provided, show placeholder
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder(effectiveIconColor, effectiveIconSize);
    }

    Widget imageWidget = CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      // Optimize memory usage by limiting cache size
      memCacheWidth: width != null ? (width! * 2).toInt() : 400,
      memCacheHeight: height != null ? (height! * 2).toInt() : 400,
      placeholder: (context, url) => _buildLoadingPlaceholder(effectiveIconColor, effectiveIconSize),
      errorWidget: (context, url, error) => _buildErrorWidget(effectiveIconColor, effectiveIconSize),
      // Cache for 7 days
      cacheKey: imageUrl,
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
    );

    // Apply border radius if specified
    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildPlaceholder(Color? color, double size) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Center(
        child: Icon(
          placeholderIcon,
          color: color ?? Colors.grey[400],
          size: size,
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder(Color? color, double size) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size * 0.6,
              height: size * 0.6,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  color ?? Colors.grey[400]!,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(Color? color, double size) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Center(
        child: Icon(
          errorIcon,
          color: Colors.red[300],
          size: size,
        ),
      ),
    );
  }
}

/// Circular avatar with cached image support
class CachedAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final IconData placeholderIcon;
  final Color? backgroundColor;
  final Color? iconColor;

  const CachedAvatar({
    Key? key,
    required this.imageUrl,
    this.radius = 20,
    this.placeholderIcon = Icons.person,
    this.backgroundColor,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = backgroundColor ?? Colors.grey[300];
    final effectiveIconColor = iconColor ?? Colors.grey[600];

    return CircleAvatar(
      radius: radius,
      backgroundColor: effectiveBackgroundColor,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                // Optimize for small avatars
                memCacheWidth: (radius * 4).toInt(),
                memCacheHeight: (radius * 4).toInt(),
                placeholder: (context, url) => Icon(
                  placeholderIcon,
                  color: effectiveIconColor,
                  size: radius,
                ),
                errorWidget: (context, url, error) => Icon(
                  placeholderIcon,
                  color: effectiveIconColor,
                  size: radius,
                ),
              ),
            )
          : Icon(
              placeholderIcon,
              color: effectiveIconColor,
              size: radius,
            ),
    );
  }
}

/// Example usage documentation
///
/// Basic usage:
/// ```dart
/// CachedImage(
///   imageUrl: student.profileImageUrl,
///   width: 200,
///   height: 200,
///   borderRadius: BorderRadius.circular(12),
/// )
/// ```
///
/// Avatar usage:
/// ```dart
/// CachedAvatar(
///   imageUrl: user.avatarUrl,
///   radius: 30,
/// )
/// ```

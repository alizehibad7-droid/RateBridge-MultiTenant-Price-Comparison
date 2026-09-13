import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Network image that works on Flutter Web (CanvasKit) and logs load failures.
///
/// [CachedNetworkImage] on web uses `createImageCodecFromUrl`, which can hang
/// on the placeholder and swallow errors. This widget fetches image bytes
/// (Cloudinary already sends CORS) and falls back to an HTML `<img>` if decode
/// fails.
class AppNetworkImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget fallback;
  final Widget? loading;
  final String? debugLabel;

  const AppNetworkImage({
    super.key,
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.loading,
    this.debugLabel,
  });

  static String? resolveUrl(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    if (uri.hasScheme && uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }
    return trimmed;
  }

  void _log(String message) {
    if (kDebugMode) {
      final tag = debugLabel == null || debugLabel!.isEmpty
          ? 'AppNetworkImage'
          : 'AppNetworkImage[$debugLabel]';
      debugPrint('$tag $message');
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolved = resolveUrl(url);
    if (resolved == null) {
      _log('no usable URL (raw=${url == null ? 'null' : '"$url"'})');
      return fallback;
    }

    _log('loading $resolved');
    return Image.network(
      resolved,
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return loading ?? _defaultLoading();
      },
      errorBuilder: (context, error, stackTrace) {
        _log('FAILED url=$resolved error=$error');
        return fallback;
      },
    );
  }

  Widget _defaultLoading() {
    return ColoredBox(
      color: const Color(0xFFE2E5F0),
      child: Center(
        child: SizedBox(
          width: width != null && width! < 40 ? 16 : 22,
          height: height != null && height! < 40 ? 16 : 22,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

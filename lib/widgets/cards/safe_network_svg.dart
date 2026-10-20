import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

/// SVG de red: si el cuerpo no es SVG (HTML/404), no se lo pasa al parser.
class SafeNetworkSvg extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final Map<String, String>? headers;
  final WidgetBuilder? placeholderBuilder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const SafeNetworkSvg({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.headers,
    this.placeholderBuilder,
    this.errorBuilder,
  });

  @override
  State<SafeNetworkSvg> createState() => _SafeNetworkSvgState();
}

class _SafeNetworkSvgState extends State<SafeNetworkSvg> {
  static final Set<String> _failedUrls = {};

  String? _svgXml;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _failed = _failedUrls.contains(widget.url);
    if (!_failed) {
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant SafeNetworkSvg oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url) return;
    _svgXml = null;
    _failed = _failedUrls.contains(widget.url);
    if (!_failed) {
      _load();
    }
  }

  Future<void> _load() async {
    final url = widget.url;
    try {
      final response = await http.get(Uri.parse(url), headers: widget.headers);
      if (url != widget.url) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _markFailed(url);
        return;
      }
      final xml = utf8.decode(response.bodyBytes, allowMalformed: true);
      if (!_looksLikeSvg(xml)) {
        _markFailed(url);
        return;
      }
      if (!mounted) return;
      setState(() => _svgXml = xml);
    } catch (_) {
      if (url != widget.url) return;
      _markFailed(url);
    }
  }

  bool _looksLikeSvg(String xml) {
    final start = xml.trimLeft().toLowerCase();
    if (start.startsWith('<!doctype html') || start.startsWith('<html')) {
      return false;
    }
    return start.contains('<svg');
  }

  void _markFailed(String url) {
    _failedUrls.add(url);
    if (!mounted) return;
    setState(() {
      _failed = true;
      _svgXml = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = widget.placeholderBuilder?.call(context) ??
        SizedBox(width: widget.width, height: widget.height);
    if (_failed) {
      return widget.errorBuilder?.call(
            context,
            StateError('svg failed'),
            StackTrace.empty,
          ) ??
          placeholder;
    }
    final xml = _svgXml;
    if (xml == null) return placeholder;
    return SvgPicture.string(
      xml,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      placeholderBuilder: (_) => placeholder,
      errorBuilder: (context, error, stackTrace) {
        _failedUrls.add(widget.url);
        if (mounted && !_failed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _markFailed(widget.url);
          });
        }
        return widget.errorBuilder?.call(context, error, stackTrace) ??
            placeholder;
      },
    );
  }
}

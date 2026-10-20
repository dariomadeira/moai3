import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/services/moai_image_cache_manager.dart';
import 'package:moai3/widgets/cards/safe_network_svg.dart';
import 'package:moai3/widgets/cards/tv_list_card_leading_logo.dart';

void main() {
  test('MoaiImageCacheManager usa versión 3 sin distorsión', () {
    expect(MoaiImageCacheManager.key, equals('moai_channel_logos_v3'));
  });

  testWidgets('TvListCardLeadingLogo renderiza placeholder cuando la URL está vacía', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TvListCardLeadingLogo(
            logoUrl: '',
            width: 54,
            height: 36,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.tv_outlined), findsOneWidget);
  });

  testWidgets('TvListCardLeadingLogo usa BoxFit.contain y alignment center en CachedNetworkImage', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TvListCardLeadingLogo(
            logoUrl: 'https://example.com/logo.png',
            width: 54,
            height: 36,
          ),
        ),
      ),
    );

    final cachedImageFinder = find.byType(CachedNetworkImage);
    expect(cachedImageFinder, findsOneWidget);

    final cachedImage = tester.widget<CachedNetworkImage>(cachedImageFinder);
    expect(cachedImage.fit, equals(BoxFit.contain));
    expect(cachedImage.alignment, equals(Alignment.center));
    expect(cachedImage.memCacheWidth, isNull);
    expect(cachedImage.maxWidthDiskCache, isNull);
    expect(cachedImage.maxHeightDiskCache, isNull);
    expect(cachedImage.memCacheHeight, equals(120));
  });

  testWidgets('TvListCardLeadingLogo usa BoxFit.contain en SVG', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TvListCardLeadingLogo(
            logoUrl: 'https://example.com/logo.svg',
            width: 54,
            height: 36,
          ),
        ),
      ),
    );

    final svgFinder = find.byType(SafeNetworkSvg);
    expect(svgFinder, findsOneWidget);

    final svgWidget = tester.widget<SafeNetworkSvg>(svgFinder);
    expect(svgWidget.fit, equals(BoxFit.contain));
    expect(svgWidget.alignment, equals(Alignment.center));
  });

  testWidgets('TvListCardLeadingLogo usa BoxFit.contain en Image.asset', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TvListCardLeadingLogo(
            logoUrl: 'assets/channels/telefe.png',
            width: 54,
            height: 36,
          ),
        ),
      ),
    );

    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);

    final imageWidget = tester.widget<Image>(imageFinder);
    expect(imageWidget.fit, equals(BoxFit.contain));
    expect(imageWidget.alignment, equals(Alignment.center));
  });
}

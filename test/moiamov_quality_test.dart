import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/moiamov_api_service.dart';

void main() {
  VodQualityOption q(String name) =>
      VodQualityOption(quality: name, sources: const []);
  String pick(List<String> names) =>
      MoiamovApiService.pickBestQuality([for (final n in names) q(n)]).quality;

  test('prefiere 1080p aunque haya 4K', () {
    expect(pick(['4K', '1080P', '720P']), '1080P');
  });

  test('4K sólo si no hay 1080p', () {
    expect(pick(['720P', '4K']), '4K');
  });

  test('sin calidades altas, la primera', () {
    expect(pick(['720P', '480P']), '720P');
  });
}

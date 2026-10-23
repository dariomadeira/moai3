import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moai3/app/bootstrap.dart';
import 'package:moai3/app/moai_app.dart';
import 'package:moai3/config/constants.dart';

void main() async {
  final deps = await AppBootstrap.run();
  runApp(
    EasyLocalization(
      path: kTranslationsPath,
      supportedLocales: kSupportedLocales,
      fallbackLocale: kFallbackLocale,
      child: MultiProvider(
        providers: deps.providers,
        child: MoaiApp(
          router: deps.router,
          identityService: deps.identity,
          presenceService: deps.presence,
        ),
      ),
    ),
  );
}

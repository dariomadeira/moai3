import 'dart:async';
import 'package:easy_localization/easy_localization.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  EasyLocalization.logger.enableBuildModes = [];
  await testMain();
}

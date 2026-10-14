// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void dismissWebSplash() {
  try {
    js.context.callMethod('dismissSplash');
    js.context.callMethod('dismissPreloader');
  } catch (_) {}
}

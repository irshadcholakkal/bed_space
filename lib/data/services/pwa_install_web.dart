import 'dart:js_interop';

@JS('bedspaceInstallApp')
external JSPromise<JSString> _install();
@JS('bedspaceIsInstalled')
external JSBoolean _installed();

Future<String> installPwa() async {
  try {
    return (await _install().toDart).toDart;
  } catch (_) {
    return 'manual_browser';
  }
}

bool isPwaInstalled() {
  try {
    return _installed().toDart;
  } catch (_) {
    return false;
  }
}

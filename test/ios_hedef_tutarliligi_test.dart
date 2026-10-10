// iOS DAĞITIM HEDEFİ TEK DEĞER: Podfile platform satırı, Podfile
// post_install, Xcode proje ayarları ve AppFrameworkInfo AYNI olmalı.
// (Önceden post_install 12.0, platform 13.0'dı.)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS dağıtım hedefi her yerde 13.0', () {
    final podfile = File('ios/Podfile').readAsStringSync();
    expect(podfile.contains("platform :ios, '13.0'"), isTrue);
    final postInstall = RegExp(r"IPHONEOS_DEPLOYMENT_TARGET'\] = '([0-9.]+)'")
        .allMatches(podfile)
        .map((m) => m.group(1))
        .toSet();
    expect(postInstall, {'13.0'});
    final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final xcode = RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);')
        .allMatches(pbx)
        .map((m) => m.group(1))
        .toSet();
    expect(xcode, {'13.0'});
    final plist = File('ios/Flutter/AppFrameworkInfo.plist').readAsStringSync();
    expect(
        RegExp(r'<key>MinimumOSVersion</key>\s*<string>13\.0</string>')
            .hasMatch(plist),
        isTrue);
  });
}

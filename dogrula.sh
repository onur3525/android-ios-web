#!/bin/sh
# HizmetCep — proje bütünlük denetimi
# Kullanım: sh dogrula.sh   (proje kökünde)

hata=0
echo "═══ PROJE KÖKÜ ═══"
for f in pubspec.yaml analysis_options.yaml README.md; do
  if [ -s "$f" ]; then echo "  ✓ $f"; else echo "  ✗ $f YOK"; hata=1; fi
done
for d in lib android ios assets test; do
  if [ -d "$d" ]; then echo "  ✓ $d/ ($(find $d -type f | wc -l) dosya)"; else echo "  ✗ $d/ YOK"; hata=1; fi
done

echo ""
echo "═══ ANDROID WRAPPER ═══"
if [ -s android/gradle/wrapper/gradle-wrapper.properties ]; then
  echo "  ✓ gradle-wrapper.properties"
else
  echo "  ✗ gradle-wrapper.properties YOK"; hata=1
fi
if [ -s android/gradle/wrapper/gradle-wrapper.jar ]; then
  echo "  ✓ gradle-wrapper.jar"
else
  echo "  ⚠ gradle-wrapper.jar YOK — bkz. android/WRAPPER_JAR_NOTU.md"
  echo "    Çözüm: flutter create --platforms=android ."
fi
for f in android/gradlew android/gradlew.bat android/app/build.gradle \
         android/app/src/main/AndroidManifest.xml; do
  if [ -s "$f" ]; then echo "  ✓ $(basename $f)"; else echo "  ✗ $f YOK"; hata=1; fi
done

echo ""
echo "═══ iOS ═══"
for f in ios/Runner.xcodeproj/project.pbxproj ios/Podfile ios/Runner/Info.plist \
         ios/Runner/AppDelegate.swift; do
  if [ -s "$f" ]; then echo "  ✓ $(basename $f)"; else echo "  ✗ $f YOK"; hata=1; fi
done

echo ""
echo "═══ FONT ═══"
for f in assets/fonts/Poppins-Regular.ttf assets/fonts/Poppins-Medium.ttf \
         assets/fonts/Poppins-Bold.ttf; do
  if [ -s "$f" ]; then echo "  ✓ $(basename $f) ($(stat -c%s $f 2>/dev/null || stat -f%z $f) bayt)"
  else echo "  ✗ $f YOK"; hata=1; fi
done

echo ""
if [ $hata -eq 0 ]; then
  echo "SONUÇ: kritik eksik YOK"
else
  echo "SONUÇ: kritik eksik VAR (yukarıda ✗ ile işaretli)"
fi
exit $hata

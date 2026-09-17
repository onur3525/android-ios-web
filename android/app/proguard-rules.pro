# ── Flutter ──
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ── Google Sign-In ──
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ── Kotlin ──
-keep class kotlin.** { *; }
-dontwarn kotlin.**

# Yığın izlerinde satır numarası korunur (crash raporları için).
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ─────────────────────────────────────────────
#  Flutter / Dart background isolates & VM entry points
# ─────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.view.FlutterCallbackInformation { *; }
-keep class io.flutter.embedding.engine.dart.DartExecutor$DartCallback { *; }
-keepattributes *Annotation*

# ─────────────────────────────────────────────
#  Firebase / FCM
# ─────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-keep class io.flutter.plugins.firebase.messaging.** { *; }
-keep class io.flutter.plugins.firebase.core.** { *; }

# ─────────────────────────────────────────────
#  Awesome Notifications
# ─────────────────────────────────────────────
-keep class me.carda.awesome_notifications.** { *; }
-keep class me.carda.awesome_notifications.core.** { *; }
-dontwarn me.carda.awesome_notifications.**

# ─────────────────────────────────────────────
#  Flutter Secure Storage (used in background isolate for approve/reject)
# ─────────────────────────────────────────────
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# ─────────────────────────────────────────────
#  sqlite3 native (sqlite3_flutter_libs)
# ─────────────────────────────────────────────
-keep class eu.simonbinder.sqlite3_flutter_libs.** { *; }
-dontwarn eu.simonbinder.sqlite3_flutter_libs.**

# ─────────────────────────────────────────────
#  Google Play Core (deferred components) — referenced by Flutter engine
#  but not bundled in every build. Ignore safely.
# ─────────────────────────────────────────────
-dontwarn com.google.android.play.core.**

# ─────────────────────────────────────────────
#  Misc — signatures, native methods, kotlin
# ─────────────────────────────────────────────
-keepattributes Signature,*Annotation*,EnclosingMethod,InnerClasses
-keepclasseswithmembernames class * { native <methods>; }
-keep class kotlin.Metadata { *; }

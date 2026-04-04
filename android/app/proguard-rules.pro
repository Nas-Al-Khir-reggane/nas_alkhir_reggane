# 1. Firebase Rules
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.firebase.** { *; }

# 2. Google Maps
-keep class com.google.android.gms.maps.** { *; }
-keep class com.google.android.gms.common.** { *; }

# 3. GetX & Models
-keep class com.nasalkheir.nas_alkheir_app.data.models.** { *; }
-keepclassmembers class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# 4. Flutter Local Notifications (ضروري جداً لعمل الإشعارات في الخلفية)
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.google.firebase.messaging.** { *; }

# 5. Flutter Internal Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# تجاهل الأخطاء المتعلقة بمكتبات Play Core المفقودة
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

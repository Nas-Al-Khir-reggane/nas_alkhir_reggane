# 1. Firebase Rules (مهم جداً لاتصال قاعدة البيانات)
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.firebase.** { *; }

# 2. Google Maps (لضمان ظهور الخرائط بشكل صحيح)
-keep class com.google.android.gms.maps.** { *; }
-keep class com.google.android.gms.common.** { *; }

# 3. GetX & Models (لكي لا تضيع بيانات المستخدم عند تحويلها من Firestore)
-keep class com.nasalkheir.nas_al_kheir.models.** { *; }
-keepclassmembers class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# 4. Flutter Internal Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# تجاهل الأخطاء المتعلقة بمكتبات Play Core المفقودة
-dontwarn com.google.android.play.core.**

# قواعد إضافية لضمان عدم توقف البناء بسبب مكتبات أندرويد الداخلية
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

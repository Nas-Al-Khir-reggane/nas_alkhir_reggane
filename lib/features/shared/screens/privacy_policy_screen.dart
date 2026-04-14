import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// شاشة سياسة الخصوصية وشروط الاستخدام
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('سياسة الخصوصية',
            style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Markdown(
          data: _policyContent,
          padding: const EdgeInsets.all(20),
          styleSheet: MarkdownStyleSheet(
            h1: GoogleFonts.tajawal(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary),
            h2: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface),
            h3: GoogleFonts.tajawal(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface),
            p: GoogleFonts.tajawal(
                fontSize: 14,
                height: 1.8,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            listBullet: GoogleFonts.tajawal(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  static const String _policyContent = '''
# سياسة الخصوصية

**آخر تحديث:** أبريل 2026

## مقدمة

تلتزم جمعية ناس الخير — رقان بحماية خصوصية مستخدمي تطبيقها. توضح هذه السياسة كيفية جمع واستخدام وحماية بياناتك الشخصية.

## البيانات التي نجمعها

### بيانات التسجيل
- الاسم الكامل
- رقم الهاتف
- البريد الإلكتروني
- العنوان (الولاية، البلدية)
- فصيلة الدم (اختياري)

### بيانات الاستخدام
- سجل التبرعات والمساهمات
- طلبات الخدمة المقدمة
- تفاعلات المحادثة

## كيف نستخدم بياناتك

- **تقديم الخدمات:** لإدارة طلبات المساعدة والتبرعات
- **الإشعارات:** لإرسال تنبيهات الطوارئ ونداءات التبرع بالدم
- **التحسين:** لتطوير خدمات الجمعية وتجربة المستخدم
- **التواصل:** لتمكين المحادثات بين أعضاء الجمعية

## حماية البيانات

- جميع البيانات مشفّرة أثناء النقل والتخزين
- نستخدم خدمات Firebase المؤمنة من Google
- لا نبيع أو نشارك بياناتك مع أطراف ثالثة
- يتم تقييد الوصول للبيانات حسب الدور

## حقوقك

- **الاطلاع:** يحق لك معرفة البيانات المخزنة عنك
- **التعديل:** يمكنك تحديث بياناتك من الملف الشخصي
- **الحذف:** يمكنك طلب حذف حسابك وبياناتك بالتواصل مع الإدارة

## ملفات تعريف الارتباط

التطبيق لا يستخدم ملفات تعريف الارتباط (Cookies). نستخدم التخزين المحلي فقط لحفظ إعداداتك.

## التحديثات

قد نحدّث هذه السياسة من وقت لآخر. سيتم إعلامك بأي تغييرات جوهرية عبر إشعار داخل التطبيق.

## التواصل

لأي استفسار حول الخصوصية، تواصل معنا عبر:
- **التطبيق:** رسالة مباشرة للإدارة
- **الموقع:** https://nasalkheir.org
''';
}

import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class AppConstants {
  static const String appName = "جمعية ناس الخير رقان";

  static void toggleTheme() {
    ThemeService().cycleTheme();
  }

  static const List<String> algeriaWilayas = [
    "01 - أدرار", "02 - الشلف", "03 - الأغواط", "04 - أم البواقي", "05 - باتنة",
    "06 - بجاية", "07 - بسكرة", "08 - بشار", "09 - البليدة", "10 - البويرة",
    "11 - تمنراست", "12 - تبسة", "13 - تلمسان", "14 - تيارت", "15 - تيزي وزو",
    "16 - الجزائر", "17 - الجلفة", "18 - جيجل", "19 - سطيف", "20 - سعيدة",
    "21 - سكيكدة", "22 - سيدي بلعباس", "23 - عنابة", "24 - قالمة", "25 - قسنطينة",
    "26 - المدية", "27 - مستغانم", "28 - المسيلة", "29 - معسكر", "30 - ورقلة",
    "31 - وهران", "32 - البيض", "33 - إليزي", "34 - برج بوعريريج", "35 - بومرداس",
    "36 - الطارف", "37 - تندوف", "38 - تسمسيلت", "39 - الوادي", "40 - خنشلة",
    "41 - سوق أهراس", "42 - تيبازة", "43 - ميلة", "44 - عين الدفلى", "45 - النعامة",
    "46 - عين تموشنت", "47 - غرداية", "48 - غليزان", "49 - تيميمون", "50 - برج باجي مختار",
    "51 - أولاد جلال", "52 - بني عباس", "53 - عين صالح", "54 - عين قزام", "55 - تقرت",
    "56 - جانت", "57 - المغير", "58 - المنيعة"
  ];

  static const Map<String, List<String>> wilayaCommunes = {
    "01 - أدرار": ["أدرار", "تامست", "تمنطيط", "فنوغيل", "إن زجمير", "رقان", "سالي", "أولاد أحمد تيمي", "بودا", "أوقروت", "دلدول", "المطارفة", "تيمقطن", "أولف", "أقبلي", "تيت"],
    "02 - الشلف": ["الشلف", "وادي الفضة", "بوقادير", "تنس", "أولاد فارس", "تاوقريت", "بني حواء", "سنجاس", "المرسى"],
    "03 - الأغواط": ["الأغواط", "أفلو", "عين ماضي", "حاسي الرمل", "قصر الحيران", "الغيشة", "بريدة", "سيدي مخلوف"],
    "04 - أم البواقي": ["أم البواقي", "عين البيضاء", "عين مليلة", "عين فكرون", "مسكيانة", "قصر الصبيحي"],
    "05 - باتنة": ["باتنة", "أريس", "بريكة", "مروانة", "ثنية العابد", "عين التوتة", "نقاوة", "المعذر", "تازولت"],
    "06 - بجاية": ["بجاية", "أميزور", "خراطة", "أقبو", "القصر", "صدوق", "تيشي", "إغزر أمقران"],
    "07 - بسكرة": ["بسكرة", "طولقة", "سيدي عقبة", "جمورة", "زريبة الوادي", "الوطاية", "فوغالة", "أولاد جلال"],
    "08 - بشار": ["بشار", "القنادسة", "تاغيت", "العبادلة", "بني ونيف", "لحمر", "موغل", "مريجة", "تبلبالة"],
    "09 - البليدة": ["البليدة", "بوفاريك", "العفرون", "بوقرة", "موزاية", "الأربعاء", "مفتاح", "أولاد يعيش"],
    "10 - البويرة": ["البويرة", "الأخضرية", "عين بسام", "سور الغزلان", "مشد الله", "قاديرية", "البشلول"],
    "11 - تمنراست": ["تمنراست", "أباليسا", "إدلس", "تاظروك", "عين أمغل", "إن غار", "إن صالح", "أراك"],
    "12 - تبسة": ["تبسة", "بئر العاتر", "الشريعة", "الونزة", "العوينات", "مرسط", "نقرين"],
    "13 - تلمسان": ["تلمسان", "مغنية", "سبدو", "الغزوات", "أولاد ميمون", "رمشي", "الحناية", "بني صاف"],
    "14 - تيارت": ["تيارت", "فرندة", "قصر الشلالة", "مهدية", "السوقر", "حمادية", "رحوية"],
    "15 - تيزي وزو": ["تيزي وزو", "عزازقة", "تيقزيرت", "ذراع بن خدة", "الأربعاء نات إيراثن", "ذراع الميزان", "واسيف"],
    "16 - الجزائر": ["الجزائر الوسطى", "سيدي امحمد", "المدنية", "بلوزداد", "باب الوادي", "بولوغين", "بوزريعة", "باش جراح", "الحراش", "الدار البيضاء", "الرويبة", "هراوة", "براقي", "بئر مراد رايس", "بئر خادم", "حي الجبل", "عين البنيان", "زرالدة", "سطاوالي", "الشراقة"],
    "17 - الجلفة": ["الجلفة", "حاسي بحبح", "عين وسارة", "مسعد", "الشارف", "الإدريسية", "حد الصحاري", "بيرين"],
    "18 - جيجل": ["جيجل", "جيجل", "الطاهير", "الميلية", "الزيامة منصورية", "السطارة", "العنصر", "جيملة"],
    "19 - سطيف": ["سطيف", "العلمة", "بوقاعة", "عين الكبيرة", "عين ولمان", "قجال", "بابور", "بني عزيز", "حمام السخنة"],
    "20 - سعيدة": ["سعيدة", "عين الحجر", "يوب", "الحساسنة", "سيدي بوبكر", "أولاد خالد"],
    "21 - سكيكدة": ["سكيكدة", "عزابة", "القل", "الحروش", "تمالوس", "رمضان جمال", "سيدي مزغيش"],
    "22 - سيدي بلعباس": ["سيدي بلعباس", "تلاغ", "سفيزف", "بن باديس", "مولاي سليسن", "تسالة", "مصطفى بن إبراهيم"],
    "23 - عنابة": ["عنابة", "الحجار", "برحال", "البوني", "شطايبي", "سيدي عمار"],
    "24 - قالمة": ["قالمة", "وادي الزناتي", "بوشقوف", "هيليوبوليس", "حمام الدباغ", "قلعة بوصبع"],
    "25 - قسنطينة": ["قسنطينة", "الخروب", "عين عبيد", "زيغود يوسف", "حامة بوزيان", "ابن زياد"],
    "26 - المدية": ["المدية", "البرواقية", "قصر البخاري", "بني سليمان", "تابلاط", "عزيز", "سي المحجوب"],
    "27 - مستغانم": ["مستغانم", "عين تادلس", "سيدي لخضر", "ماسرة", "بوقيرات", "حاسي ماماش"],
    "28 - المسيلة": ["المسيلة", "بوسعادة", "سيدي عيسى", "مقرة", "حمام الضلعة", "أولاد دراج", "شلال"],
    "29 - معسكر": ["معسكر", "سيق", "المحمدية", "تيغنيف", "غريس", "هاشم", "بوحنيفية"],
    "30 - ورقلة": ["ورقلة", "حاسي مسعود", "الرويسات", "عين البيضاء", "أنقوسة", "حاسي بن عبد الله", "سيدي خويلد"],
    "31 - وهران": ["وهران", "السانية", "أرزيو", "بطيوة", "قديل", "عين الترك", "بوتليليس", "بير الجير"],
    "32 - البيض": ["البيض", "بوقطب", "الأبيض سيدي الشيخ", "بريزينة", "الشلالة", "رقاصة", "بني ونيف"],
    "33 - إليزي": ["إليزي", "برج عمر إدريس", "دبداب", "إن أميناس"],
    "34 - برج بوعريريج": ["برج بوعريريج", "رأس الوادي", "بليمور", "منصورة", "مجانا", "الحمادية"],
    "35 - بومرداس": ["بومرداس", "بودواو", "دلس", "الثنية", "برج منايل", "خميس الخشنة", "يسر"],
    "36 - الطارف": ["الطارف", "القالة", "بوثلجة", "الذرعان", "بن مهيدي", "البسباس"],
    "37 - تندوف": ["تندوف", "أم العسل"],
    "38 - تسمسيلت": ["تسمسيلت", "ثنية الحد", "لرجام", "برج بونعامة", "خميستي"],
    "39 - الوادي": ["الوادي", "قمار", "الدبيلة", "الرقيبة", "حاسي خليفة", "كوينين", "المغير", "جامعة"],
    "40 - خنشلة": ["خنشلة", "قايس", "أولاد رشاش", "ششار", "الحامة", "بوحمامة"],
    "41 - سوق أهراس": ["سوق أهراس", "سدراتة", "مداوروش", "تاورة", "المشروحة", "لحدادة"],
    "42 - تيبازة": ["تيبازة", "شرشال", "القليعة", "حجوط", "بواسماعيل", "قوراية", "الداموس"],
    "43 - ميلة": ["ميلة", "شلغوم العيد", "فرجيوة", "تاجنانت", "تلاغمة", "وادي العثمانية"],
    "44 - عين الدفلى": ["عين الدفلى", "خميس مليانة", "مليانة", "العطاف", "العبادية", "جليدة"],
    "45 - النعامة": ["النعامة", "مشرية", "عين الصفراء", "عسلة", "صفيصيفة", "مكمن بن عمار"],
    "46 - عين تموشنت": ["عين تموشنت", "بني صاف", "حمام بوحجر", "العامرية", "المالح"],
    "47 - غرداية": ["غرداية", "القرارة", "متليلي", "بني يزقن", "ضاية بن ضحوة", "زلفانة", "بريان", "المنيعة"],
    "48 - غليزان": ["غليزان", "وادي ارهيو", "مازونة", "زمورة", "المطمر", "عمي موسى"],
    "49 - تيميمون": ["تيميمون", "أولاد سعيد", "قصر قدور", "شروين", "طلمين", "أوقروت", "دلدول", "المطارفة"],
    "50 - برج باجي مختار": ["برج باجي مختار", "تيمياوين"],
    "51 - أولاد جلال": ["أولاد جلال", "الدوسن", "سيدي خالد", "البسباس", "الشعيبة"],
    "52 - بني عباس": ["بني عباس", "إيغلي", "الواتة", "كرزاز", "تلمين", "القصابي"],
    "53 - عين صالح": ["عين صالح", "إيغوستن", "إن غار", "فقارة الزواية"],
    "54 - عين قزام": ["عين قزام", "تين زواتين"],
    "55 - تقرت": ["تقرت", "النزلة", "تبسبست", "تماسين", "المقارين", "الطيبات", "بن ناصر", "العالية"],
    "56 - جانت": ["جانت", "برج الحواس"],
    "57 - المغير": ["المغير", "جامعة", "أم الطيور", "تندلة"],
    "58 - المنيعة": ["المنيعة", "حاسي القارة"],
  };

  static List<String> getCommunesForWilaya(String wilaya) {
    return wilayaCommunes[wilaya] ?? ["مركز الولاية"];
  }

  static const List<String> defaultServiceTypes = [
    "نقل الجنائز", "تغسيل الموتى", "مساعدات غذائية", "مساعدات مالية", "مساعدة طبية", "تعليم وكفالة أيتام", "بناء وتعمير"
  ];

  static String translateServiceType(String type) {
    if (type.isEmpty) return 'خدمة / مهمة';
    String t = type.toLowerCase().trim().replaceAll('_', ' ');
    
    final Map<String, String> translations = {
      'patient transport': 'نقل المرضى',
      'funeral transport': 'نقل الجنائز',
      'school bags': 'الحقيبة المدرسية',
      'blood donation': 'تبرع بالدم',
      'medical equipment': 'توفير معدات طبية',
      'medical aid': 'الرعاية الطبية',
      'food distribution': 'إطعام الطعام',
      'food aid': 'إطعام الطعام',
      'seasonal aid': 'مساعدات موسمية',
      'orphan care': 'كفالة أيتام',
      'water well': 'حفر الآبار',
      'financial aid': 'تفريج كربة (مالي)',
      'construction': 'ترميم بيوت الله والفقراء',
      'education': 'تعليم وكفالة طالب',
      'emergency': 'حالة طارئة',
      'water_supply': 'سقي الماء',
      'water supply': 'سقي الماء',
      'orphans_care': 'كفالة أيتام',
      'orphans care': 'كفالة أيتام',
      'other': 'أخرى',
    };

    return translations[t] ?? type;
  }

  static double getScreenPaddingValue(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 150.0;
    if (width > 800) return 60.0;
    return 20.0;
  }

  static EdgeInsets getScreenPadding(BuildContext context) {
    return EdgeInsets.symmetric(horizontal: getScreenPaddingValue(context));
  }

  static IconData getServiceIcon(String type) {
    String t = type.toLowerCase().trim().replaceAll('_', ' ');
    
    if (t == 'نقل الجنازات' || t == 'نقل الجنائز' || t == ' funeral transport') {
      return Icons.airport_shuttle_rounded;
    }
    if (t == 'تغسيل الموتى' || t == 'funeral ghusl' || t == 'ghusl') {
      return Icons.waves_rounded;
    }
    if (t == 'مساعدات غذائية' || t == 'إطعام الطعام' || t == 'food aid' || t == 'food distribution') {
      return Icons.shopping_basket_rounded;
    }
    if (t == 'مساعدة طبية' || t == 'الرعاية الطبية' || t == 'medical aid' || t == 'medical equipment' || t == 'patient transport' || t == 'نقل المرضى') {
      return Icons.medical_services_rounded;
    }
    if (t == 'مساعدات مالية' || t == 'financial aid' || t == 'money' || t == 'تفريج كربة (مالي)') {
      return Icons.payments_rounded;
    }
    if (t == 'بناء وتعمير' || t == 'ترميم بيوت الله والفقراء' || t == 'construction' || t == 'housing') {
      return Icons.home_work_rounded;
    }
    if (t == 'تعليم وكفالة أيتام' || t == 'تعليم وكفالة طالب' || t == 'education' || t == 'school bags' || t == 'الحقيبة المدرسية') {
      return Icons.menu_book_rounded;
    }
    if (t == 'تبرع بالدم' || t == 'blood donation') {
      return Icons.bloodtype_rounded;
    }
    if (t == 'سقي الماء' || t == 'حفر الآبار' || t == 'water supply' || t == 'water well') {
      return Icons.water_drop_rounded;
    }
    if (t == 'كفالة أيتام' || t == 'orphan care') {
      return Icons.child_care_rounded;
    }
    if (t == 'حالة طارئة' || t == 'emergency') {
      return Icons.emergency_rounded;
    }

    return Icons.volunteer_activism_rounded;
  }

  static IconData getIconFromName(String iconName) {
    switch (iconName) {
      case 'mosque': return Icons.mosque;
      case 'shopping_basket': return Icons.shopping_basket;
      case 'medication': return Icons.medication;
      case 'payments': return Icons.payments;
      case 'home_work': return Icons.home_work;
      case 'menu_book': return Icons.menu_book;
      case 'school': return Icons.school;
      case 'water_drop': return Icons.water_drop;
      case 'volunteer_activism': return Icons.volunteer_activism;
      case 'checkroom': return Icons.checkroom;
      case 'inventory': return Icons.inventory;
      case 'emergency': return Icons.emergency_outlined;
      case 'ac_unit': return Icons.ac_unit;
      case 'nightlight_round': return Icons.nightlight_round;
      case 'bloodtype': return Icons.bloodtype;
      case 'more_horiz': return Icons.more_horiz;
      // Fallbacks
      case 'medical': return Icons.medical_services_outlined;
      case 'food': return Icons.restaurant;
      case 'transport': return Icons.local_shipping_outlined;
      case 'blood': return Icons.bloodtype_outlined;
      case 'funeral': return Icons.airport_shuttle;
      case 'funeral_ghusl': return Icons.waves_rounded;
      case 'ghusl': return Icons.waves_rounded;
      case 'money': return Icons.account_balance_wallet_outlined;
      case 'construction': return Icons.foundation_rounded;
      case 'housing': return Icons.home_repair_service_rounded;
      case 'other': return Icons.more_horiz;
      default: return Icons.category_outlined;
    }
  }

  static const String usersCollection = "users";
  static const String projectsCollection = "projects";
  static const String donationsCollection = "donations";
  static const String serviceRequestsCollection = "service_requests";
  static const String vehiclesCollection = "vehicles";
  static const String chatCollection = "chats";
  static const String serviceTypesCollection = "service_types";
  static const String taskTypesCollection = "task_types";

  static String translateStatus(String status) {
    switch (status.toLowerCase().trim()) {
      case 'pending': return 'قيد الانتظار';
      case 'in_progress': return 'قيد التنفيذ';
      case 'completed': return 'مكتمل';
      case 'rejected': return 'مرفوض';
      case 'approved': return 'مقبول';
      case 'archived': return 'مؤرشف';
      default: return status;
    }
  }

  static const List<Map<String, dynamic>> projectCategories = [
    {'id': 'construction', 'name': 'البناء والترميم', 'icon': Icons.construction, 'color': Color(0xFF5D4037)},
    {'id': 'orphan', 'name': 'كفالة الأيتام والتعليم', 'icon': Icons.child_care, 'color': Color(0xFF1565C0)},
    {'id': 'food', 'name': 'إطعام الطعام والطرود', 'icon': Icons.shopping_basket, 'color': Color(0xFF85C69B)},
    {'id': 'water', 'name': 'سقي الماء وحفر الآبار', 'icon': Icons.water_drop, 'color': Color(0xFF0277BD)},
    {'id': 'medical', 'name': 'مداواة المرضى والإسعاف', 'icon': Icons.healing, 'color': Color(0xFFC62828)},
    {'id': 'housing', 'name': 'تفريج كرب الأسر والبيوت', 'icon': Icons.home, 'color': Color(0xFF795548)},
    {'id': 'funeral', 'name': 'نقل الجنائز (إكرام الموتى)', 'icon': Icons.airport_shuttle, 'color': Color(0xFF4527A0)},
    {'id': 'zakat', 'name': 'زكاة المال والصدقات', 'icon': Icons.savings, 'color': Color(0xFFD4AF37)},
    {'id': 'general', 'name': 'أبواب الخير العامة', 'icon': Icons.volunteer_activism, 'color': Color(0xFF546E7A)},
  ];
}

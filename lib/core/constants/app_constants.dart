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
    "01 - أدرار": ["أدرار", "تامست", "تمنطيط", "فنوغيل", "إن زجمير", "رقان", "سالي", "أولاد أحمد تيمي", "بودا"],
    "03 - الأغواط": ["الأغواط", "أفلو", "عين ماضي", "حاسي الرمل", "قصر الحيران"],
    "07 - بسكرة": ["بسكرة", "طولقة", "سيدي عقبة", "جمورة", "زريبة الوادي"],
    "08 - بشار": ["بشار", "القنادسة", "تاغيت", "العبادلة", "بني ونيف", "لحمر"],
    "11 - تمنراست": ["تمنراست", "أباليسا", "إدلس", "تاظروك", "عين أمغل"],
    "17 - الجلفة": ["الجلفة", "حاسي بحبح", "عين وسارة", "مسعد", "الشارف"],
    "30 - ورقلة": ["ورقلة", "حاسي مسعود", "الرويسات", "عين البيضاء", "أنقوسة"],
    "32 - البيض": ["البيض", "بوقطب", "الأبيض سيدي الشيخ", "بريزينة", "الشلالة"],
    "33 - إليزي": ["إليزي", "برج عمر إدريس", "دبداب"],
    "37 - تندوف": ["تندوف", "أم العسل"],
    "39 - الوادي": ["الوادي", "قمار", "الدبيلة", "الرقيبة", "حاسي خليفة"],
    "45 - النعامة": ["النعامة", "مشرية", "عين الصفراء", "عسلة", "صفيصيفة"],
    "47 - غرداية": ["غرداية", "القرارة", "متليلي", "بني يزقن", "ضاية بن ضحوة", "زلفانة"],
    "49 - تيميمون": ["تيميمون", "أولاد سعيد", "قصر قدور", "شروين", "طلمين", "أوقروت"],
    "50 - برج باجي مختار": ["برج باجي مختار", "تيمياوين"],
    "51 - أولاد جلال": ["أولاد جلال", "الدوسن", "سيدي خالد"],
    "52 - بني عباس": ["بني عباس", "إيغلي", "الواتة", "كرزاز", "تلمين"],
    "53 - عين صالح": ["عين صالح", "إيغوستن", "إن غار"],
    "54 - عين قزام": ["عين قزام", "تين زواتين"],
    "55 - تقرت": ["تقرت", "النزلة", "تبسبست", "تماسين", "المقارين", "الطيبات"],
    "56 - جانت": ["جانت", "برج الحواس"],
    "57 - المغير": ["المغير", "جامعة", "أم الطيور", "تندلة"],
    "58 - المنيعة": ["المنيعة", "حاسي القارة"],
  };

  static List<String> getCommunesForWilaya(String wilaya) {
    return wilayaCommunes[wilaya] ?? ["مركز الولاية"];
  }

  static const List<String> defaultServiceTypes = [
    "نقل الجنازات", "مساعدات غذائية", "مساعدات مالية", "مساعدة طبية", "تعليم وكفالة أيتام", "بناء وتعمير"
  ];

  static String translateServiceType(String type) {
    if (type.isEmpty) return 'خدمة / مهمة';
    String t = type.toLowerCase().trim().replaceAll('_', ' ');
    
    final Map<String, String> translations = {
      'patient transport': 'نقل المرضى',
      'funeral transport': 'إكرام الموتى',
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
    
    if (t == 'نقل الجنازات' || t == 'إكرام الموتى' || t == 'funeral transport') {
      return Icons.airport_shuttle_rounded;
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
      case 'money': return Icons.account_balance_wallet_outlined;
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
    {'id': 'funeral', 'name': 'إكرام الموتى (نقل الجنائز)', 'icon': Icons.airport_shuttle, 'color': Color(0xFF4527A0)},
    {'id': 'zakat', 'name': 'زكاة المال والصدقات', 'icon': Icons.savings, 'color': Color(0xFFD4AF37)},
    {'id': 'general', 'name': 'أبواب الخير العامة', 'icon': Icons.volunteer_activism, 'color': Color(0xFF546E7A)},
  ];
}

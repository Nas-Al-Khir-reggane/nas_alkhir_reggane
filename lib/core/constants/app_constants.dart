import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppConstants {
  static const String appName = "جمعية ناس الخير رقان";

  // للتبديل بين الوضعين يدوياً بشكل صحيح
  static void toggleTheme() {
    if (Get.isDarkMode) {
      Get.changeThemeMode(ThemeMode.light);
    } else {
      Get.changeThemeMode(ThemeMode.dark);
    }
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

  static const List<String> defaultServiceTypes = [
    "نقل الجنازات",
    "مساعدات غذائية",
    "مساعدات مالية",
    "مساعدة طبية",
    "تعليم وكفالة أيتام",
    "بناء وتعمير"
  ];

  static const List<String> defaultTaskTypes = [
    "توصيل أمانة",
    "زيارة ميدانية",
    "شراء مستلزمات",
    "نقل مرضى",
    "تنظيم فعاليات"
  ];

  // Firestore Collections
  static const String usersCollection = "users";
  static const String projectsCollection = "projects";
  static const String donationsCollection = "donations";
  static const String serviceRequestsCollection = "service_requests";
  static const String vehiclesCollection = "vehicles";
  static const String chatCollection = "chats";
  static const String serviceTypesCollection = "service_types";
  static const String taskTypesCollection = "task_types";
}

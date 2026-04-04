import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nas_al_kheir/core/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App shell renders with initialized ThemeService', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await ThemeService().init();

    await tester.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(
          body: Center(child: Text('NAS_APP_READY')),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(GetMaterialApp), findsOneWidget);
    expect(find.text('NAS_APP_READY'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:agency_head/core/routes/app_router.dart';
import 'package:agency_head/core/theme/app_theme.dart';

void main() {
  runApp(const AgencyHeadApp());
}

class AgencyHeadApp extends StatelessWidget {
  const AgencyHeadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Student Agency Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
    );
  }
}

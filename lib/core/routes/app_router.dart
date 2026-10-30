import 'package:agency_head/features/leads/lead_details_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:agency_head/features/navigation/main_wrapper.dart';
import 'package:agency_head/features/splash/splash_screen.dart';
import 'package:agency_head/features/auth/login_screen.dart';
import 'package:agency_head/features/profile/profile_screen.dart';
import 'package:agency_head/features/leads/create_lead_screen.dart';
import 'package:agency_head/features/sheets/sheets_list_screen.dart';
import 'package:agency_head/features/sheets/spreadsheet_screen.dart';
import 'package:agency_head/features/sheets/create_sheet_screen.dart';
import 'package:agency_head/features/executives/executive_list_screen.dart';
import 'package:agency_head/features/executives/executive_details_screen.dart';
import 'package:agency_head/features/executives/create_executive_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/create-sheet',
        builder: (context, state) => const CreateSheetScreen(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainWrapper(child: child);
        },
        routes: [
          GoRoute(
            path: '/sheets',
            builder: (context, state) => const SheetsListScreen(),
          ),
          GoRoute(
            path: '/executives',
            builder: (context, state) => const ExecutiveListScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/sheet/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return SpreadsheetScreen(sheetId: id);
        },
      ),
      GoRoute(
        path: '/sheet/:sheetId/lead/:leadId',
        builder: (context, state) {
          final sheetId = state.pathParameters['sheetId']!;
          final leadId = state.pathParameters['leadId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return LeadDetailsScreen(
            leadId: leadId,
            sheetId: sheetId,
            initialRow: extra?['row'],
            sheet: extra?['sheet'],
            userRole: extra?['userRole'],
            initialEditMode: extra?['editMode'] == true,
          );
        },
      ),
      GoRoute(
        path: '/create-lead',
        builder: (context, state) => const CreateLeadScreen(),
      ),
      GoRoute(
        path: '/lead-details/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>?;
          return LeadDetailsScreen(
            leadId: id,
            sheetId: extra?['sheetId']?.toString() ?? '',
            initialRow: extra?['row'],
            sheet: extra?['sheet'],
            userRole: extra?['userRole'],
            initialEditMode: extra?['editMode'] == true,
          );
        },
      ),
      GoRoute(
        path: '/executive-details/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ExecutiveDetailsScreen(executiveId: id);
        },
      ),
      GoRoute(
        path: '/create-executive',
        builder: (context, state) => const CreateExecutiveScreen(),
      ),
      GoRoute(
        path: '/edit-lead/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CreateLeadScreen(leadId: id);
        },
      ),
    ],
  );
}

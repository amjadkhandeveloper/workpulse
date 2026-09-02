import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/companies/companies_screen.dart';
import '../../features/admin/companies/company_form_screen.dart';
import '../../features/admin/dashboard/admin_dashboard_screen.dart';
import '../../features/admin/jobs/admin_jobs_screen.dart';
import '../../features/admin/jobs/job_form_screen.dart';
import '../../features/admin/jobs/job_review_screen.dart';
import '../../features/admin/leaves/admin_leaves_screen.dart';
import '../../features/admin/map/live_map_screen.dart';
import '../../features/admin/reports/reports_screen.dart';
import '../../features/admin/shell/admin_shell.dart';
import '../../features/admin/users/user_form_screen.dart';
import '../../features/admin/users/users_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/intro/intro_screen.dart';
import '../../features/setup/setup_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/user/attendance/attendance_screen.dart';
import '../../features/user/dashboard/user_dashboard_screen.dart';
import '../../features/user/jobs/checkout_screen.dart';
import '../../features/user/jobs/job_details_screen.dart';
import '../../features/user/leaves/apply_leave_screen.dart';
import '../../features/user/leaves/user_leaves_screen.dart';
import '../../features/user/shell/user_shell.dart';
import '../providers.dart';

final _refresh = ValueNotifier<int>(0);

final routerProvider = Provider<GoRouter>((ref) {
  ref.listen(sessionControllerProvider, (_, _) => _refresh.value++);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _refresh,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final loc = state.matchedLocation;
      switch (session.status) {
        case SessionStatus.loading:
          return loc == '/splash' ? null : '/splash';
        case SessionStatus.misconfigured:
          return loc == '/setup' ? null : '/setup';
        case SessionStatus.needsIntro:
          return loc == '/intro' ? null : '/intro';
        case SessionStatus.unauthenticated:
          return loc == '/login' ? null : '/login';
        case SessionStatus.authenticated:
          final isAdmin = session.isAdmin;
          final goingAuth = loc == '/login' || loc == '/intro' || loc == '/splash' || loc == '/setup';
          if (goingAuth) return isAdmin ? '/admin' : '/user';
          if (isAdmin && loc.startsWith('/user')) return '/admin';
          if (!isAdmin && loc.startsWith('/admin')) return '/user';
          return null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/setup', builder: (_, _) => const SetupScreen()),
      GoRoute(path: '/intro', builder: (_, _) => const IntroScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: '/admin', builder: (_, _) => const AdminDashboardScreen()),
          GoRoute(path: '/admin/users', builder: (_, _) => const UsersScreen()),
          GoRoute(path: '/admin/users/new', builder: (_, _) => const UserFormScreen()),
          GoRoute(
            path: '/admin/users/:id',
            builder: (_, state) => UserFormScreen(userId: state.pathParameters['id']),
          ),
          GoRoute(path: '/admin/companies', builder: (_, _) => const CompaniesScreen()),
          GoRoute(path: '/admin/companies/new', builder: (_, _) => const CompanyFormScreen()),
          GoRoute(
            path: '/admin/companies/:id',
            builder: (_, state) => CompanyFormScreen(companyId: state.pathParameters['id']),
          ),
          GoRoute(path: '/admin/jobs', builder: (_, _) => const AdminJobsScreen()),
          GoRoute(path: '/admin/jobs/new', builder: (_, _) => const JobFormScreen()),
          GoRoute(
            path: '/admin/jobs/:id',
            builder: (_, state) => JobFormScreen(jobId: state.pathParameters['id']),
          ),
          GoRoute(
            path: '/admin/jobs/:id/review',
            builder: (_, state) => JobReviewScreen(jobId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/admin/leaves', builder: (_, _) => const AdminLeavesScreen()),
          GoRoute(path: '/admin/reports', builder: (_, _) => const ReportsScreen()),
          GoRoute(path: '/admin/map', builder: (_, _) => const LiveMapScreen()),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => UserShell(child: child),
        routes: [
          GoRoute(path: '/user', builder: (_, _) => const UserDashboardScreen()),
          GoRoute(
            path: '/user/jobs/:id',
            builder: (_, state) => JobDetailsScreen(jobId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/user/jobs/:id/checkout',
            builder: (_, state) => CheckoutScreen(jobId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/user/attendance', builder: (_, _) => const AttendanceScreen()),
          GoRoute(path: '/user/leaves', builder: (_, _) => const UserLeavesScreen()),
          GoRoute(path: '/user/leaves/apply', builder: (_, _) => const ApplyLeaveScreen()),
        ],
      ),
    ],
  );
});

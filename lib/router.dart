import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/welcome_screen.dart';
import 'screens/job_type_screen.dart';
import 'screens/register_screen.dart';
import 'screens/access_screen.dart';
import 'screens/home_screen.dart';
import 'screens/job_detail_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/applications_screen.dart';
import 'screens/application_detail_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/message_detail_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_results_screen.dart';
import 'screens/session_bootstrap_screen.dart';
import 'screens/cv_builder_screen.dart';

final router = GoRouter(
  initialLocation: '/bootstrap',
  routes: [
    GoRoute(
      path: '/bootstrap',
      builder: (context, state) => const SessionBootstrapScreen(),
    ),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/onboarding/job-type',
      builder: (context, state) => const JobTypeScreen(),
    ),
    GoRoute(
      path: '/auth/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/auth/access',
      builder: (context, state) => const AccessScreen(),
    ),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/jobs/:id',
      builder: (context, state) =>
          JobDetailScreen(jobId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/jobs/search',
      builder: (context, state) {
        final query = state.uri.queryParameters['q'] ?? '';
        return SearchResultsScreen(query: query);
      },
    ),
    GoRoute(
      path: '/documents',
      builder: (context, state) => const DocumentsScreen(),
    ),
    GoRoute(
      path: '/documents/cv-builder',
      builder: (context, state) => const CvBuilderScreen(),
    ),
    GoRoute(
      path: '/applications',
      builder: (context, state) => const ApplicationsScreen(),
    ),
    GoRoute(
      path: '/applications/:id',
      builder: (context, state) =>
          ApplicationDetailScreen(applicationId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/messages',
      builder: (context, state) => const MessagesScreen(),
    ),
    GoRoute(
      path: '/messages/:id',
      builder: (context, state) =>
          MessageDetailScreen(messageId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
  ],
  errorBuilder: (context, state) =>
      Scaffold(body: Center(child: Text('Página no encontrada: ${state.uri}'))),
);

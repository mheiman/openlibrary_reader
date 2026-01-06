import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

import '../../features/authentication/presentation/pages/login_page.dart';
import '../../features/authentication/presentation/state/auth_notifier.dart';
import '../../features/authentication/presentation/state/auth_state.dart';
import '../../features/help/presentation/pages/help_page.dart';
import '../../features/reader/presentation/pages/reader_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/shelves/presentation/pages/shelves_page.dart';
import '../di/injection.dart';
import 'app_routes.dart';

@lazySingleton
class AppRouter {
  late final GoRouter router;

  AppRouter() {
    final authNotifier = getIt<AuthNotifier>();

    router = GoRouter(
      initialLocation: AppRoutes.root,
      debugLogDiagnostics: true,
      refreshListenable: authNotifier, // Re-evaluate redirect when auth state changes
      redirect: (context, state) {
        final authState = authNotifier.state;
        final isLoginPage = state.matchedLocation == AppRoutes.login;

        // If unauthenticated and not already on login page, redirect to login
        if (authState is Unauthenticated && !isLoginPage) {
          return AppRoutes.login;
        }

        // If authenticated and on login page, redirect to home
        if (authState is Authenticated && isLoginPage) {
          return AppRoutes.root;
        }

        return null; // No redirect needed
      },
      routes: [
        // Root/Splash
        GoRoute(
          path: AppRoutes.root,
          name: 'root',
          builder: (context, state) => const ShelvesPage(),
        ),

        GoRoute(
          path: AppRoutes.splash,
          name: 'splash',
          builder: (context, state) => const _PlaceholderPage(title: 'Splash'),
        ),

        // Authentication
        GoRoute(
          path: AppRoutes.login,
          name: 'login',
          builder: (context, state) => const LoginPage(),
        ),

        // Main Features
        GoRoute(
          path: AppRoutes.home,
          name: 'home',
          builder: (context, state) => const ShelvesPage(),
        ),

        GoRoute(
          path: AppRoutes.shelves,
          name: 'shelves',
          builder: (context, state) => const ShelvesPage(),
        ),

        GoRoute(
          path: AppRoutes.search,
          name: 'search',
          builder: (context, state) => const SearchPage(),
        ),

        GoRoute(
          path: AppRoutes.settings,
          name: 'settings',
          builder: (context, state) =>
              const _PlaceholderPage(title: 'Settings'),
        ),

        // Reader
        GoRoute(
          path: AppRoutes.reader,
          name: 'reader',
          builder: (context, state) {
            final bookId = state.pathParameters['bookId'] ?? '';
            final title = state.uri.queryParameters['title'];
            final workId = state.uri.queryParameters['workId'];
            final coverImageIdStr = state.uri.queryParameters['coverImageId'];
            final coverImageId = coverImageIdStr != null && coverImageIdStr.isNotEmpty
                ? int.tryParse(coverImageIdStr)
                : null;
            final coverEditionId = state.uri.queryParameters['coverEditionId'];

            return ReaderPage(
              bookId: bookId,
              title: title,
              workId: workId,
              coverImageId: coverImageId,
              coverEditionId: coverEditionId,
            );
          },
        ),

        // Help & About
        GoRoute(
          path: AppRoutes.help,
          name: 'help',
          builder: (context, state) => const HelpPage(),
        ),

        GoRoute(
          path: AppRoutes.about,
          name: 'about',
          builder: (context, state) => const _PlaceholderPage(title: 'About'),
        ),

        // Error
        GoRoute(
          path: AppRoutes.error,
          name: 'error',
          builder: (context, state) => const _PlaceholderPage(title: 'Error'),
        ),
      ],
      errorBuilder: (context, state) => _PlaceholderPage(
        title: 'Error: ${state.error}',
      ),
    );
  }
}

/// Placeholder page for routes that haven't been implemented yet
class _PlaceholderPage extends StatelessWidget {
  final String title;

  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 64,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'This page is under construction',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.root);
                }
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

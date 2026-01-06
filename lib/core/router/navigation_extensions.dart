import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';

/// Extension methods for easy navigation
extension NavigationExtensions on BuildContext {
  // Authentication
  void goToLogin() => go(AppRoutes.login);
  void goToLogout() => go(AppRoutes.logout);

  // Main features
  void goToHome() => go(AppRoutes.home);
  void goToShelves() => go(AppRoutes.shelves);
  void goToSearch({String? query, String? filter}) {
    if (query != null || filter != null) {
      final queryParams = <String, String>{};
      if (query != null) queryParams['query'] = query;
      if (filter != null) queryParams['filter'] = filter;
      go(Uri(path: AppRoutes.search, queryParameters: queryParams).toString());
    } else {
      go(AppRoutes.search);
    }
  }
  void pushToSearch({String? query, String? filter}) {
    if (query != null || filter != null) {
      final queryParams = <String, String>{};
      if (query != null) queryParams['query'] = query;
      if (filter != null) queryParams['filter'] = filter;
      push(Uri(path: AppRoutes.search, queryParameters: queryParams).toString());
    } else {
      push(AppRoutes.search);
    }
  }
  void goToSettings() => go(AppRoutes.settings);

  // Reader
  void goToReader(String bookId) => go(AppRoutes.readerPath(bookId));
  void pushReader(String bookId) => push(AppRoutes.readerPath(bookId));

  // Help & About
  void goToHelp() => go(AppRoutes.help);
  void goToAbout() => go(AppRoutes.about);

  // Navigation actions
  void goBack() => pop();
  bool get canGoBack => canPop();
}

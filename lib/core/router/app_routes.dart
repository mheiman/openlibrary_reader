/// Route names for the application
class AppRoutes {
  // Root
  static const String root = '/';
  static const String splash = '/splash';

  // Authentication
  static const String login = '/login';
  static const String logout = '/logout';
  static const String oauthCallback = '/oauth2/callback';

  // Main features
  static const String home = '/home';
  static const String shelves = '/shelves';
  static const String search = '/search';
  static const String settings = '/settings';

  // Reader
  static const String reader = '/reader/:bookId';
  static String readerPath(String bookId) => '/reader/$bookId';

  // Help
  static const String help = '/help';
  static const String about = '/about';

  // Error
  static const String error = '/error';
}

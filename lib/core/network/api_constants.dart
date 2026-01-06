class ApiConstants {
  // Base URLs
//  static const String openLibraryBaseUrl = 'https://openlibrary.org';
  static const String archiveOrgBaseUrl = 'https://archive.org';
  static const String openLibraryBaseUrl = 'http://localhost:8080';


  // Open Library Endpoints
  static const String searchEndpoint = '/search.json';
  static const String worksEndpoint = '/works';
  static const String booksEndpoint = '/books';
  static const String editionsEndpoint = '/editions.json';
  static const String accountEndpoint = '/account';
  static const String loanEndpoint = '/account/loan';

  // Internet Archive Endpoints
  static const String metadataEndpoint = '/metadata';
  static const String loanServiceEndpoint = '/services/loans/loan';
  static const String streamEndpoint = '/stream';

  // Authentication
  static const String loginPath = '/account/login';
  
  // OAuth2
  static const String oauthAuthorizePath = '/oauth2/authorize';
  static const String oauthTokenPath = '/oauth2/token';
  static const String oauthUserInfoPath = '/oauth2/userinfo';
  static const String oauthTokenToCookiePath = '/oauth2/token-to-cookie';
  
  // OAuth2 Configuration
  static const String oauthClientId = 'mobile_app';
  static const String oauthRedirectUri = 'https://olreader.github.io/docs/oauth-redirect.html';
  static const String oauthScope = 'openid profile email';
  
  // OAuth2 Debug/Testing Configuration
  static const bool oauthUseMinimalParameters = true; // Set to false to use all parameters
  static const String oauthRedirectUriEncoding = 'encoded'; // 'minimal', 'partial', 'encoded', 'raw', or 'http'

  // Headers
  static const String contentTypeJson = 'application/json';
  static const String acceptJson = 'application/json';

  // Timeouts (in milliseconds)
  static const int connectionTimeout = 30000;
  static const int receiveTimeout = 30000;

  // Cache
  static const int cacheValidityHours = 6;

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxBatchSize = 50;

  // File names
  static const String bookDataFileName = 'bookData.json';
  static const String shelfDataFileName = 'shelfData.json';

  // Shared Preferences Keys
  static const String prefMoveToReading = 'moveReading';
  static const String prefShowChrome = 'showChrome';
  static const String prefKeepAwake = 'keepAwake';
  static const String prefCoverSize = 'coverSize';
  static const String prefSortOrder = 'sortOrder';
  static const String prefShelfVisibility = 'shelfVisibility';
  static const String prefSearchSortOrder = 'searchSortOrder';
  static const String prefSearchSortAscending = 'searchSortAscending';
  static const String prefShowLists = 'showLists';
  static const String prefSelectedList = 'selectedList';
}

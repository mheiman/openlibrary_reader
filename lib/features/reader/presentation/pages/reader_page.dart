import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/navigation_extensions.dart';
import '../../../authentication/data/datasources/auth_remote_data_source.dart';
import '../../../settings/presentation/state/settings_notifier.dart';
import '../../../settings/presentation/state/settings_state.dart';
import '../state/reader_notifier.dart';
import '../state/reader_state.dart';

/// Full-screen reader page
class ReaderPage extends StatefulWidget {
  final String bookId;
  final String? workId;
  final String? title;
  final int? coverImageId;
  final String? coverEditionId;

  const ReaderPage({
    super.key,
    required this.bookId,
    this.workId,
    this.title,
    this.coverImageId,
    this.coverEditionId,
  });

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> with WidgetsBindingObserver {
  late final ReaderNotifier _notifier;
  late final AuthRemoteDataSource _authDataSource;
  late final SettingsNotifier _settingsNotifier;
  InAppWebViewController? _webViewController;

  bool _isLoading = true;
  double _progress = 0;
  String _loadMessage = 'Loading your book...';
  int _loginRedirectCount = 0;
  DateTime? _lastToggleNavTime;

  /// Mirrors the JS nav state; JS is authoritative.
  bool _fullScreen = false;

  late OverlayEntry _overlayEntry;
  bool _overlayInserted = false;

  /// Timer to track if loading takes too long
  Timer? _loadingTimeoutTimer;

  /// Track which domain is currently causing delays
  String _currentLoadingDomain = 'openlibrary.org';

  /// Track if loan expired dialog is currently showing
  bool _isLoanExpiredDialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notifier = getIt<ReaderNotifier>();
    _authDataSource = getIt<AuthRemoteDataSource>();
    _settingsNotifier = getIt<SettingsNotifier>();
    _overlayEntry = _createOverlayEntry();

    // Load settings if not already loaded
    if (_settingsNotifier.state is! SettingsLoaded) {
      _settingsNotifier.loadSettings();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Overlay.of(context).insert(_overlayEntry);
      _overlayInserted = true;
    });

    _notifier.initializeReader(
      bookId: widget.bookId,
      workId: widget.workId ?? widget.bookId,
      title: widget.title ?? 'Reading',
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _loadingTimeoutTimer?.cancel();

    if (_overlayInserted) {
      _overlayEntry.remove();
    }

    _webViewController?.dispose();

    WakelockPlus.disable();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('Reader lifecycle state: $state');

    if (state == AppLifecycleState.resumed) {
      // App is visible and running - check if loan token is still valid
      _checkLoanValidity();

      // Restore fullscreen mode if needed
      if (_fullScreen) {
        final settingsState = _settingsNotifier.state;
        if (settingsState is SettingsLoaded && !settingsState.settings.showChrome) {
          SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.manual,
            overlays: [],
          );
        }
      }
    }
  }

  Future<void> _checkLoanValidity() async {
    if (_webViewController == null || !mounted) return;

    try {
      // Check if the loan token is still valid
      final hasValidToken = await _webViewController!.evaluateJavascript(
        source: 'searchInside.hasValidLoanToken();',
      );

      debugPrint('Loan token validity: $hasValidToken');

      if (hasValidToken == false && mounted) {
        // Loan has expired - exit fullscreen
        if (_fullScreen) {
          _setFullScreenFromJs(false);
        }

        _showLoanExpiredDialog();
      }
    } catch (e) {
      debugPrint('Error checking loan validity: $e');
      // If we can't check, assume it's still valid and continue
    }
  }

  void _showLoanExpiredDialog() {
    if (!mounted || _isLoanExpiredDialogShowing) return;

    _isLoanExpiredDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Still reading ${widget.title ?? 'this book'}?'),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              _isLoanExpiredDialogShowing = false;
              // Reload the book to get a fresh checkout
              await _reloadReader();
            },
            child: const Text('Keep Reading'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _isLoanExpiredDialogShowing = false;
              // Return to previous screen
              context.goBack();
            },
            child: const Text('Close Book'),
          ),
        ],
      ),
    );
  }

  void _startLoadingTimeout() {
    // Cancel any existing timer
    _loadingTimeoutTimer?.cancel();

    // Start a new 1-minute timeout
    _loadingTimeoutTimer = Timer(const Duration(minutes: 1), () {
      if (mounted && _isLoading) {
        _showLoadingTimeoutDialog();
      }
    });
  }

  void _cancelLoadingTimeout() {
    _loadingTimeoutTimer?.cancel();
    _loadingTimeoutTimer = null;
  }

  void _showLoadingTimeoutDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Slow Response'),
        content: Text(
          '$_currentLoadingDomain is taking a long time to respond.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Restart the timeout timer to give it another minute
              _startLoadingTimeout();
            },
            child: const Text('Keep Trying'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Cancel loading and go back
              _cancelLoadingTimeout();
              context.goBack();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestToggleNav() async {
    // The screen top GestureDetector inexplicably calls this method twice for
    // every tap. I've done everything I can to troubleshoot, so for now we're
    // just going to ignore the second call
    final now = DateTime.now();
    if (_lastToggleNavTime != null &&
        now.difference(_lastToggleNavTime!) < const Duration(seconds: 2)) {
      return;
    }
    _lastToggleNavTime = now;

    await _webViewController?.evaluateJavascript(
      source: 'toggleNav();',
    );
    debugPrintStack(label: '_requestToggleNav()');
    debugPrint('hash: $hashCode');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _fullScreen
          ? null
          : AppBar(
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                color: Theme.of(context).colorScheme.onPrimary,
                tooltip: 'Back',
                onPressed: () => context.goBack(),
              ),
              title: Text(
                widget.title ?? 'Reader',
                style: TextStyle(color: Theme.of(context).colorScheme.onPrimary,),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.autorenew_rounded),
                  color: Theme.of(context).colorScheme.onPrimary,
                  tooltip: 'Reload',
                  onPressed: _reloadReader,
                ),
              ],
            ),
      body: ListenableBuilder(
            listenable: _notifier,
            builder: (context, _) {
              final state = _notifier.state;

              if (state is ReaderLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              } else if (state is ReaderError) {
                return _buildError(state.message);
              } else if (state is ReaderReady) {
                return _buildReader(state);
              }

              return const SizedBox();
            },
          ),
    );
  }

  Widget _buildReader(ReaderReady state) {
    final config = state.config;

    if (config.keepAwake) {
      WakelockPlus.enable();
    }

    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(state.readerUrl),
            headers: {
              'Cookie': _authDataSource.cookieHeader ?? '',
            },
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true,
            databaseEnabled: true,
            allowFileAccess: true,
            allowContentAccess: true,
            useHybridComposition: true,
            useShouldOverrideUrlLoading: true,
            useShouldInterceptAjaxRequest: true,
            isInspectable: true,
            transparentBackground: true,
            disableHorizontalScroll: false,
            disableVerticalScroll: false,
            userAgent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
          ),
          onWebViewCreated: (controller) async {
            _webViewController = controller;

            if (!Platform.isAndroid ||
                await WebViewFeature.isFeatureSupported(
                  WebViewFeature.WEB_MESSAGE_LISTENER,
                )) {
              await controller.addWebMessageListener(
                WebMessageListener(
                  jsObjectName: 'OLReader',
                  allowedOriginRules: const {
                    'https://archive.org',
                    'https://*.archive.org',
                  },
                  onPostMessage:
                      (message, sourceOrigin, isMainFrame, replyProxy) {
                    _handleWebMessage(message?.data);
                  },
                ),
              );
            }
          },
          onLoadStart: (controller, url) {
            // Don't reset progress if we're already at the theater view
            if (_progress >= 0.8) return;

            _currentLoadingDomain = 'openlibrary.org';
            _startLoadingTimeout();
            setState(() {
              _isLoading = true;
              _progress = 0;
              _loadMessage = 'Loading your book...';
            });
          },
          onLoadStop: (controller, url) async {
            debugPrint('Reader onLoadStop: $url');
            final urlString = url.toString();
            if (urlString.contains('view=theater')) {
              _cancelLoadingTimeout();
              if (Platform.isAndroid) {
                await _injectReaderCode(controller);
              }
              // On iOS, hide overlay here; on Android, wait for PostInit message
              if (Platform.isIOS) {
                setState(() {
                  _isLoading = false;
                });
              }
            }
            // Don't hide overlay for intermediate page loads
          },
          onReceivedError: (controller, url, code) {
            _cancelLoadingTimeout();
            setState(() {
              _isLoading = false;
            });
            debugPrint('Reader failed to load $url: $code');
          },
          onConsoleMessage: (controller, consoleMessage) {
            debugPrint('Reader console: ${consoleMessage.message}');
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            final url = navigationAction.request.url.toString();
            debugPrint('Reader shouldOverride: $url');

            if (url.contains('openlibrary.org/account/login')) {
              _loginRedirectCount++;

              if (_loginRedirectCount > 2) {
                if (mounted) {
                  _showError(
                    'This book requires you to be logged in. Please log in and try again.',
                  );
                  context.goBack();
                }
                return NavigationActionPolicy.CANCEL;
              }

              await _authDataSource.ensureCookiesLoaded();
              final cookieHeader = _authDataSource.cookieHeader;

              if (cookieHeader == null ||
                  cookieHeader.isEmpty ||
                  !cookieHeader.contains('session=')) {
                if (mounted) {
                  _showError(
                    'This book requires you to be logged in. Please log in and try again.',
                  );
                  context.goBack();
                }
                return NavigationActionPolicy.CANCEL;
              }

              controller.loadUrl(
                urlRequest: URLRequest(
                  url: navigationAction.request.url,
                  headers: {'Cookie': cookieHeader},
                ),
              );
              return NavigationActionPolicy.CANCEL;
            }

            if (url.contains('/borrow')) {
              _currentLoadingDomain = 'openlibrary.org';
              _startLoadingTimeout();
              setState(() {
                _progress = 0.2;
                _loadMessage = 'Opening your book...';
              });
            } else if (url.contains('BookReaderAuth')) {
              _currentLoadingDomain = 'openlibrary.org';
              _startLoadingTimeout();
              setState(() {
                _progress = 0.4;
                _loadMessage = 'Checking book out...';
              });
            } else if (url.contains('archive.org/stream')) {
              _currentLoadingDomain = 'archive.org';
              _startLoadingTimeout();
              setState(() {
                _progress = 0.6;
                _loadMessage = 'Loading book pages...';
              });
            } else if (url.contains('view=theater')) {
              _currentLoadingDomain = 'archive.org';
              _startLoadingTimeout();
              setState(() {
                _progress = 0.8;
              });
            }

            if ((url.contains('openlibrary.org') &&
                    url.contains('/details/')) ||
                url.contains('/account/loans')) {
              context.goBack();
              return NavigationActionPolicy.CANCEL;
            }

            return NavigationActionPolicy.ALLOW;
          },
          shouldInterceptAjaxRequest: (controller, ajaxRequest) async {
            final url = ajaxRequest.url.toString();
            if (url.contains('BookReaderJSIA')) {
              _currentLoadingDomain = 'archive.org';
              _startLoadingTimeout();
              await _injectReaderCode(controller);
              setState(() {
                _progress = 1.0;
              });
            }
            return null;
          },
        ),
        if (_isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.35,
                      child: _buildCoverImage(),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 35.0),
                      width: 250.0,
                      child: LinearProgressIndicator(
                        value: _progress,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 10.0),
                      child: Text(
                        _loadMessage,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCoverImage() {
    String? coverUrl;

    if (widget.coverEditionId != null && widget.coverEditionId!.isNotEmpty) {
      coverUrl =
          'https://covers.openlibrary.org/b/olid/${widget.coverEditionId}-M.jpg';
    } else if (widget.coverImageId != null) {
      coverUrl =
          'https://covers.openlibrary.org/b/id/${widget.coverImageId}-M.jpg';
    }

    if (coverUrl != null) {
      return CachedNetworkImage(
        imageUrl: coverUrl,
        fit: BoxFit.contain,
        errorWidget: (context, url, error) => _buildCoverPlaceholder(),
        // Generous caching settings for reader covers
        memCacheWidth: 800,           // High quality memory cache for reader
        maxHeightDiskCache: 1200,      // Preserve high-quality images on disk
        cacheKey: coverUrl,            // Custom cache key for reliable caching
        fadeInDuration: const Duration(milliseconds: 300), // Smooth fade-in
        fadeOutDuration: const Duration(milliseconds: 150), // Smooth fade-out
        // Web-specific optimizations

      );
    }
    return _buildCoverPlaceholder();
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(
          Icons.book,
          size: 96,
          color: Colors.white54,
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          const Text(
            'Error loading reader',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.goBack(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 8),
      ),
    );
  }

  Future<void> _injectReaderCode(InAppWebViewController controller) async {
    if (!mounted) return;

    try {
      debugPrint('Injecting reader customization code');

      // Load CSS asset
      final cssOverride = await DefaultAssetBundle.of(context)
          .loadString('assets/css/ia_reader.css');
      final cssInjection =
          "const cssOverrideStyle = document.createElement('style');"
          "cssOverrideStyle.textContent = `$cssOverride`;"
          "document.head.append(cssOverrideStyle);";
      await controller.evaluateJavascript(source: cssInjection);
      debugPrint('Injected reader CSS');

      if (!mounted) return;

      // Load JavaScript asset
      final jsOverride = await DefaultAssetBundle.of(context)
          .loadString('assets/js/menu_toggle.js');
      await controller.evaluateJavascript(source: jsOverride);
      debugPrint('Injected reader JavaScript');
    } catch (e) {
      debugPrint('Error injecting reader code: $e');
    }
  }

  void _handleWebMessage(String? messageData) {
    if (messageData == null) return;

    try {
      final message = json.decode(messageData) as Map<String, dynamic>;
      final type = message['type'] as String?;
      debugPrint('WebMessage received: $type');

      switch (type) {
        case 'HidingNav':
          _setFullScreenFromJs(true);
          break;
        case 'ShowingNav':
          _setFullScreenFromJs(false);
          break;
        case 'PostInit':
          setState(() {
            _isLoading = false;
          });
          break;
        case 'NoReader':
          _showError('Book reader could not be loaded');
          break;
        case 'LoanExpired':
          if (_fullScreen) {
            _setFullScreenFromJs(false);
          }
          //_showError('Your loan has expired');
          break;
      }
    } catch (e) {
      debugPrint('Error parsing web message: $e');
    }
  }

  /// Mirror JS fullscreen state; do not call toggleNav from here.
  void _setFullScreenFromJs(bool fullScreen) {
    setState(() {
      _fullScreen = fullScreen;

      // Only modify SystemChrome if showChrome setting is false
      final settingsState = _settingsNotifier.state;
      if (settingsState is SettingsLoaded && !settingsState.settings.showChrome) {
        if (fullScreen) {
          SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.manual,
            overlays: [],
          );
        } else {
          SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.manual,
            overlays: SystemUiOverlay.values,
          );
        }
      }
    });

    _webViewController?.evaluateJavascript(source: 'br.resize();');
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      maintainState: true,
      builder: (context) {
        return Positioned(
          top: 0,
          right: 0,
          left: 0,
          height: 25,
          child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _requestToggleNav,
              ),
        );
      },
    );
  }

  Future<void> _reloadReader() async {
    final state = _notifier.state;
    if (state is! ReaderReady) return;

    _currentLoadingDomain = 'openlibrary.org';
    _startLoadingTimeout();
    setState(() {
      _isLoading = true;
      _progress = 0;
      _loadMessage = 'Loading your book...';
    });

    await _webViewController?.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(state.readerUrl),
        headers: {
          'Cookie': _authDataSource.cookieHeader ?? '',
        },
      ),
    );
  }
}

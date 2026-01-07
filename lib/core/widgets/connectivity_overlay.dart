import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../di/injection.dart';
import '../services/connectivity_service.dart';

/// Widget that shows connectivity status overlay
class ConnectivityOverlay extends StatefulWidget {
  final Widget child;

  const ConnectivityOverlay({super.key, required this.child});

  @override
  State<ConnectivityOverlay> createState() => _ConnectivityOverlayState();
}

class _ConnectivityOverlayState extends State<ConnectivityOverlay> {
  late final ConnectivityService _connectivityService;

  @override
  void initState() {
    super.initState();
    _connectivityService = getIt<ConnectivityService>();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _connectivityService,
      builder: (context, _) {
        // Show different messages based on connectivity state
        if (_connectivityService.isOffline) {
          return _buildOverlay(
            context,
            'No Internet Connection',
            'You are offline. Please check your network connection.',
            null,
            null,
          );
        } else if (_connectivityService.isOpenLibraryDown) {
          return _buildOverlay(
            context,
            'OpenLibrary Unavailable',
            'OpenLibrary.org is currently unresponsive. Please try again later.',
            'Check OpenLibrary Status',
            'https://openlibrary.org',
          );
        } else if (_connectivityService.isArchiveOrgDown) {
          return _buildOverlay(
            context,
            'Archive.org Unavailable',
            'Archive.org is currently unresponsive. Please try again later.',
            'Check Archive.org Status',
            'https://archive.org',
          );
        }

        return widget.child;
      },
    );
  }

  Widget _buildOverlay(
    BuildContext context,
    String title,
    String message,
    String? buttonText,
    String? url,
  ) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _connectivityService.isOffline ? Icons.wifi_off : Icons.cloud_off,
                        color: Theme.of(context).colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 20,
                        ),
                        onPressed: () {
                          // Dismiss by resetting service status
                          _connectivityService.resetServiceAvailability();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  if (buttonText != null && url != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => launchUrlString(url),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(buttonText),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
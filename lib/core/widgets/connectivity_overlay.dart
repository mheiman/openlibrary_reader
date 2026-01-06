import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../services/connectivity_service.dart';

/// Widget that shows connectivity status overlay
class ConnectivityOverlay extends StatelessWidget {
  final Widget child;

  const ConnectivityOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivity, _) {
        // Show different messages based on connectivity state
        if (connectivity.isOffline) {
          return _buildOverlay(
            context,
            'No Internet Connection',
            'You are offline. Please check your network connection.',
            null,
            null,
          );
        } else if (connectivity.isOpenLibraryDown) {
          return _buildOverlay(
            context,
            'OpenLibrary Unavailable',
            'OpenLibrary.org is currently unresponsive. Please try again later.',
            'Check OpenLibrary Status',
            'https://openlibrary.org',
          );
        } else if (connectivity.isArchiveOrgDown) {
          return _buildOverlay(
            context,
            'Archive.org Unavailable',
            'Archive.org is currently unresponsive. Please try again later.',
            'Check Archive.org Status',
            'https://archive.org',
          );
        }
        
        return child;
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
        child,
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
                        connectivity.isOffline ? Icons.wifi_off : Icons.cloud_off,
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
                          Provider.of<ConnectivityService>(context, listen: false)
                              .resetServiceAvailability();
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
                        child: Text(buttonText),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size(50, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
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
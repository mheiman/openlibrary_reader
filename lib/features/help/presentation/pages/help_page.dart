import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';

/// Help page that displays help content from the web
class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OL Reader Help'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              // If we can't pop, go back to the root/shelves page
              context.go('/');
            }
          },
          tooltip: 'Back',
        ),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri('https://loomis-house.com/olreader/?view=internal'),
            ),
            initialSettings: InAppWebViewSettings(
              transparentBackground: true,
            ),
            onLoadStop: (InAppWebViewController controller, WebUri? url) {
              if (mounted) {
                setState(() {
                  _loading = false;
                });
              }
            },
          ),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

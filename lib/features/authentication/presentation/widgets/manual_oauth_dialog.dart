import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/auth_notifier.dart';

/// Dialog for manually entering OAuth authorization code
class ManualOAuthDialog extends StatefulWidget {
  final AuthNotifier authNotifier;

  const ManualOAuthDialog({
    super.key,
    required this.authNotifier,
  });

  @override
  State<ManualOAuthDialog> createState() => _ManualOAuthDialogState();
}

class _ManualOAuthDialogState extends State<ManualOAuthDialog> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final code = _codeController.text.trim();
      await widget.authNotifier.handleManualOAuthCode(code);

      // Close dialog on success
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Error will be shown by AuthNotifier state
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Authorization Code'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If the automatic login redirect didn\'t work, paste your authorization code below:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _codeController,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                hintText: 'Authorization code',
                prefixIcon: const Icon(Icons.vpn_key),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste),
                  tooltip: 'Paste from clipboard',
                  onPressed: _isSubmitting ? null : () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) {
                      _codeController.text = data!.text!;
                    }
                  },
                ),
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleSubmit(),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the authorization code';
                }
                if (value.trim().length < 10) {
                  return 'Code appears too short';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Tip: Long-press to paste the code from your clipboard',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _handleSubmit,
          child: _isSubmitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}

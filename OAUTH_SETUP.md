# OAuth Setup for OpenLibrary Reader

This document explains how to configure the OAuth redirect URI for your fork of this repository.

## Overview

The OAuth redirect URI is where users are sent after authenticating with OpenLibrary. The app automatically uses GitHub Pages for OAuth redirects based on your local configuration.

## Initial Setup (Required)

After cloning the repository, you need to create your local configuration:

1. Copy the template file:
```bash
cp lib/core/network/local_config.dart.template lib/core/network/local_config.dart
```

2. Edit `lib/core/network/local_config.dart` and update:
```dart
class LocalConfig {
  static const String githubUsername = 'YOUR_GITHUB_USERNAME';  // Change this!
  static const String githubRepo = 'openlibrary_reader';        // Or your repo name
  static const String? customOAuthRedirectUri = null;           // Usually leave as null

  // OAuth client credentials - keep these private!
  static const String oauthClientId = 'YOUR_OAUTH_CLIENT_ID';
  static const String oauthClientSecret = 'YOUR_OAUTH_CLIENT_SECRET';
}
```

3. Your `local_config.dart` is git-ignored and won't be committed.

**This creates your personal OAuth redirect URI:**
`https://YOUR_USERNAME.github.io/YOUR_REPO/oauth-redirect.html`

## Configuration Options

### 1. Local Development (Default)

After creating `local_config.dart`, just run normally:
```bash
flutter run  # Uses your GitHub Pages URL from local_config.dart
flutter build apk
```

### 2. CI/CD or Temporary Override

Override your local config with command-line arguments:

```bash
# Override GitHub username/repo
flutter build apk --dart-define=GITHUB_USERNAME=other_user

# Override OAuth credentials
flutter build apk \
  --dart-define=OAUTH_CLIENT_ID=your_client_id \
  --dart-define=OAUTH_CLIENT_SECRET=your_client_secret
```

### 3. Custom OAuth Redirect URI

For complete control (custom domain, different hosting, etc.), either:

**Option A:** Set in `local_config.dart`:
```dart
static const String? customOAuthRedirectUri = 'https://your-domain.com/oauth-redirect.html';
```

**Option B:** Override at build time:
```bash
flutter build apk --dart-define=OAUTH_REDIRECT_URI=https://your-domain.com/oauth-redirect.html
```

### 4. GitHub Actions CI/CD

Since `local_config.dart` is git-ignored, you need to provide config for CI/CD.

Add repository variables/secrets (Settings → Secrets and variables → Actions):

**Variables** (non-sensitive):
- `GITHUB_USERNAME`: Your GitHub username
- `GITHUB_REPO`: Your repository name (optional if still `openlibrary_reader`)

**Secrets** (sensitive):
- `OAUTH_CLIENT_ID`: Your OAuth client ID
- `OAUTH_CLIENT_SECRET`: Your OAuth client secret

Then in your workflow:
```yaml
- name: Build APK
  run: |
    flutter build apk \
      --dart-define=GITHUB_USERNAME=${{ vars.GITHUB_USERNAME }} \
      --dart-define=GITHUB_REPO=${{ vars.GITHUB_REPO }} \
      --dart-define=OAUTH_CLIENT_ID=${{ secrets.OAUTH_CLIENT_ID }} \
      --dart-define=OAUTH_CLIENT_SECRET=${{ secrets.OAUTH_CLIENT_SECRET }}
```

Or use the full redirect URL if preferred:
```yaml
- name: Build APK
  run: |
    flutter build apk \
      --dart-define=OAUTH_REDIRECT_URI=${{ vars.OAUTH_REDIRECT_URI }} \
      --dart-define=OAUTH_CLIENT_ID=${{ secrets.OAUTH_CLIENT_ID }} \
      --dart-define=OAUTH_CLIENT_SECRET=${{ secrets.OAUTH_CLIENT_SECRET }}
```

## Verifying Configuration

You can verify your OAuth configuration is correct by checking the logs when initiating OAuth login. Look for:

```
🔑 [OAuth] OAuth parameters: {...redirect_uri=YOUR_URL...client_id=YOUR_CLIENT_ID...}
```

Note: The client_secret is not logged for security reasons.

## GitHub Pages Setup

1. Ensure your fork has GitHub Pages enabled (Settings → Pages)
2. Set the source to the `docs/` folder or root with `docs/` folder
3. The `oauth-redirect.html` file should be accessible at your Pages URL
4. Test by visiting: `https://YOUR_USERNAME.github.io/YOUR_REPO_NAME/oauth-redirect.html`

## Server-Side Configuration

Make sure your OpenLibrary OAuth server is configured to accept your redirect URI. The redirect URI must exactly match what's configured in your OAuth provider settings.

## Troubleshooting

### "Cannot find 'local_config.dart'" error
You need to create the local config file:
```bash
cp lib/core/network/local_config.dart.template lib/core/network/local_config.dart
```
Then edit it with your GitHub username.

### OAuth redirect fails on mobile
- Verify the redirect URI in the app matches your GitHub Pages URL
- Check that GitHub Pages is enabled and the page is accessible
- Ensure the URL uses `https://` (not `http://`) for production builds
- Check logs: look for "OAuth parameters" to see what redirect URI is being used

### "Invalid redirect URI" error
- The redirect URI must be registered with your OAuth provider
- Check for typos in your `local_config.dart`
- Ensure the URL is accessible from a browser

### CI/CD builds fail
- Remember: `local_config.dart` is NOT in the repository (it's git-ignored)
- You must provide `--dart-define` arguments in your CI/CD workflow
- See "GitHub Actions CI/CD" section above

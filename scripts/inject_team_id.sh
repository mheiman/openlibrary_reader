#!/bin/bash

# OAuth Redirect Service - Team ID Injection Script
# For local testing only - use GitHub Secrets for production

echo "🔒 OpenLibrary Reader - Team ID Injection Script"
echo "=============================================="
echo ""

# Check if Team ID is provided
if [ -z "$APPLE_TEAM_ID" ]; then
  read -p "Enter your Apple Developer Team ID: " APPLE_TEAM_ID
fi

# Validate Team ID format
if [[ "$APPLE_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "✅ Team ID format is valid: $APPLE_TEAM_ID"
else
  echo "❌ Invalid Team ID format!"
  echo "Expected: 10 alphanumeric characters (A-Z, 0-9)"
  echo "Example: ABCDE12345"
  exit 1
fi

# Check if AASA file exists
if [ ! -f "docs/.well-known/apple-app-site-association" ]; then
  echo "❌ AASA file not found!"
  echo "Expected: docs/.well-known/apple-app-site-association"
  exit 1
fi

# Create backup
cp docs/.well-known/apple-app-site-association docs/.well-known/apple-app-site-association.backup
 echo "💾 Backup created: apple-app-site-association.backup"

# Inject Team ID
sed -i "" "s/TEAM_ID_PLACEHOLDER/$APPLE_TEAM_ID/g" docs/.well-known/apple-app-site-association

echo "🔧 Team ID injected successfully!"

# Show the result (masked)
FULL_APP_ID=$(grep -o '"appID": "[^"]*"' docs/.well-known/apple-app-site-association)
MASKED_APP_ID=$(echo "$FULL_APP_ID" | sed 's/"appID": "\(.\)\(.*\)\(..\)"/"appID": "\1***\3"/')
echo "Updated appID: $MASKED_APP_ID"

# Validate JSON
if jsonlint docs/.well-known/apple-app-site-association >/dev/null 2>&1; then
  echo "✅ JSON is valid"
else
  echo "❌ JSON validation failed!"
  echo "Restoring backup..."
  mv docs/.well-known/apple-app-site-association.backup docs/.well-known/apple-app-site-association
  exit 1
fi

echo ""
echo "📋 Next Steps:"
echo "1. Test locally: open docs/oauth-redirect.html in browser"
echo "2. For production: use GitHub Secrets (APPLE_TEAM_ID)"
echo "3. Push changes to trigger GitHub Actions workflow"
echo ""
echo "⚠️  Security Reminder:"
echo "- This script is for LOCAL TESTING only"
echo "- For production, use GitHub Secrets"
echo "- Never commit actual Team ID to repository"

echo ""
echo "🎉 Team ID injection complete!"

# Show file info
ls -la docs/.well-known/apple-app-site-association
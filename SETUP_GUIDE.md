# Setup Guide for Bed Space Management App

This guide will help you set up the Google Sign-In and Google Sheets API integration.

## Prerequisites

- Flutter SDK installed
- Google Cloud Platform account
- Android Studio / Xcode for platform-specific configuration

## Step 1: Google Cloud Console Configuration

### 1.1 Create/Select Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Note your project ID

### 1.2 Enable APIs

Enable the following APIs in your Google Cloud project:

1. Go to **APIs & Services** > **Library**
2. Search and enable:
   - **Google Sheets API**
   - **Google Drive API**

### 1.3 Create OAuth 2.0 Credentials

#### For Android:

1. Go to **APIs & Services** > **Credentials**
2. Click **Create Credentials** > **OAuth client ID**
3. If prompted, configure the OAuth consent screen first:
   - User type: **Internal** (for personal use)
   - Fill in required fields
4. Create OAuth client ID:
   - Application type: **Android**
   - Name: `Bed Space Android` (or any name)
   - Package name: `com.example.bed_space` (check your `android/app/build.gradle.kts`)
   - SHA-1 certificate fingerprint: Get this using:
     ```bash
     cd android
     ./gradlew signingReport
     ```
     Look for SHA1 in the output
5. Click **Create**
6. Download the `google-services.json` file
7. Place it in `android/app/`

#### For iOS:

1. Create another OAuth client ID:
   - Application type: **iOS**
   - Name: `Bed Space iOS`
   - Bundle ID: Check your `ios/Runner/Info.plist` or Xcode project settings
2. Click **Create**
3. Download the `GoogleService-Info.plist` file
4. Place it in `ios/Runner/`
5. Open `ios/Runner/Info.plist`
6. Find the `CFBundleURLSchemes` array
7. Replace `REVERSE_CLIENT_ID` with the actual reverse client ID from `GoogleService-Info.plist`
   - The reverse client ID is found in the plist file as `REVERSED_CLIENT_ID`
   - Format: `com.googleusercontent.apps.YOUR_CLIENT_ID`

### 1.4 Configure OAuth Consent Screen

1. Go to **APIs & Services** > **OAuth consent screen**
2. User Type: **Internal** (for personal use) or **External** (if you need to test with other accounts)
3. Fill in required information:
   - App name: Bed Space Management
   - User support email: Your email
   - Developer contact: Your email
4. Add scopes (if required):
   - `https://www.googleapis.com/auth/spreadsheets`
   - `https://www.googleapis.com/auth/drive.file`
5. Add test users (if using External type):
   - Add your Google account email
6. Save and continue

## Step 2: Android Configuration

### 2.1 Verify Build Configuration

Check `android/app/build.gradle.kts`:

```kotlin
minSdk = 21  // Minimum required for Google Sign-In
```

### 2.2 Verify Manifest Permissions

The `AndroidManifest.xml` already includes required permissions:
- Internet permission
- Notification permissions

### 2.3 Place google-services.json

Ensure `google-services.json` is in `android/app/` directory.

## Step 3: iOS Configuration

### 3.1 Update Info.plist

1. Open `ios/Runner/Info.plist`
2. Find the URL scheme configuration
3. Replace `REVERSE_CLIENT_ID` with your actual reverse client ID from `GoogleService-Info.plist`

The URL scheme should look like:
```xml
<key>CFBundleURLSchemes</key>
<array>
    <string>com.googleusercontent.apps.YOUR_ACTUAL_CLIENT_ID</string>
</array>
```

### 3.2 Place GoogleService-Info.plist

Ensure `GoogleService-Info.plist` is in `ios/Runner/` directory.

## Step 4: Install Dependencies

```bash
flutter pub get
```

## Step 5: Run the App

### Android

```bash
flutter run
```

### iOS

```bash
cd ios
pod install
cd ..
flutter run
```

## Step 6: First Time Usage

1. Launch the app
2. Click "Sign in with Google"
3. Select your Google account
4. Grant permissions for Google Sheets and Drive
5. The app will automatically:
   - Create a Google Sheet named `BedSpace_<your_email>`
   - Set up all required tabs (Buildings, Rooms, Beds, Tenants, Payments)
   - Store the sheet ID locally

## Troubleshooting

### Google Sign-In Fails

1. **Check SHA-1 fingerprint**: Ensure you've added the correct SHA-1 fingerprint in Google Cloud Console
2. **Check package name**: Verify the package name matches in `build.gradle.kts` and Google Cloud Console
3. **Check OAuth client ID**: Ensure you've created Android/iOS OAuth client IDs

### Sheets API Errors

1. **Check API enablement**: Ensure Google Sheets API and Drive API are enabled
2. **Check OAuth scopes**: Verify scopes are properly configured
3. **Check access token**: The app uses the access token from Google Sign-In

### iOS URL Scheme Issues

1. **Check Info.plist**: Ensure the reverse client ID is correctly set
2. **Check GoogleService-Info.plist**: Verify the file is in the correct location
3. **Rebuild app**: Sometimes Xcode cache needs to be cleared

### Sheet Creation Fails

1. **Check permissions**: Ensure the OAuth consent screen has the required scopes
2. **Check Drive API**: Ensure Google Drive API is enabled
3. **Check test users**: If using External OAuth, ensure your account is added as a test user

## Important Notes

- **Internal Use Only**: This app is designed for personal/internal use
- **No Backend**: All data is stored in Google Sheets
- **One Sheet Per Device**: Each device creates its own sheet
- **Reinstall Warning**: Uninstalling the app will lose the local sheet reference (but the sheet remains in Google Drive)

## Security Considerations

- Store credentials securely
- Don't commit `google-services.json` or `GoogleService-Info.plist` to public repositories
- Use internal OAuth consent screen for personal use
- Be aware that all data is stored in Google Sheets with the logged-in user's account


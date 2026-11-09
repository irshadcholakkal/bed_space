# Setup Guide for Bed Space Management App

This guide will help you set up the Google Sign-In and Google Sheets API integration.

For the landing page, customer registration and Supabase account tables, start
with [SaaS setup](docs/SAAS_SETUP.md), then configure Google access below.
For subscriptions, server-only payment keys and callback addresses, see
[Paymob setup](docs/PAYMOB_SETUP.md).

## Cloudflare Pages hosting

Create a **Pages** project under **Workers & Pages**, connect your Git repository,
and use these build settings:

| Setting | Value |
|---|---|
| Framework preset | None |
| Root directory | Repository root, or the folder containing `pubspec.yaml` |
| Build command | `bash scripts/cloudflare-build.sh` |
| Build output directory | `build/web` |
| Build environment variables | `NODE_VERSION=22`, `SKIP_DEPENDENCY_INSTALL=true`, and `GOOGLE_CLIENT_ID` |

Set the environment variables for Production and Preview as needed. Use the
Google **Web application** client ID described below, then deploy. Changes to
`GOOGLE_CLIENT_ID` require a new build. A Git-integrated Pages project does not
need a deploy command; if asked for a Workers deploy command, select Pages.

See [PWA deployment instructions](docs/PWA.md) for custom domains, preview
authorization, installation and offline checks, and the
[Cloudflare build configuration reference](https://developers.cloudflare.com/pages/configuration/build-configuration/).

## Hosting with an existing Cloudflare Worker

The repository also supports a static-assets Worker named `bed-space` through
`wrangler.json`. Keep **Build command** `bash scripts/cloudflare-build.sh`,
**Deploy command** `npx wrangler deploy`, and **Root directory** `/`.
Wrangler uploads only the compiled `build/web` folder.

Set `GOOGLE_CLIENT_ID`, `NODE_VERSION=22`, and `SKIP_DEPENDENCY_INSTALL=true`
under **Builds > Variables and secrets**, then deploy the updated repository.
Runtime variables and bindings are unnecessary for this static app; the Google
client ID is embedded at build time. Keep the custom domain attached to this
Worker and authorize its exact HTTPS origin in Google Cloud Console.

## Google Cloud setup for the Cloudflare Pages PWA

1. Create/select your project in https://console.cloud.google.com/.
2. In **APIs & Services > Library**, enable **Google Sheets API** and
   **Google Drive API**.
3. Open **Google Auth Platform**. Set up **Branding** with the app name,
   support email and contact email. In **Audience**, choose **External** for
   personal Gmail accounts and add your login email under **Test users** while
   the app is in Testing. Internal is only for a Google Workspace organization.
4. In **Data Access**, add the scopes requested by this app:
   `openid`, `email`, `profile`,
   `https://www.googleapis.com/auth/spreadsheets`, and
   `https://www.googleapis.com/auth/drive.file`.
5. In **Clients > Create client**, choose **Web application**. Add these
   **Authorized JavaScript origins**, replacing the deployment example:
   - `http://localhost`
   - `http://localhost:3000`
   - `https://YOUR-PROJECT.pages.dev`
   - Your custom HTTPS domain, if used.
   Origins have no path or trailing slash. No redirect URI is needed for this
   app's browser popup/token sign-in flow.
6. Copy the **Client ID** into the root `.env`:
   ```dotenv
   GOOGLE_CLIENT_ID=YOUR_CLIENT_ID.apps.googleusercontent.com
   FLUTTER_VERSION=3.47.2
   ```
   This browser app does not use a client secret, API key or service-account
   JSON. No change in `lib/main.dart` is required.
7. For local Chrome testing, use PowerShell from the project root:
   ```powershell
   node scripts/load-build-env.mjs
   flutter run -d chrome --web-port 3000 --dart-define-from-file=.dart_tool/build-config.json
   ```
8. In **Cloudflare Pages > Project > Settings > Environment Variables**, add the same
   `GOOGLE_CLIENT_ID` for Production (and Preview if required), then redeploy.
   The local `.env` is intentionally not uploaded. Authorize each preview
   origin separately if you test Google login on preview deployments.
9. Open the app, sign in with an allowed test user and grant Sheets/Drive
   access. When changing to a different Cloud project, its `drive.file`
   authorization does not automatically give access to files created by the
   previous OAuth app; back up existing data before switching projects.

For access beyond test users, review Google's publishing/verification
requirements for the requested scopes in Google Auth Platform.

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
   - User type: **External** for personal Gmail; **Internal** only for Workspace organizations
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
2. User Type: **External** for personal Gmail accounts, or **Internal** for users within a Google Workspace organization
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

### Cloudflare Pages shows a white screen

In the Pages project's build settings, use **Build command**
`bash scripts/cloudflare-build.sh` and **Build output directory** `build/web`.
The source folder `web` is not deployable: its HTML and bootstrap JavaScript
contain placeholders that Flutter replaces during a release build.
Set the root directory to the folder containing `pubspec.yaml`, then trigger
a new deployment from the latest commit.

After deployment, check that `/main.dart.js` returns JavaScript and that the
page source has `<base href="/">` rather than `$FLUTTER_BASE_HREF`.
For Direct Upload, run `./scripts/build_pwa.ps1` locally and upload the
contents of `build/web`. If an installed PWA still shows the old deployment,
clear this site's browser storage and reopen it.

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


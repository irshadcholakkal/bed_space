# Quick Start Guide

## ✅ App is Running!

Your Bed Space Management app has been successfully built and is running on your device.

## Current Status

- ✅ App compiled successfully
- ✅ Installed on device
- ✅ Google Sign-In activity is launching (this is normal)

## Next Steps

### 1. Configure Google Sign-In (Required)

Before you can use the app, you need to set up Google Cloud Console credentials:

#### Get Your SHA-1 Fingerprint

Run this command in your project directory:
```bash
cd android
./gradlew signingReport
```

Look for the SHA1 value in the output (under `Variant: debug`).

#### Create OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create or select a project
3. Enable **Google Sheets API** and **Google Drive API**
4. Go to **APIs & Services** > **Credentials**
5. Click **Create Credentials** > **OAuth client ID**
6. Choose **Android** as application type
7. Enter:
   - Package name: `com.example.bed_space`
   - SHA-1 certificate fingerprint: (from step above)
8. Download `google-services.json`
9. Place it in `android/app/` directory

### 2. Test Sign-In

1. Tap "Sign in with Google" in the app
2. Select your Google account
3. Grant permissions for Sheets and Drive
4. The app will automatically create a Google Sheet named `BedSpace_<your_email>`

### 3. Start Using the App

Once signed in, you can:
- View dashboard statistics
- Manage buildings and rooms
- Track financials
- Set up rent reminders

## Troubleshooting

### Sign-In Fails

- **Check SHA-1**: Ensure you've added the correct SHA-1 fingerprint
- **Check Package Name**: Must match `com.example.bed_space` exactly
- **Check APIs**: Ensure Sheets API and Drive API are enabled
- **Check OAuth Consent**: Configure OAuth consent screen in Google Cloud Console

### Sheet Creation Fails

- **Check Permissions**: Ensure you granted Sheets and Drive permissions
- **Check API Access**: Verify APIs are enabled in Google Cloud Console
- **Check Internet**: Ensure device has internet connection

### App Crashes

- Check logs in terminal for error messages
- Verify all dependencies are installed: `flutter pub get`
- Try hot restart: Press `R` in terminal

## Need Help?

- See `SETUP_GUIDE.md` for detailed setup instructions
- See `README.md` for project overview
- Check Google Cloud Console for API status

---

**Note**: The app is designed for internal/personal use. One sheet is created per device per Google account.


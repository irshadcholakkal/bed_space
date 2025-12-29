# Bed Space Management App

A Flutter application for managing shared accommodation / bed spaces using Google Sign-In and Google Sheets as the database.

## ⚠️ IMPORTANT DISCLAIMER

**This app:**
- Is **client-only** (no backend, no Firebase)
- Uses Google Sign-In for authentication
- Uses Google Sheets API directly as database
- **Does NOT guarantee uniqueness across devices**
- **Is NOT suitable for high-security financial data**
- **Is designed for internal / prototype usage only**

**One Google user → one Google Sheet per device**
- Sheet ID is stored locally in SharedPreferences
- On app reinstall, a new sheet may be created
- No global synchronization across devices

## Features

- 🔐 **Google Sign-In Authentication** - Secure login with Google account
- 📊 **Dashboard** - Overview of buildings, rooms, beds, and financials
- 🏢 **Rooms Management** - View buildings and rooms with vacancy status
- 💰 **Financials** - Track tenant payments by month
- 🔔 **Rent Reminders** - Local notifications 3 days before rent due date
- ⚙️ **Settings** - Account info, sheet sync, and logout

## Architecture

- **Clean Architecture** - Separated into data, domain, and presentation layers
- **BLoC Pattern** - State management using flutter_bloc
- **Pastel UI** - Minimalist design with soft, calming colors

## Setup Instructions

### 1. Google Cloud Console Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the following APIs:
   - Google Sheets API
   - Google Drive API
4. Create OAuth 2.0 Credentials:
   - Go to **APIs & Services** > **Credentials**
   - Click **Create Credentials** > **OAuth client ID**
   - Application type: **Android** and **iOS** (create separate credentials for each)
   - For Android: Add your package name and SHA-1 fingerprint
   - For iOS: Add your bundle ID
   - Download the configuration files

### 2. Android Setup

1. Place your `google-services.json` in `android/app/`
2. Update `android/app/build.gradle.kts`:
   ```kotlin
   minSdk = 21  // Minimum required for Google Sign-In
   ```

3. The app already includes required permissions in `AndroidManifest.xml`:
   - Internet permission
   - Notification permissions

### 3. iOS Setup

1. Update `ios/Runner/Info.plist`:
   - Replace `REVERSE_CLIENT_ID` in the URL scheme with your actual reverse client ID from Google Services
   - The reverse client ID format is: `com.googleusercontent.apps.YOUR_CLIENT_ID`

2. Add your Google Services configuration:
   - Add `GoogleService-Info.plist` to `ios/Runner/`

### 4. Install Dependencies

```bash
flutter pub get
```

### 5. Run the App

```bash
flutter run
```

## Project Structure

```
lib/
├── data/
│   ├── models/           # Data models (Building, Room, Bed, Tenant, Payment)
│   ├── repositories/     # Sheet repository for local storage
│   └── services/         # Google Auth & Sheets API services
├── presentation/
│   ├── blocs/           # BLoC state management
│   │   ├── auth/
│   │   ├── dashboard/
│   │   ├── financial/
│   │   ├── notification/
│   │   ├── room/
│   │   └── sheet/
│   ├── screens/         # UI screens
│   ├── theme/           # App theme with pastel colors
│   └── widgets/         # Reusable widgets
└── main.dart            # App entry point
```

## Google Sheets Structure

The app automatically creates a Google Sheet with the following tabs:

### Buildings
- `building_id`, `building_name`, `address`, `total_rooms`

### Rooms
- `room_id`, `building_id`, `room_number`, `total_capacity`, `lower_beds_count`, `upper_beds_count`, `lower_bed_rent`, `upper_bed_rent`, `utility_cost_monthly`

### Beds
- `bed_id`, `room_id`, `bed_type` (LOWER/UPPER), `status` (VACANT/OCCUPIED)

### Tenants
- `tenant_id`, `tenant_name`, `phone`, `building_id`, `room_id`, `bed_id`, `rent_amount`, `joining_date`, `rent_due_day`, `active`

### Payments
- `payment_id`, `tenant_id`, `amount`, `payment_month`, `paid_date`

## Usage

1. **Sign In**: Click "Sign in with Google" on the login screen
2. **First Time**: The app will automatically create a Google Sheet named `BedSpace_<your_email>`
3. **Dashboard**: View overview statistics and current month financials
4. **Rooms**: Browse buildings and rooms, see vacancy status
5. **Financials**: Track payments by month, see paid/unpaid tenants
6. **Settings**: View account info, sync sheet, or logout

## Limitations

- **No Multi-Device Sync**: Sheet ID is stored locally per device
- **No Backend Validation**: All validation is client-side
- **No Conflict Resolution**: No handling for concurrent edits
- **No Offline Support**: Requires internet connection for all operations
- **Reinstall Warning**: App reinstall may create a new sheet

## Development Notes

- All business logic is in BLoC classes
- Google Sheets service uses direct HTTP calls to Sheets API
- Local notifications use flutter_local_notifications
- State persistence uses SharedPreferences

## Dependencies

- `flutter_bloc` - State management
- `google_sign_in` - Google authentication
- `googleapis` - Google Sheets API
- `http` - HTTP requests
- `shared_preferences` - Local storage
- `flutter_local_notifications` - Local notifications
- `intl` - Date formatting
- `timezone` - Timezone support for notifications

## License

Internal use only - Not for distribution

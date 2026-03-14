# Cash Book - Flutter Firebase App

A modern Flutter application for managing personal finances with Firebase backend integration. Track your income and expenses with real-time cloud synchronization.

## Features

- 📱 **Cross-platform**: Works on Android, iOS, and Web
- 🔥 **Firebase Integration**: Real-time data synchronization with Firestore
- 💰 **Transaction Management**: Add, edit, and delete income/expense transactions
- 📊 **Financial Overview**: View balance, total income, and total expenses
- ⚙️ **Settings**: Customizable currency symbols
- 🎨 **Modern UI**: Beautiful Material Design interface with dark/light themes
- 🔐 **Authentication**: Anonymous authentication for data privacy

## Firebase Setup

### 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name: `cash-book-app` (or your preferred name)
4. Enable Google Analytics (optional)
5. Create the project

### 2. Enable Required Services

#### Authentication
1. In Firebase Console, go to **Authentication** > **Sign-in method**
2. Enable **Anonymous** authentication
3. Save changes

#### Firestore Database
1. Go to **Firestore Database**
2. Click "Create database"
3. Choose "Start in test mode" (for development)
4. Select a location for your database
5. Create database

### 3. Configure Your App

#### Android Configuration
1. In Firebase Console, click "Add app" and select Android
2. Enter package name: `com.example.myapp`
3. Download `google-services.json`
4. Replace the placeholder file in `android/app/google-services.json` with your downloaded file

#### Web Configuration
1. In Firebase Console, click "Add app" and select Web
2. Register your app with a nickname
3. Copy the Firebase configuration object
4. Update `lib/firebase_options.dart` with your actual configuration:

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'your-actual-web-api-key',
  appId: 'your-actual-web-app-id',
  messagingSenderId: 'your-actual-sender-id',
  projectId: 'your-actual-project-id',
  authDomain: 'your-actual-project-id.firebaseapp.com',
  storageBucket: 'your-actual-project-id.appspot.com',
);
```

### 4. Update Firebase Options

Replace all placeholder values in `lib/firebase_options.dart` with your actual Firebase configuration values for all platforms (Android, iOS, Web).

## Installation & Setup

### Prerequisites
- Flutter SDK (3.8.1 or higher)
- Dart SDK
- Android Studio / VS Code
- Firebase CLI (optional, for advanced features)

### Installation Steps

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd cash-book
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase** (see Firebase Setup section above)

4. **Run the app**
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart                 # App entry point with Firebase initialization
├── firebase_options.dart     # Firebase configuration
├── models/
│   └── transaction.dart      # Transaction data model
├── services/
│   ├── firebase_service.dart # Firebase utilities and configuration
│   ├── transaction_service.dart # Transaction CRUD operations
│   └── settings_service.dart    # User settings management
├── screens/
│   ├── splash_screen.dart    # App initialization screen
│   ├── home_screen.dart      # Main dashboard
│   ├── add_transaction_screen.dart # Add/edit transactions
│   ├── settings_screen.dart  # App settings
│   └── onboarding_screen.dart # First-time user experience
├── widgets/
│   └── transaction_list.dart # Transaction list widget
└── theme/
    └── app_theme.dart        # App theming
```

## Firebase Data Structure

### Firestore Collections

```
users/{userId}/
├── transactions/
│   └── {transactionId}/
│       ├── id: string
│       ├── title: string
│       ├── amount: number
│       ├── date: timestamp
│       └── type: string (income/expense)
└── settings/
    └── preferences/
        └── currencySymbol: string
```

## Development

### Adding New Features

1. **Models**: Add new data models in `lib/models/`
2. **Services**: Create service classes in `lib/services/` for business logic
3. **Screens**: Add new screens in `lib/screens/`
4. **Widgets**: Create reusable widgets in `lib/widgets/`

### Firebase Security Rules

For production, update your Firestore security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /transactions/{transactionId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /settings/{document} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

## Building for Production

### Android
```bash
flutter build apk --release
```

### Web
```bash
flutter build web --release
```

### iOS
```bash
flutter build ios --release
```

## Troubleshooting

### Common Issues

1. **Firebase not initialized**: Ensure `google-services.json` is properly placed and Firebase options are configured
2. **Build errors**: Run `flutter clean` and `flutter pub get`
3. **Authentication errors**: Check if Anonymous authentication is enabled in Firebase Console
4. **Firestore permission errors**: Verify security rules and authentication status

### Debug Mode
Enable debug logging by setting `kDebugMode` checks in your code or use Firebase Console logs.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in the repository
- Check Firebase documentation
- Review Flutter documentation

---

**Note**: Remember to replace all placeholder Firebase configuration values with your actual project credentials before running the app.

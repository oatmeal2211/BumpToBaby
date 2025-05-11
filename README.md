# BumpToBaby

## About
BumpToBaby is a comprehensive maternal and child health mobile application designed to support mothers through pregnancy and early childcare. The app provides essential tools, information, and community features to help women navigate their maternal journey with confidence.

## Features

### 1. User Authentication
- Secure signup and login functionality
- Email verification
- Password reset capabilities
- Profile customization with profile picture upload

### 2. Home Screen Dashboard
Six main feature buttons providing access to:
- Nearest Clinics: Find and navigate to nearby healthcare facilities
- Health Tracker: Monitor pregnancy progress, symptoms, and baby development
- Appointment Scheduler: Manage doctor appointments and reminders
- Educational Resources: Access pregnancy and childcare information
- Emergency Contacts: Quick access to emergency services
- Community Forum: Connect with other mothers

### 3. Community Features
- Events Calendar: Horizontally scrollable important dates for mothers
- Post Feed: Reddit-like interface for sharing experiences
- Post Creation: Share text, images, and videos
- Commenting System: Engage with other users' posts
- Post Reactions: Like and save posts
- Content Management: Edit and delete your own posts and comments

### 4. Profile Management
- Customizable user profiles
- Activity history showing your posts and comments
- Profile picture management with Firebase Storage
- Account settings and preferences
- Secure sign-out functionality

## Setup Instructions

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio or VS Code with Flutter plugins
- Firebase account
- Git

### Installation Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/BumpToBaby.git
   cd BumpToBaby
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Enable Authentication, Firestore, and Storage services
   - Add Android and iOS apps to your Firebase project
   - Download the `google-services.json` file for Android and place it in `android/app/`
   - Download the `GoogleService-Info.plist` file for iOS and place it in `ios/Runner/`

4. **Firebase Authentication Configuration**
   - In Firebase Console, go to Authentication → Sign-in methods
   - Enable Email/Password authentication

5. **Firestore Database Rules**
   Set up proper security rules for your database:
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId} {
         allow read: if request.auth != null;
         allow write: if request.auth != null && request.auth.uid == userId;
       }
       
       match /posts/{postId} {
         allow read: if request.auth != null;
         allow create: if request.auth != null;
         allow update, delete: if request.auth != null && 
                               resource.data.userId == request.auth.uid;
       }
       
       match /comments/{commentId} {
         allow read: if request.auth != null;
         allow create: if request.auth != null;
         allow update, delete: if request.auth != null && 
                               resource.data.userId == request.auth.uid;
       }
     }
   }
   ```

6. **Firebase Storage Rules**
   ```
   rules_version = '2';
   service firebase.storage {
     match /b/{bucket}/o {
       match /userProfileImages/{userId}/{allPaths=**} {
         allow read: if request.auth != null;
         allow write: if request.auth != null && request.auth.uid == userId;
       }
       
       match /postImages/{postId}/{allPaths=**} {
         allow read: if request.auth != null;
         allow write: if request.auth != null;
         allow delete: if request.auth != null && 
                       firestore.get(/databases/(default)/documents/posts/$(postId)).data.userId == request.auth.uid;
       }
     }
   }
   ```

7. **Environment Configuration**
   Create a `.env` file in the root directory with the following variables:
   ```
   GOOGLE_MAPS_API_KEY=your_google_maps_api_key
   WEATHER_API_KEY=your_weather_api_key
   ```

8. **Example google-services.json format**
   ```json
   {
     "project_info": {
       "project_number": "123456789012",
       "project_id": "bumptobaby-app",
       "storage_bucket": "bumptobaby-app.appspot.com"
     },
     "client": [
       {
         "client_info": {
           "mobilesdk_app_id": "1:123456789012:android:a1b2c3d4e5f6g7h8",
           "android_client_info": {
             "package_name": "com.example.bumptobaby"
           }
         },
         "oauth_client": [],
         "api_key": [
           {
             "current_key": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
           }
         ],
         "services": {
           "appinvite_service": {
             "other_platform_oauth_client": []
           }
         }
       }
     ],
     "configuration_version": "1"
   }
   ```

9. **Run the application**
   ```bash
   flutter run
   ```

## Database Structure

### Firestore Collections

1. **users**
   ```
   users/{userId}
   {
     userId: string,
     email: string,
     displayName: string,
     profileImageUrl: string,
     createdAt: timestamp,
     lastLogin: timestamp
   }
   ```

2. **posts**
   ```
   posts/{postId}
   {
     postId: string,
     userId: string,
     userName: string,
     userProfileImage: string,
     content: string,
     imageUrl: string (optional),
     createdAt: timestamp,
     updatedAt: timestamp,
     likeCount: number,
     commentCount: number,
     likes: {
       userId: boolean
     }
   }
   ```

3. **comments**
   ```
   comments/{commentId}
   {
     commentId: string,
     postId: string,
     userId: string,
     userName: string,
     userProfileImage: string,
     content: string,
     createdAt: timestamp,
     updatedAt: timestamp
   }
   ```

## Troubleshooting

1. **Firebase Connection Issues**
   - Verify your `google-services.json` and `.env` files are correctly configured
   - Check that your Firebase project has the correct package name
   - Ensure Firebase services (Auth, Firestore, Storage) are enabled

2. **Build Errors**
   - Run `flutter clean` followed by `flutter pub get`
   - Check for any conflicting dependencies in `pubspec.yaml`
   - Ensure you have the latest version of Flutter: `flutter upgrade`

3. **Google Maps Issues**
   - Verify your Google Maps API key is correctly set in the `.env` file
   - Ensure the Google Maps API is enabled in your Google Cloud Console

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.

## License
This project is licensed under the MIT License - see the LICENSE file for details.
# BumpToBaby

![BumpToBaby Banner](./banner.png)

## About
BumpToBaby is a mobile app that centralises all you need as a mother to help you through your pregnancy journey. It integrates AI and LLMs to provide personalised content for diet planning, health tracking as well as language support for medical knowledge.

## 🛠️ Tech Stack
| Tech         | Purpose |
|--------------|---------|
| **Flutter**   | Frontend and Backend Development |
| **Firebase**    | Authentication, Database and Storage |
| **Gemini**  | AI generated personalised content and insights |
| **Github**   | Version Control |
| **Perspective API** | Content Moderation |
| **Google Maps API**   | Map Data Integration |
| **Qwen**   | Medical Misinformation Detection |
| **PubMed API**   | Medical Data Retrieval |

## Medical Misinformation Prevention

BumpToBaby now includes a sophisticated medical misinformation detection system using Retrieval Augmented Generation (RAG) with Qwen. This system helps protect users from potentially harmful medical misinformation by:

1. **PubMed Data Integration**: The app retrieves reliable medical information from PubMed, a trusted source of medical research.

2. **Intelligent Content Moderation**: Using advanced AI technology from Qwen, the app can detect when posts contain medical information that contradicts established medical consensus.

3. **Informative Warnings**: When misinformation is detected, users see clear warning banners explaining the issue along with references to accurate medical information.

4. **Seamless Integration**: The system works alongside our existing content moderation to provide comprehensive protection against both harmful and medically inaccurate content.

### How It Works

1. When a user creates a post, the content is analyzed for medical claims
2. The system searches for relevant medical information in our database
3. If the post contradicts reliable medical information, it's flagged
4. Users see a warning banner with correct information when viewing flagged posts
### 1. User Authentication
- Secure signup and login functionality
- Email verification
- Password reset capabilities
- Profile customization with profile picture upload

### 2. Home Screen Dashboard
Eight main feature buttons providing access to:
- Vaccination Clinic Nearby: Find and navigate to nearby healthcare facilities
- Smart Health Tracker: Creates personalised health schedule by filling in health survey
- Growth & Development: Monitor pregnancy progress, symptoms, and baby development
- Audio/Visual Learning: Platform for educational videos, podcasts and audiobooks related to pregnancy and motherhood
- Nutrition & Meals: Creates personalised nutrition and meal plans based on pregnancy stage and dietary requirements
- Family Planning: Family planning trackers depending on family planning goal
- Health Help: AI assistant that answers pregnancy related questions and can be translated into different languages
- Community: Allows interaction between users to make posts sharing pregnancy progress, also has events feature to showcase upcoming events

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
- Android Studio for Emulation

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
       // User profile rules
       match /users/{userId} {
         // Allow read of any user profile
         allow read: if request.auth != null;
         // Only allow users to modify their own profile
         allow write: if request.auth != null && request.auth.uid == userId;
       }
    
       // Posts rules
       match /posts/{postId} {
  		   // Anyone logged in can read posts
  		   allow read: if request.auth != null;

  		   // Only creator can update/delete their posts (excluding likes)
  		   allow update, delete: if request.auth != null
                           && request.auth.uid == resource.data.userId
                           && !(request.resource.data.keys().hasAny(['likes']) &&
                                !(request.resource.data.likes == resource.data.likes));

  		   // Allow users to like/unlike by updating only the likes array
  		   allow update: if request.auth != null &&
                   request.resource.data.diff(resource.data).affectedKeys().hasOnly(['likes']) &&
                   request.resource.data.userId == resource.data.userId;

  		   // Anyone logged in can create posts
  		   allow create: if request.auth != null && request.auth.uid == request.resource.data.userId;
      
         // Allow others to update ONLY the commentsCount field
  		   allow update: if request.auth != null &&
                   request.resource.data.diff(resource.data).affectedKeys().hasOnly(['commentCount']);

  		   allow create: if request.auth != null && request.auth.uid == request.resource.data.userId;

  		   // Comments subcollection (unchanged)
  		   match /comments/{commentId} {
    		   allow read: if request.auth != null;

    		   // Allow comment creation only if userId is set and matches the authenticated user
    		   allow create: if request.auth != null &&
                     request.resource.data.keys().hasAll(['userId', 'content']) &&
                     request.resource.data.userId == request.auth.uid;

    		   // Allow only comment creator to update/delete their comment
    		   allow update, delete: if request.auth != null && resource.data.userId == request.auth.uid;
  			   }
		   }
    
       // Allow users to read and write their own family planning data
       match /familyPlanning/{userId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
    
       // Allow users to read and write their own health surveys
       match /health_surveys/{userId}/{document=**} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
    
       // Allow users to read and write their own health schedules
       match /health_schedules/{userId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
    
       // Default deny
       match /{document=**} {
         allow read, write: if false;
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
   ANDROID_API_KEY=YOUR_FIREBASE_ANDROID_API_KEY
   ANDROID_APP_ID=YOUR_FIREBASE_ANDROID_APP_ID
   ANDROID_SENDER_ID=YOUR_FIREBASE_ANDROID_SENDER_ID
   ANDROID_PROJECT_ID=YOUR_FIREBASE_ANDROID_PROJECT_ID
   ANDROID_STORAGE_BUCKET=YOUR_FIREBASE_ANDROID_STORAGE_BUCKET

   IOS_API_KEY=YOUR_FIREBASE_IOS_API_KEY
   IOS_APP_ID=YOUR_FIREBASE_IOS_APP_ID
   IOS_SENDER_ID=YOUR_FIREBASE_IOS_SENDER_ID
   IOS_PROJECT_ID=YOUR_FIREBASE_IOS_PROJECT_ID
   IOS_STORAGE_BUCKET=YOUR_FIREBASE_IOS_STORAGE_BUCKET
   IOS_BUNDLE_ID=YOUR_FIREBASE_IOS_BUNDLE_ID

   GOOGLE_MAPS_API_KEY=YOUR_GOOGLE_MAPS_API_KEY
   PERSPECTIVE_API_KEY=YOUR_PERSPECTIVE_API_KEY
   GEMINI_API_KEY=YOUR_GEMENI_API_KEY
   DASHSCOPE_API_KEY=YOUR_DASHSCOPE_API_KEY
   PUBMED_API_KEY=YOUR_PUBMED_API_KEY
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


## Team
- **Team Name:** [Trying Our Best]
- **Members:** [Siew Wei En], [Lee Lik Shen], [Maxwell Jared Daniel] 
- **Institution:** University of Malaya

## Contact
📧 [Siew Wei En]  
🔗 [Linkedin](https://www.linkedin.com/in/weiensiew/)

📧 [Lee Lik Shen]  
🔗 [Linkedin](linkedin.com/in/leelikshen)

📧 [Maxwell Jared Daniel]  
🔗 [Linkedin](https://www.linkedin.com/in/maxwell-jared-daniel-215927298/)

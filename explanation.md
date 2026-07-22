# Speech Therapy App: Full Project Structure & Code Explanation

This document provides a comprehensive, simple, and easy-to-understand explanation of the full project structure and the code for each file inside the `lib` folder of the Speech Therapy application. Special emphasis is given to the database functionalities (how data is stored, retrieved, and managed).

---

## 📁 1. Overall Project Structure (`lib` folder)

The `lib` folder is the heart of the Flutter application. It is organized using a clean architecture pattern to separate the User Interface (UI) from the business logic and database operations.

Here is the structure:
- **`main.dart` & `firebase_options.dart`**: The entry points of the application.
- **`models/`**: Contains the blueprint (data structures) for the data saved in the database.
- **`services/`**: Contains all the background logic, including communicating with the Firebase database, recording audio, and evaluating speech.
- **`utils/`**: Contains helpful shared code, like app themes and static lists of words/phrases.
- **`screens/`**: Contains all the visual pages (UI) that the user sees and interacts with.

---

## 🗄️ 2. Database Functionalities & Services

The application uses **Firebase** as its backend. Specifically:
- **Firebase Authentication**: For logging in users.
- **Cloud Firestore**: A NoSQL database to store user profiles, therapy assignments, and exercise results.
- **Firebase Storage**: To save the recorded audio files.

### `lib/services/firestore_service.dart` (The Database Manager)
This is the most important file for database functionalities. It handles all reading and writing to Cloud Firestore.
- **Users Collection (`users`)**:
  - `createOrUpdateUser()`: Saves a new user or updates an existing one using `SetOptions(merge: true)`.
  - `getUser()` & `userStream()`: Retrieves a user's profile once or listens to live updates.
  - `linkPatientToTherapist()`: Links a patient's account to a therapist's account so the therapist can track their progress. It updates arrays in both the therapist's and patient's database documents.
- **Exercise Results Collection (`exercise_results`)**:
  - `saveExerciseResult()`: Saves a patient's score after they complete an exercise. It also increments the `totalWordsSpoken` count in the user's profile.
  - `getTodayResults()` & `getWeeklyAverageAccuracy()`: Queries the database for results within a specific date range (using `isGreaterThanOrEqualTo` timestamps) to generate progress charts.
- **Assignments Collection (`assignments`)**:
  - `createAssignment()`: Allows therapists to assign specific phrases to patients.
  - `getPatientAssignments()`: Fetches a patient's "pending" tasks.
  - `updateAssignmentStatus()`: Marks an assignment as 'completed' and sets a completion timestamp.
- **Saved Sessions Collection (`saved_sessions`)**:
  - Allows saving a custom list of phrases for repeated practice.

### `lib/services/auth_service.dart` (Authentication)
Handles logging users in and out.
- Contains `signUpWithEmail()`, `signInWithEmail()`, and `signInWithGoogle()`.
- Whenever a new user signs up, this service automatically creates a corresponding user document in the Firestore database to store their role (patient/therapist) and name.

### `lib/services/storage_service.dart` (File Storage)
Handles saving actual files (audio recordings) to the cloud.
- `uploadAudio()`: Takes a local recording file and uploads it to Firebase Storage under `audio/userId/sessionId/fileName`.
- Returns the public download URL so it can be saved in the `exercise_results` database document.

### `lib/services/audio_service.dart` (Hardware Integration)
- Uses the device's microphone to record audio (`RecordConfig`).
- Generates a live stream of audio amplitude (volume levels) so the UI can show a cool audio waveform animation.
- Uses `FlutterTts` (Text-to-Speech) to read words aloud so patients can "Listen to the Example".

### `lib/services/speech_grading_service.dart` (AI/Logic)
- Connects to the device's Speech-to-Text engine to transcribe what the user says.
- **Grading Algorithm**: It compares the `expectedPhrase` with the `spokenPhrase`. It normalizes the text (removes punctuation, converts to lowercase) and uses a Longest Common Subsequence (LCS) algorithm to calculate a `clarity_score` from 0 to 100.

---

## 🧱 3. Data Models (`lib/models/`)

These files act as translators. They convert raw database JSON into Dart objects that are easy to use in the code, and vice versa.

- **`user_model.dart`**: Stores user information like name, email, role (patient/therapist), streak days, total words spoken, and their linked doctor/patient ID.
- **`exercise_result_model.dart`**: Stores the outcome of a single exercise. Contains the expected phrase, what the app heard, the clarity score, the AI feedback, and the link to the audio recording.
- **`assignment_model.dart`**: Represents homework given by a therapist. Contains the list of phrases to practice and the status (pending/completed).
- **`saved_session_model.dart`**: Represents a custom list of words a user has saved for quick access later.

---

## 📱 4. UI Screens (`lib/screens/`)

The screens are divided into organized sub-folders depending on their purpose. They do not contain direct database logic; instead, they call the functions inside the `services/` folder.

- **Authentication (`auth_screen.dart`, `role_selection_screen.dart`)**: Where the user signs up and chooses if they are a Patient or a Therapist.
- **Profiles (`patient_profile_setup.dart`, `therapist_profile_setup.dart`)**: Collects additional info (like clinic name or age) to complete the database profile.
- **Dashboards (`patient_dashboard.dart`, `therapist_dashboard.dart`)**: The home screens. The patient dashboard shows today's assignments and progress. The therapist dashboard shows a list of linked patients and alerts the therapist if any patient is scoring poorly.
- **Exercises (`exercises/` folder)**:
  - `phrase_practice_screen.dart`, `word_repeat_screen.dart`, `picture_naming_screen.dart`: The actual games/exercises. They use the `AudioService` to record, the `SpeechGradingService` to grade, and the `FirestoreService` to save the final score to the database.
  - `difficulty_selection_dialog.dart`: A popup allowing users to choose Easy, Medium, or Hard modes.
- **Progress (`progress/` folder)**:
  - `progress_tracker_screen.dart` & `daily_report_screen.dart`: Uses the database queries to fetch past scores and display them as beautiful charts and statistics (like streaks and average accuracy).

---

## 🛠️ 5. Utility Files (`lib/utils/`)

- **`constants.dart`**: Stores all the static data for the app. This includes the dictionary of phrases (Common, Food & Drink, Feelings), the Tongue Twisters, the emojis for the Picture Naming game, and the logic for the Hard difficulty (Sentence Chains).
- **`app_theme.dart`**: Defines the visual identity of the app. It stores the exact color codes (like `#2BCDEE`), the Google Fonts (Lexend), and the styling for buttons, cards, and text inputs so the whole app looks consistent.

---

## 🚀 6. Entry Points

- **`main.dart`**: The starting point of the app. It initializes Flutter, starts Firebase, applies the `AppTheme`, and opens the `SplashScreen`.
- **`firebase_options.dart`**: A file generated automatically by Firebase that contains the API keys needed to connect the app to the cloud servers.

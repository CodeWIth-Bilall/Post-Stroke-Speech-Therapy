# Speech Therapy Services Explanation

The `lib/services/` directory acts as the central brain of the application. The UI screens (`lib/screens/`) never talk directly to the database or hardware components. Instead, they rely on these "Services" to handle complex background operations.

Here is an explanation of every file in the `lib/services` folder, including where and why each is used within the application:

---

## 1. `firestore_service.dart`

**What it does:**
This is the database manager. It handles all interactions with Firebase Cloud Firestore. It reads and writes user profiles, manages the linking between patients and therapists, saves exercise scores, handles daily streaks, and tracks custom assignments and saved phrase sessions.

**Where it is used:**
- **`Dashboards (patient_dashboard.dart, therapist_dashboard.dart)`:** To load real-time user stats, upcoming assignments, and linked patients.
- **`Progress Screens (progress_tracker_screen.dart, daily_report_screen.dart)`:** To fetch historical results to populate charts, average scores, and track consecutive days played.
- **`Exercise Screens`:** After an exercise completes, to upload the final score and update the user's `totalWordsSpoken`.
- **`Therapist Profile setup` & `Patient Profile setup`:** To initialize and update their profile details in the database.

**Why it is used:**
By keeping all database queries in one file, the application remains organized. If the database structure changes in the future, developers only have to update this one file instead of hunting down database calls scattered across fifty different UI screens.

---

## 2. `auth_service.dart`

**What it does:**
This service handles all user authentication via Firebase Auth. It includes logic for logging in with Email/Password, signing up, signing in with Google, and logging out. It automatically communicates with `firestore_service.dart` to ensure a database document is created when a new user signs up.

**Where it is used:**
- **`auth_screen.dart`:** When the user enters their email and password to log in or register.
- **`role_selection_screen.dart`:** To save the user's selected role (therapist vs. patient) upon creating an account.
- **Settings / Drawer:** Used when the user presses the "Logout" button.

**Why it is used:**
To abstract away the complexities of Firebase Authentication. UI buttons simply call `AuthService().signInWithEmail(...)` without needing to worry about the underlying tokens, security, and error handling.

---

## 3. `audio_service.dart`

**What it does:**
This service manages device hardware: the microphone and the speaker. 
- It uses `record` package to record the user's voice into a `.wav` file.
- It generates a live stream of the audio's volume (amplitude) to power visual animations (waveforms).
- It uses `flutter_tts` (Text-to-Speech) to read text out loud.

**Where it is used:**
- **`Exercise Screens (phrase_practice_screen.dart, word_repeat_screen.dart, picture_naming_screen.dart)`:** 
  - Used when the user taps "Listen to Example" (calls the TTS functionality).
  - Used when the user holds the microphone button to start recording their speech. 
  - The live amplitude stream is fed directly into the waveform UI widget so it bounces as the user speaks.

**Why it is used:**
Managing microphone permissions, temporary file paths, and audio streaming can be messy. This file centralizes those operations so the UI only has to call simple methods like `startRecording()` or `speak("hello")`.

---

## 4. `speech_grading_service.dart`

**What it does:**
This is the "AI" component of the app. It uses the `speech_to_text` package to transcribe what the user just said through the microphone. After transcription, it runs a custom grading algorithm (using Longest Common Subsequence and fuzzy word matching) to compare the transcribed text against the expected phrase. It outputs a `clarity_score` (0 to 100) and actionable text feedback.

**Where it is used:**
- **`Exercise Screens`:** As soon as the user finishes recording their audio, this service evaluates their speech. It returns a grade and feedback which is then displayed to the user on the results popup.

**Why it is used:**
Grading speech accuracy requires complex math (Levenshtein distances, text normalization, dynamic programming matrices). This logic is completely separated into this file so the exercise screens remain lightweight and only focus on displaying the final score.

---

## 5. `storage_service.dart`

**What it does:**
This service handles uploading physical files to Firebase Cloud Storage. Once an audio file is recorded locally, this service uploads that file to the cloud and retrieves a public download URL.

**Where it is used:**
- **`Exercise Screens`:** After the user finishes speaking and the `speech_grading_service` has graded it, the local `.wav` file from `audio_service` is passed to this `storage_service` to be uploaded to Firebase. The resulting URL is then saved to the database via `firestore_service`.

**Why it is used:**
This ensures that therapists have the ability to click on a patient's historical records and listen to their exact audio recordings. The UI doesn't have to handle the heavy lifting of internet uploads, error catching, or reference path generations.

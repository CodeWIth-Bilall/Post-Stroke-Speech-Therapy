# EchoVoice — Restructuring to Provider + go_router Architecture

Refactor the fully-functional Speech Therapy (EchoVoice) application from a monolithic structure into a clean, modular architecture based on `Provider` + `go_router`, without breaking any existing functionality.

## User Review Required

> [!IMPORTANT]
> **Zero Logic Changes** — This refactoring moves and wraps existing code. No Firebase queries, grading algorithms, or UI widgets are altered. Every screen will look and behave identically after migration.

> [!WARNING]
> **New Dependencies** — This plan adds `go_router` and `provider` to `pubspec.yaml`. Please confirm these are acceptable.

> [!IMPORTANT]
> **Navigation Overhaul** — All `Navigator.push` / `Navigator.pushReplacement` calls will be replaced with `context.go()` / `context.goNamed()`. The splash screen's routing logic moves into the `go_router` redirect guard.

## Open Questions

1. **Would you like the old `lib/screens/` and `lib/services/` folders deleted** after all files are migrated, or kept as a reference until you're comfortable with the new structure?
2. **Do you want `go_router` redirect guards** to handle auth state changes in real-time (stream-based), or is the current "check-on-launch" approach sufficient?

---

## Target Folder Structure

```
lib/
├── app/
│   ├── app.dart                          # MaterialApp.router (replaces current main.dart widget)
│   └── di.dart                           # MultiProvider dependency injection
│
├── core/
│   ├── constants/
│   │   └── app_constants.dart            # ← MOVED from utils/constants.dart (no changes)
│   ├── theme/
│   │   └── app_theme.dart                # ← MOVED from utils/app_theme.dart (no changes)
│   └── router/
│       └── app_router.dart               # NEW — go_router config with redirect guards
│
├── data/
│   ├── models/
│   │   ├── user_model.dart               # ← MOVED (no changes)
│   │   ├── exercise_result_model.dart    # ← MOVED (no changes)
│   │   ├── assignment_model.dart         # ← MOVED (no changes)
│   │   └── saved_session_model.dart      # ← MOVED (no changes)
│   ├── repositories/
│   │   ├── auth_repository.dart          # NEW — wraps AuthService
│   │   ├── user_repository.dart          # NEW — wraps user CRUD from FirestoreService
│   │   ├── exercise_repository.dart      # NEW — wraps exercise results from FirestoreService
│   │   ├── assignment_repository.dart    # NEW — wraps assignments from FirestoreService
│   │   └── session_repository.dart       # NEW — wraps saved sessions from FirestoreService
│   └── services/
│       ├── auth_service.dart             # ← MOVED (no changes)
│       ├── firestore_service.dart        # ← MOVED (no changes, consumed by repos)
│       ├── audio_service.dart            # ← MOVED (no changes)
│       ├── speech_grading_service.dart   # ← MOVED (no changes)
│       └── storage_service.dart          # ← MOVED (no changes)
│
├── modules/
│   ├── splash/
│   │   └── splash_screen.dart            # ← MOVED (navigation → go_router)
│   ├── auth/
│   │   ├── view_model/
│   │   │   └── auth_view_model.dart      # NEW — extracts logic from AuthScreen
│   │   └── view/
│   │       └── auth_screen.dart          # ← MOVED (uses VM, navigation → go_router)
│   ├── onboarding/
│   │   ├── view_model/
│   │   │   ├── role_selection_vm.dart    # NEW — extracts logic from RoleSelectionScreen
│   │   │   ├── patient_setup_vm.dart     # NEW — extracts logic from PatientProfileSetup
│   │   │   └── therapist_setup_vm.dart   # NEW — extracts logic from TherapistProfileSetup
│   │   └── view/
│   │       ├── role_selection_screen.dart # ← MOVED (uses VM, navigation → go_router)
│   │       ├── patient_profile_setup.dart# ← MOVED (uses VM, navigation → go_router)
│   │       └── therapist_profile_setup.dart # ← MOVED (uses VM, navigation → go_router)
│   ├── patient/
│   │   ├── view_model/
│   │   │   └── patient_dashboard_vm.dart # NEW — extracts logic from PatientDashboard
│   │   └── view/
│   │       └── patient_dashboard.dart    # ← MOVED (uses VM, navigation → go_router)
│   ├── therapist/
│   │   ├── view_model/
│   │   │   └── therapist_dashboard_vm.dart # NEW — extracts logic from TherapistDashboard
│   │   └── view/
│   │       ├── therapist_dashboard.dart  # ← MOVED (uses VM, navigation → go_router)
│   │       └── patient_detail_page.dart  # NEW — extracted from therapist_dashboard.dart
│   ├── exercises/
│   │   ├── view_model/
│   │   │   ├── phrase_practice_vm.dart   # NEW — extracts logic from PhrasePracticeScreen
│   │   │   ├── session_practice_vm.dart  # NEW — extracts logic from SessionPracticeScreen
│   │   │   ├── word_repeat_vm.dart       # NEW — extracts logic from WordRepeatScreen
│   │   │   ├── picture_naming_vm.dart    # NEW — extracts logic from PictureNamingScreen
│   │   │   └── create_session_vm.dart    # NEW — extracts logic from CreateSessionScreen
│   │   └── view/
│   │       ├── phrase_practice_screen.dart
│   │       ├── phrase_selection_screen.dart
│   │       ├── session_practice_screen.dart
│   │       ├── word_repeat_screen.dart
│   │       ├── picture_naming_screen.dart
│   │       └── create_session_screen.dart
│   └── progress/
│       ├── view_model/
│       │   ├── daily_report_vm.dart      # NEW
│       │   └── progress_tracker_vm.dart  # NEW
│       └── view/
│           ├── daily_report_screen.dart
│           └── progress_tracker_screen.dart
│
├── firebase_options.dart                 # ← STAYS (untouched)
└── main.dart                             # MODIFIED — slim bootstrap, delegates to app/
```

---

## Proposed Changes

### Phase 1: Foundation — Core Layer & Dependencies

#### [MODIFY] [pubspec.yaml](file:///c:/Users/Rehman/Desktop/Speech_Therapy/pubspec.yaml)
- Add `provider: ^6.1.2` and `go_router: ^14.8.1` dependencies.

---

#### [NEW] `lib/core/constants/app_constants.dart`
- **Copy** contents of `lib/utils/constants.dart` verbatim.

#### [NEW] `lib/core/theme/app_theme.dart`
- **Copy** contents of `lib/utils/app_theme.dart` verbatim.

#### [NEW] `lib/core/router/app_router.dart`
- Define `GoRouter` configuration with all routes:
  - `/splash` → SplashScreen
  - `/auth` → AuthScreen
  - `/role-selection` → RoleSelectionScreen
  - `/setup/patient` → PatientProfileSetup
  - `/setup/therapist` → TherapistProfileSetup
  - `/patient` → PatientDashboard (shell route with tabs)
  - `/therapist` → TherapistDashboard (shell route with tabs)
  - `/exercises/phrase-selection` → PhraseSelectionScreen
  - `/exercises/phrase-practice` → PhrasePracticeScreen
  - `/exercises/session-practice` → SessionPracticeScreen
  - `/exercises/word-repeat` → WordRepeatScreen
  - `/exercises/picture-naming` → PictureNamingScreen
  - `/exercises/create-session` → CreateSessionScreen
  - `/progress/daily` → DailyReportScreen
  - `/progress/tracker` → ProgressTrackerScreen
  - `/therapist/patient-detail` → PatientDetailPage
  - `/therapist/assign-builder` → AssignmentBuilderPage
- **Redirect guard:** Checks `FirebaseAuth.instance.currentUser` and user doc to redirect unauthenticated users to `/auth`, users without role to `/role-selection`, etc. (mirrors current `SplashScreen._navigateToNext` logic).

---

### Phase 2: Data Layer — Models & Repositories

#### [MOVE] Models (no code changes)
| From | To |
|---|---|
| `lib/models/user_model.dart` | `lib/data/models/user_model.dart` |
| `lib/models/exercise_result_model.dart` | `lib/data/models/exercise_result_model.dart` |
| `lib/models/assignment_model.dart` | `lib/data/models/assignment_model.dart` |
| `lib/models/saved_session_model.dart` | `lib/data/models/saved_session_model.dart` |

#### [MOVE] Services (no code changes, only import path updates)
| From | To |
|---|---|
| `lib/services/auth_service.dart` | `lib/data/services/auth_service.dart` |
| `lib/services/firestore_service.dart` | `lib/data/services/firestore_service.dart` |
| `lib/services/audio_service.dart` | `lib/data/services/audio_service.dart` |
| `lib/services/speech_grading_service.dart` | `lib/data/services/speech_grading_service.dart` |
| `lib/services/storage_service.dart` | `lib/data/services/storage_service.dart` |

#### [NEW] `lib/data/repositories/auth_repository.dart`
- Thin wrapper over `AuthService`. Exposes:
  - `signInWithEmail()`, `signUpWithEmail()`, `signInWithGoogle()`, `signOut()`
  - `currentUser` getter, `authStateChanges` stream
  - `getUserRole()`, `isProfileComplete()`

#### [NEW] `lib/data/repositories/user_repository.dart`
- Delegates to `FirestoreService` user methods:
  - `getUser()`, `userStream()`, `createOrUpdateUser()`, `updateUserFields()`
  - `findUserByEmail()`, `linkPatientToTherapist()`, `getLinkedPatients()`
  - `updateStreak()`

#### [NEW] `lib/data/repositories/exercise_repository.dart`
- Delegates to `FirestoreService` exercise methods:
  - `saveExerciseResult()`, `getExerciseResults()`, `getExerciseResultsOnce()`
  - `getResultsForDateRange()`, `getTodayResults()`
  - `getWeeklyAverageAccuracy()`, `getWeeklyDailyScores()`

#### [NEW] `lib/data/repositories/assignment_repository.dart`
- Delegates to `FirestoreService` assignment methods:
  - `createAssignment()`, `getPatientAssignments()`, `updateAssignmentStatus()`
  - `getCompletedAssignments()`, `getPatientsNeedingAttention()`

#### [NEW] `lib/data/repositories/session_repository.dart`
- Delegates to `FirestoreService` session methods:
  - `saveSession()`, `getSavedSessions()`, `deleteSession()`

---

### Phase 3: State Management — ViewModels

Each ViewModel is a `ChangeNotifier` that:
- Receives repositories via constructor injection
- Holds all state that was previously in `_State` classes
- Exposes methods that UI calls (replacing inline `onPressed` logic)
- Calls `notifyListeners()` on state changes

#### [NEW] `lib/modules/auth/view_model/auth_view_model.dart`
- Extracts from `_AuthScreenState`: `_isLogin`, `_isLoading`, `_errorMessage`, `_obscurePassword`, `_submitAuth()`, `_signInWithGoogle()`, `_navigateBasedOnRole()`, `_parseError()`
- Uses `AuthRepository` and `UserRepository`

#### [NEW] `lib/modules/onboarding/view_model/role_selection_vm.dart`
- Extracts from `_RoleSelectionScreenState`: `_selectedRole`, `_isLoading`, `_continue()`
- Uses `UserRepository`

#### [NEW] `lib/modules/onboarding/view_model/patient_setup_vm.dart`
- Extracts profile setup logic (text controller values, `_saveProfile()`)
- Uses `UserRepository`

#### [NEW] `lib/modules/onboarding/view_model/therapist_setup_vm.dart`
- Extracts therapist profile setup logic
- Uses `UserRepository`

#### [NEW] `lib/modules/patient/view_model/patient_dashboard_vm.dart`
- Extracts from `_PatientDashboardState`: `_currentTab`, user data loading, `_loadUserData()`, `_loadAssignments()`, settings operations, sign-out
- Uses `UserRepository`, `ExerciseRepository`, `AssignmentRepository`, `SessionRepository`

#### [NEW] `lib/modules/therapist/view_model/therapist_dashboard_vm.dart`
- Extracts from `_TherapistDashboardState`: `_currentTab`, `_therapist`, `_patients`, `_loadTherapist()`, `_showAddPatientDialog()` logic, edit profile logic
- Uses `UserRepository`, `AuthRepository`

#### [NEW] Exercise & Progress ViewModels
- `phrase_practice_vm.dart` — recording state, grading, result saving
- `session_practice_vm.dart` — multi-phrase session flow, assignment completion
- `word_repeat_vm.dart` — word repeat state, grading
- `picture_naming_vm.dart` — picture naming state, grading
- `create_session_vm.dart` — session builder state, save to Firestore
- `daily_report_vm.dart` — date selection, loading daily results
- `progress_tracker_vm.dart` — loading weekly scores, history

---

### Phase 4: Module Migration — Screens

Each screen is **MOVED** into its module folder and refactored to:
1. Replace direct service instantiation with `context.read<ViewModel>()`
2. Replace `Navigator.push/pushReplacement` with `context.go()` / `context.goNamed()`
3. Move all business logic into the ViewModel
4. Keep **all UI widgets exactly as they are**

#### Auth Module
| From | To |
|---|---|
| `lib/screens/auth_screen.dart` | `lib/modules/auth/view/auth_screen.dart` |

#### Onboarding Module
| From | To |
|---|---|
| `lib/screens/role_selection_screen.dart` | `lib/modules/onboarding/view/role_selection_screen.dart` |
| `lib/screens/patient_profile_setup.dart` | `lib/modules/onboarding/view/patient_profile_setup.dart` |
| `lib/screens/therapist_profile_setup.dart` | `lib/modules/onboarding/view/therapist_profile_setup.dart` |

#### Splash Module
| From | To |
|---|---|
| `lib/screens/splash_screen.dart` | `lib/modules/splash/splash_screen.dart` |

> [!NOTE]
> The splash screen's `_navigateToNext()` logic is replaced by `go_router` redirect guards. The splash screen becomes a pure animation widget that shows for 2-3 seconds, then `context.go('/')` triggers the redirect.

#### Patient Module
| From | To |
|---|---|
| `lib/screens/patient_dashboard.dart` | `lib/modules/patient/view/patient_dashboard.dart` |

#### Therapist Module
| From | To |
|---|---|
| `lib/screens/therapist_dashboard.dart` | `lib/modules/therapist/view/therapist_dashboard.dart` |

> The private `_PatientDetailPage` and `_AssignmentBuilderPage` classes currently inside `therapist_dashboard.dart` will be **extracted** into separate files under `lib/modules/therapist/view/`.

#### Exercises Module
| From | To |
|---|---|
| `lib/screens/exercises/phrase_practice_screen.dart` | `lib/modules/exercises/view/phrase_practice_screen.dart` |
| `lib/screens/exercises/phrase_selection_screen.dart` | `lib/modules/exercises/view/phrase_selection_screen.dart` |
| `lib/screens/exercises/session_practice_screen.dart` | `lib/modules/exercises/view/session_practice_screen.dart` |
| `lib/screens/exercises/word_repeat_screen.dart` | `lib/modules/exercises/view/word_repeat_screen.dart` |
| `lib/screens/exercises/picture_naming_screen.dart` | `lib/modules/exercises/view/picture_naming_screen.dart` |
| `lib/screens/exercises/create_session_screen.dart` | `lib/modules/exercises/view/create_session_screen.dart` |

#### Progress Module
| From | To |
|---|---|
| `lib/screens/progress/daily_report_screen.dart` | `lib/modules/progress/view/daily_report_screen.dart` |
| `lib/screens/progress/progress_tracker_screen.dart` | `lib/modules/progress/view/progress_tracker_screen.dart` |

---

### Phase 5: App Layer & Final Wiring

#### [NEW] `lib/app/di.dart`
- Creates a `MultiProvider` that provides all repositories and shared ViewModels:
```dart
MultiProvider(
  providers: [
    Provider(create: (_) => FirestoreService()),
    Provider(create: (_) => AuthService()),
    Provider(create: (_) => AudioService()),
    Provider(create: (_) => SpeechGradingService()),
    Provider(create: (_) => StorageService()),
    ProxyProvider<FirestoreService, UserRepository>(...),
    ProxyProvider<FirestoreService, ExerciseRepository>(...),
    ProxyProvider<FirestoreService, AssignmentRepository>(...),
    ProxyProvider<FirestoreService, SessionRepository>(...),
    ProxyProvider<AuthService, AuthRepository>(...),
  ],
  child: const App(),
)
```

#### [NEW] `lib/app/app.dart`
- `MaterialApp.router` using the `GoRouter` from `app_router.dart`
- Uses `AppTheme.lightTheme`

#### [MODIFY] `lib/main.dart`
- Slim bootstrap: `Firebase.initializeApp()` → `runApp(AppDI())`
- Delegates to `app/di.dart`

---

## Execution Order

| Step | Phase | Description |
|------|-------|-------------|
| 1 | P1 | Add `provider` + `go_router` deps, `flutter pub get` |
| 2 | P1 | Create `core/` folder: constants, theme, router |
| 3 | P2 | Move models to `data/models/` |
| 4 | P2 | Move services to `data/services/` |
| 5 | P2 | Create all 5 repositories in `data/repositories/` |
| 6 | P3 | Create all ViewModels |
| 7 | P4 | Move + refactor screens into `modules/` |
| 8 | P5 | Create `app/di.dart`, `app/app.dart`, update `main.dart` |
| 9 | P5 | Delete old `lib/screens/`, `lib/services/`, `lib/utils/`, `lib/models/` |
| 10 | — | Verify: `flutter analyze`, `flutter build` |

---

## Verification Plan

### Automated Tests
```bash
flutter analyze           # Zero errors/warnings
flutter build apk --debug  # Successful build
```

### Manual Verification
- The app should launch, show splash, and route correctly based on auth state
- All exercise screens should function identically (recording, grading, saving)
- Patient and therapist dashboards should display the same data
- Navigation between all screens should work via go_router
- Sign out should redirect to auth screen

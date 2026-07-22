# EchoVoice Restructuring — Task Tracker

## Phase 1: Foundation — Core Layer & Dependencies
- [ ] Add `provider` + `go_router` to pubspec.yaml, run `flutter pub get`
- [ ] Create `lib/core/constants/app_constants.dart`
- [ ] Create `lib/core/theme/app_theme.dart`
- [ ] Create `lib/core/router/app_router.dart`

## Phase 2: Data Layer — Models & Repositories
- [ ] Move models to `lib/data/models/`
- [ ] Move services to `lib/data/services/`
- [ ] Create `lib/data/repositories/auth_repository.dart`
- [ ] Create `lib/data/repositories/user_repository.dart`
- [ ] Create `lib/data/repositories/exercise_repository.dart`
- [ ] Create `lib/data/repositories/assignment_repository.dart`
- [ ] Create `lib/data/repositories/session_repository.dart`

## Phase 3: State Management — ViewModels
- [ ] Create `auth_view_model.dart`
- [ ] Create `role_selection_vm.dart`
- [ ] Create `patient_setup_vm.dart`
- [ ] Create `therapist_setup_vm.dart`
- [ ] Create `patient_dashboard_vm.dart`
- [ ] Create `therapist_dashboard_vm.dart`
- [ ] Create exercise ViewModels (phrase, session, word, picture, create)
- [ ] Create progress ViewModels (daily_report, progress_tracker)

## Phase 4: Module Migration — Screens
- [ ] Migrate splash module
- [ ] Migrate auth module
- [ ] Migrate onboarding module (role, patient setup, therapist setup)
- [ ] Migrate patient module
- [ ] Migrate therapist module (+ extract PatientDetailPage, AssignmentBuilderPage)
- [ ] Migrate exercises module
- [ ] Migrate progress module

## Phase 5: App Layer & Final Wiring
- [ ] Create `lib/app/di.dart`
- [ ] Create `lib/app/app.dart`
- [ ] Update `lib/main.dart`
- [ ] Delete old directories

## Verification
- [ ] `flutter analyze` passes
- [ ] `flutter build apk --debug` succeeds

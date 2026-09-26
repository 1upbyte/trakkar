import 'package:flutter/foundation.dart';

import '../../models/login_details.dart';
import '../../models/setup_attempt.dart';
import 'secure_session_store.dart';
import 'traccar_auth_service.dart';

class SetupController extends ChangeNotifier {
  SetupController({
    required TraccarAuthService service,
    required SessionStore store,
  }) : _authService = service,
       _sessionStore = store;

  final TraccarAuthService _authService;
  final SessionStore _sessionStore;

  SetupAttemptState state = SetupAttemptState.choosing;
  LoginDetailsDraft? draft;
  SetupFailure? failure;
  bool hasAuthenticatedSession = false;
  bool isProceedingAnyway = false;
  bool isRestoringSession = true;
  bool get authenticationActive => state == SetupAttemptState.authenticating;

  Future<void> restoreSession() async {
    try {
      final stored = await _sessionStore.read();
      if (stored != null) await authenticate(stored.details);
    } on Object {
      // Missing secure-storage access should return the user to setup without
      // surfacing a platform exception that might contain implementation data.
    } finally {
      isRestoringSession = false;
      notifyListeners();
    }
  }

  void beginScanning() {
    if (authenticationActive) return;
    state = SetupAttemptState.scanning;
    failure = null;
    notifyListeners();
  }

  void beginManualEntry() {
    if (authenticationActive) return;
    state = SetupAttemptState.editing;
    failure = null;
    notifyListeners();
  }

  void updateDraft(LoginDetailsDraft value) {
    draft = value;
    notifyListeners();
  }

  Future<void> authenticate(LoginDetailsDraft details) async {
    if (authenticationActive || !details.hasRequiredValues) return;
    draft = details;
    failure = null;
    state = SetupAttemptState.authenticating;
    notifyListeners();

    final result = await _authService.authenticate(details);
    if (result is AuthenticationFailure) {
      failure = result.failure;
      state = result.failure.isRejectedCredentials
          ? SetupAttemptState.rejected
          : SetupAttemptState.unavailable;
      notifyListeners();
      return;
    }

    try {
      await _sessionStore.save(
        details,
        (result as AuthenticationSuccess).cookie,
      );
      hasAuthenticatedSession = true;
      draft = null;
      failure = null;
      state = SetupAttemptState.success;
    } on Object {
      failure = const SetupFailure(
        service: SetupService.manager,
        summary: 'The session could not be saved securely.',
        safeDetails: 'Secure session storage is unavailable.',
      );
      state = SetupAttemptState.unavailable;
    }
    notifyListeners();
  }

  Future<void> retry() async {
    final current = draft;
    if (authenticationActive || current == null) return;
    isProceedingAnyway = false;
    await authenticate(current);
  }

  void backToEditing() {
    if (authenticationActive) return;
    state = SetupAttemptState.editing;
    failure = null;
    isProceedingAnyway = false;
    notifyListeners();
  }

  void proceedAnyway() {
    if (authenticationActive) return;
    isProceedingAnyway = true;
    state = SetupAttemptState.proceeding;
    notifyListeners();
  }

  void abandonSetup() {
    if (authenticationActive) return;
    draft = null;
    failure = null;
    state = SetupAttemptState.choosing;
    notifyListeners();
  }

  void resetToFirstRun() {
    hasAuthenticatedSession = false;
    isProceedingAnyway = false;
    isRestoringSession = false;
    draft = null;
    failure = null;
    state = SetupAttemptState.choosing;
    notifyListeners();
  }

  @override
  void dispose() {
    _authService.close();
    super.dispose();
  }
}

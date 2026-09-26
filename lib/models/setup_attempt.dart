enum SetupAttemptState {
  choosing,
  scanning,
  editing,
  authenticating,
  success,
  rejected,
  unavailable,
  proceeding,
  canceled,
}

enum SetupService { manager, client, camera, location }

class SetupFailure {
  const SetupFailure({
    required this.service,
    required this.summary,
    this.safeDetails,
    this.isRejectedCredentials = false,
  });

  final SetupService service;
  final String summary;
  final String? safeDetails;
  final bool isRejectedCredentials;
}

class SetupAttempt {
  const SetupAttempt({required this.state, this.failure, this.details});

  final SetupAttemptState state;
  final SetupFailure? failure;
  final Object? details;
}

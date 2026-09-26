enum ResetStatus {
  idle,
  confirming,
  stoppingTracking,
  clearingLocalConfig,
  complete,
  failed,
  canceled,
}

class ResetRequest {
  const ResetRequest({this.status = ResetStatus.idle, this.failureMessage});

  final ResetStatus status;
  final String? failureMessage;

  bool get isActive =>
      status == ResetStatus.stoppingTracking ||
      status == ResetStatus.clearingLocalConfig;
}

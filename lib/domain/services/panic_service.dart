class PanicReport {
  const PanicReport({required this.sessionsDestroyed});

  final int sessionsDestroyed;
}

/// Runs the panic sequence. Order is the whole design:
///
/// 1. close every live session
/// 2. destroy the data keys and the device key
/// 3. delete the store files
/// 4. lock
///
/// Step 2 is the irreversible one. Step 3 is cleanup, and if the process is
/// killed between them the data is already unrecoverable — which is what lets
/// `3c` report in the past tense without lying.
abstract interface class PanicService {
  Future<PanicReport> trigger();
}

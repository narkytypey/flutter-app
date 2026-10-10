import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/android_flip_service.dart';
import '../../../../domain/services/flip_service.dart';
import '../../container/view_models/providers.dart' show panic;
import '../../settings/view_models/providers.dart' show panicOnFlipProvider;

final flipServiceProvider = Provider<FlipService>((ref) => AndroidFlipService());

/// Settings' "Trigger by flipping face down" (user's ruling, 2026-09-30).
/// `AppGate` puts this around the open vault, so it exists exactly while a
/// vault is open: while that vault's switch is on, the accelerometer is
/// listened to, and a flip runs [panic], with no confirmation. Leaving the
/// vault, or turning the switch off, stops it.
///
/// Since the user's rulings of 2026-10-10 this is the only way to start a
/// panic (the container's panic buttons are gone), and the switch is on in
/// a vault that never set it.
class FlipPanicGuard extends ConsumerStatefulWidget {
  const FlipPanicGuard({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FlipPanicGuard> createState() => _FlipPanicGuardState();
}

class _FlipPanicGuardState extends ConsumerState<FlipPanicGuard> {
  late final FlipService _service = ref.read(flipServiceProvider);
  StreamSubscription<void>? _flips;
  bool _panicking = false;

  void _listen(bool on) {
    if (on && _flips == null) {
      _flips = _service.flips.listen((_) => _panic());
      unawaited(_service.start());
    } else if (!on && _flips != null) {
      _stop();
    }
  }

  void _stop() {
    unawaited(_flips?.cancel());
    _flips = null;
    unawaited(_service.stop());
  }

  Future<void> _panic() async {
    if (_panicking || !mounted) return;
    _panicking = true;
    await panic(ref);
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<bool>>(
      panicOnFlipProvider,
      (_, next) => _listen(next.valueOrNull ?? false),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    if (_flips != null) _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

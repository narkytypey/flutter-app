import 'site.dart';

enum OpenStepState { pending, running, done }

/// One line of spec `8a`'s checklist.
class OpenStep {
  const OpenStep(this.label, this.state);

  final String label;
  final OpenStepState state;

  OpenStep withState(OpenStepState next) => OpenStep(label, next);
}

/// The checklist `8a` shows, built from what this site actually applies. Copy
/// is verbatim from the spec; the tunnel line interpolates the real endpoint.
/// [torPercent] is Tor's last reported percentage (built-in Tor spec §7).
List<OpenStep> openStepsFor(Site site, {int? torPercent}) {
  return <OpenStep>[
    const OpenStep('Fresh session, no shared cookies', OpenStepState.pending),
    if (site.blockTrackers)
      const OpenStep('Filter lists loaded', OpenStepState.pending),
    if (site.antiFingerprinting)
      const OpenStep('Fingerprint noise injected', OpenStepState.pending),
    if (site.proxyMode == ProxyMode.tor)
      OpenStep(torStepLabel(torPercent), OpenStepState.pending)
    else if (site.proxyMode != ProxyMode.direct)
      OpenStep('Connecting through ${site.proxyHost}:${site.proxyPort}',
          OpenStepState.pending),
  ];
}

/// Built-in Tor spec §7: Tor's own percentage while it starts. None before
/// its first report, at 0, or at 100, which is a start already over (perhaps
/// an earlier one).
String torStepLabel(int? percent) => percent == null || percent <= 0 || percent >= 100
    ? 'Connecting to Tor'
    : 'Connecting to Tor · $percent%';

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
List<OpenStep> openStepsFor(Site site) {
  return <OpenStep>[
    const OpenStep('Fresh session, no shared cookies', OpenStepState.pending),
    if (site.blockTrackers)
      const OpenStep('Filter lists loaded', OpenStepState.pending),
    if (site.antiFingerprinting)
      const OpenStep('Fingerprint noise injected', OpenStepState.pending),
    if (site.proxyMode != ProxyMode.direct)
      OpenStep('Connecting through ${site.proxyHost}:${site.proxyPort}',
          OpenStepState.pending),
  ];
}

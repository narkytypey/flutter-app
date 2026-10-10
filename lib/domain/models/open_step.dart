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
///
/// [applied] is whether the container's own `open` has returned: by then the
/// fresh profile, the filter engine and the document-start scripts are all in
/// place natively, so every line but the last is done, and the last (the
/// tunnel, or the session itself on a direct site) runs until the first load
/// reports live, as the spec draws it. Before that the first line runs.
List<OpenStep> openStepsFor(Site site, {int? torPercent, bool applied = false}) {
  final labels = <String>[
    'Fresh session, no shared cookies',
    if (site.blockTrackers) 'Filter lists loaded',
    if (site.antiFingerprinting) 'Fingerprint noise injected',
    if (site.proxyMode == ProxyMode.tor)
      torStepLabel(torPercent)
    else if (site.proxyMode != ProxyMode.direct)
      'Connecting through ${site.proxyHost}:${site.proxyPort}',
  ];
  final last = labels.length - 1;
  return <OpenStep>[
    for (var i = 0; i < labels.length; i++)
      OpenStep(
        labels[i],
        applied
            ? (i < last ? OpenStepState.done : OpenStepState.running)
            : (i == 0 ? OpenStepState.running : OpenStepState.pending),
      ),
  ];
}

/// Built-in Tor spec §7: Tor's own percentage while it starts. None before
/// its first report, at 0, or at 100, which is a start already over (perhaps
/// an earlier one).
String torStepLabel(int? percent) => percent == null || percent <= 0 || percent >= 100
    ? 'Connecting to Tor'
    : 'Connecting to Tor · $percent%';

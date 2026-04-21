/// Seconds remaining on the active step of a countdown board.
///
/// Uses **ceil of fractional remaining** — the `3..2..1..go` cadence. For
/// `dur=5` the active marble reads `5, 4, 3, 2, 1` each for ~1s, then the
/// countdown `Timer` fires at `elapsed=5s` and auto-advances; the live
/// display never renders `0`. Instead, the just-completed marble's painter
/// branch (`isDone → shown = 0`) paints `0` on the next frame, so the
/// transition is `1` (active, last second) → `0` (done) at advance.
///
/// The key property is **consistency**: the marble label
/// (`_countdownRemainingForActive`) and the overlay chip
/// (`_TimerOverlay` step text) both route through this, so they can't drift
/// by one like they used to when each rounded the remainder independently.
int countdownRemainingSeconds({
  required int durationSeconds,
  required Duration elapsed,
}) {
  final remainingMs = durationSeconds * 1000 - elapsed.inMilliseconds;
  if (remainingMs <= 0) return 0;
  return (remainingMs + 999) ~/ 1000;
}

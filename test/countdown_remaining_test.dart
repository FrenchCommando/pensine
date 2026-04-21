import 'package:flutter_test/flutter_test.dart';
import 'package:pensine/behavior/countdown_remaining.dart';

/// The pure helper behind the countdown marble label and the timer overlay
/// step chip. Both call sites previously rounded the remainder independently
/// and drifted by one — marble showed `5` while overlay showed `4s`
/// simultaneously. Now both route through this helper.
///
/// Convention: **ceil of fractional remaining** — the `3..2..1..go` cadence.
/// For `dur=5` the display reads `5, 4, 3, 2, 1` each for ~1s, then the
/// countdown `Timer` fires at `elapsed=5s` and auto-advances (live `0` never
/// renders). The just-completed marble's painter paints `0` on the next
/// frame via the `isDone` branch, so the transition is `1 → 0` at advance.
void main() {
  group('countdownRemainingSeconds', () {
    test('at step start (elapsed=0) returns full duration', () {
      expect(
        countdownRemainingSeconds(
          durationSeconds: 5,
          elapsed: Duration.zero,
        ),
        5,
      );
    });

    test('full duration is visible for the whole first second (ceil)', () {
      for (final ms in [0, 1, 250, 500, 999]) {
        expect(
          countdownRemainingSeconds(
            durationSeconds: 5,
            elapsed: Duration(milliseconds: ms),
          ),
          5,
          reason: 'elapsed=${ms}ms should still show 5',
        );
      }
    });

    test('decrements at each integer-second boundary', () {
      expect(
        countdownRemainingSeconds(
          durationSeconds: 5,
          elapsed: const Duration(seconds: 1),
        ),
        4,
      );
      expect(
        countdownRemainingSeconds(
          durationSeconds: 5,
          elapsed: const Duration(milliseconds: 1500),
        ),
        4,
      );
      expect(
        countdownRemainingSeconds(
          durationSeconds: 5,
          elapsed: const Duration(seconds: 4),
        ),
        1,
      );
    });

    test('shows 1 for the final second — advance takes over at 5s', () {
      for (final ms in [4000, 4001, 4500, 4999]) {
        expect(
          countdownRemainingSeconds(
            durationSeconds: 5,
            elapsed: Duration(milliseconds: ms),
          ),
          1,
          reason: 'elapsed=${ms}ms is in the final second, should show 1',
        );
      }
    });

    test('clamps to 0 when elapsed meets or exceeds duration', () {
      expect(
        countdownRemainingSeconds(
          durationSeconds: 5,
          elapsed: const Duration(seconds: 5),
        ),
        0,
      );
      expect(
        countdownRemainingSeconds(
          durationSeconds: 5,
          elapsed: const Duration(seconds: 100),
        ),
        0,
      );
    });
  });
}

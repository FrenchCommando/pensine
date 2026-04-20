import '../models/board.dart';

/// Per-board-type tap rules, factored out of `BoardScreen` so the state
/// machine is a pure function — testable in isolation, no widget tree or
/// tickers needed. The screen still owns side effects (haptics, timer
/// lifecycle, persistence); the outcome describes what it should do.
///
/// Adding a new board type: add one case to `applyBoardTap`. Everything
/// else (column choice, icon, sequential/net predicates) lives either on
/// `BoardTypeX` in `board.dart` or is data-driven off `isSequential`.

/// Describes what should happen after a tap. Pure data.
class BoardTapOutcome {
  /// Whether the board model was mutated and needs persisting.
  final bool changed;

  /// A lap to append to `board.laps`, or null.
  final Lap? addLap;

  /// Timer lifecycle instruction for timer/countdown boards, or null.
  final TimerCommand? timer;

  /// Haptics the screen should fire in order.
  final List<HapticCue> haptics;

  const BoardTapOutcome({
    this.changed = false,
    this.addLap,
    this.timer,
    this.haptics = const [],
  });

  static const noop = BoardTapOutcome();
}

/// Timer lifecycle transitions a sequential tap can request.
enum TimerCommand {
  /// Rewound to start — cancel tickers, clear start times.
  stop,

  /// Advanced forward — ensure tickers running, update step start.
  startOrContinue,

  /// Completed all steps — cancel tickers but keep start time for overlay.
  freeze,
}

/// Haptic cues. Names mirror `HapticFeedback` methods; the screen maps.
enum HapticCue { selectionClick, lightImpact, mediumImpact }

/// Apply a tap on [item] using [board]'s semantics. Mutates [board] in
/// place. Returns an outcome the screen consumes for side effects.
///
/// [stepStart] is the time the currently-active sequential step started —
/// used to compute lap elapsed. [now] is injectable for tests; defaults
/// to `DateTime.now()`.
BoardTapOutcome applyBoardTap({
  required Board board,
  required BoardItem item,
  DateTime? stepStart,
  DateTime Function()? now,
}) {
  // Defensive: don't mutate an item that's not part of this board. Prevents
  // caller-side bugs from silently toggling/ordering orphans.
  if (!board.items.contains(item)) return BoardTapOutcome.noop;

  switch (board.type) {
    case BoardType.thoughts:
    case BoardType.flashcards:
      // Tap is a no-op at the model level. Thoughts expand in-place;
      // flashcards flip — both are handled by `MarbleBoard` visual state
      // without touching `Board`.
      return BoardTapOutcome.noop;

    case BoardType.todo:
      item.done = !item.done;
      return const BoardTapOutcome(changed: true);

    case BoardType.checklist:
    case BoardType.timer:
    case BoardType.countdown:
      return _applySequentialTap(
        board: board,
        item: item,
        stepStart: stepStart,
        now: now ?? DateTime.now,
      );
  }
}

BoardTapOutcome _applySequentialTap({
  required Board board,
  required BoardItem item,
  required DateTime? stepStart,
  required DateTime Function() now,
}) {
  final items = board.items;
  final tappedIndex = items.indexOf(item);
  if (tappedIndex < 0) return BoardTapOutcome.noop;

  final nextIndex = items.indexWhere((i) => !i.done);
  // If the tapped item IS the active step, advance past it. Otherwise jump
  // to tapped position (rewind or leapfrog).
  final targetDone =
      (tappedIndex == nextIndex) ? tappedIndex + 1 : tappedIndex;

  // Lap append: only when genuinely advancing past the active step, and
  // only for steps beyond index 0. Index 0 is the "Start" sentinel —
  // arms the clock but is never logged. Rewinds (targetDone <= nextIndex)
  // preserve existing laps; freshly-leapfrogged steps didn't have a real
  // elapsed, so they're not logged either.
  Lap? addLap;
  if (targetDone > nextIndex && nextIndex > 0 && stepStart != null) {
    final activeItem = items[nextIndex];
    addLap = Lap(
      itemId: activeItem.id,
      elapsedSeconds: now().difference(stepStart).inSeconds,
    );
    board.laps.add(addLap);
  }

  // Mutate done flags: everything before targetDone done, rest undone.
  for (var i = 0; i < items.length; i++) {
    items[i].done = i < targetDone;
  }

  // Haptics.
  final haptics = <HapticCue>[HapticCue.selectionClick];
  final completedAll = targetDone == items.length && targetDone > nextIndex;
  if (completedAll) haptics.add(HapticCue.mediumImpact);

  // Timer lifecycle (timer/countdown boards only).
  TimerCommand? timer;
  if (board.type == BoardType.timer || board.type == BoardType.countdown) {
    if (targetDone == 0) {
      timer = TimerCommand.stop;
    } else if (completedAll) {
      timer = TimerCommand.freeze;
    } else {
      timer = TimerCommand.startOrContinue;
    }
  }

  return BoardTapOutcome(
    changed: true,
    addLap: addLap,
    timer: timer,
    haptics: haptics,
  );
}

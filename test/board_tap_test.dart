import 'package:flutter_test/flutter_test.dart';
import 'package:pensine/behavior/board_tap.dart';
import 'package:pensine/models/board.dart';

/// Tests the pure tap state machine extracted from BoardScreen. These were
/// previously only testable via widget-pumping the full BoardScreen
/// (`test/board_screen_interactions_test.dart`). Now they run as unit
/// tests in ~ms each — no widgets, no tickers, no wakelock mock.

void main() {
  group('Thoughts & flashcards', () {
    test('tap is a no-op', () {
      for (final type in [BoardType.thoughts, BoardType.flashcards]) {
        final board = Board(name: 'x', type: type, items: [
          BoardItem(content: 'a'),
          BoardItem(content: 'b'),
        ]);
        final outcome = applyBoardTap(board: board, item: board.items[0]);
        expect(outcome.changed, false);
        expect(outcome.haptics, isEmpty);
        expect(outcome.timer, isNull);
        expect(board.items.every((i) => !i.done), true);
      }
    });
  });

  group('Todo', () {
    test('tap toggles done', () {
      final board = Board(name: 'x', type: BoardType.todo, items: [
        BoardItem(content: 'a'),
      ]);
      applyBoardTap(board: board, item: board.items[0]);
      expect(board.items[0].done, true);
      applyBoardTap(board: board, item: board.items[0]);
      expect(board.items[0].done, false);
    });
  });

  group('Sequential: checklist', () {
    Board make() => Board(name: 'x', type: BoardType.checklist, items: [
          BoardItem(content: 'first'),
          BoardItem(content: 'second'),
          BoardItem(content: 'third'),
        ]);

    test('tapping the next-undone item advances', () {
      final b = make();
      final out = applyBoardTap(board: b, item: b.items[0]);
      expect(b.items[0].done, true);
      expect(b.items[1].done, false);
      expect(b.items[2].done, false);
      expect(out.haptics, contains(HapticCue.selectionClick));
    });

    test('tapping forward jumps (marks everything before done)', () {
      final b = make();
      applyBoardTap(board: b, item: b.items[2]);
      expect(b.items[0].done, true);
      expect(b.items[1].done, true);
      expect(b.items[2].done, false);
    });

    test('tapping backward rewinds to before that item', () {
      final b = make();
      b.items[0].done = true;
      b.items[1].done = true;
      applyBoardTap(board: b, item: b.items[0]);
      expect(b.items.every((i) => !i.done), true);
    });

    test('completing all fires mediumImpact haptic', () {
      final b = make();
      b.items[0].done = true;
      b.items[1].done = true;
      final out = applyBoardTap(board: b, item: b.items[2]);
      expect(b.items.every((i) => i.done), true);
      expect(out.haptics, contains(HapticCue.mediumImpact));
    });

    test('checklist never commands a timer (that is timer/countdown only)', () {
      final b = make();
      final out = applyBoardTap(board: b, item: b.items[0]);
      expect(out.timer, isNull);
    });
  });

  group('Sequential: timer (lap logging)', () {
    Board make() => Board(name: 'x', type: BoardType.timer, items: [
          BoardItem(content: 'Start'), // index 0 — arms the clock, never logs
          BoardItem(content: 'A'),
          BoardItem(content: 'B'),
        ]);

    test('advancing past index 0 does NOT log a lap', () {
      final b = make();
      final out = applyBoardTap(
        board: b,
        item: b.items[0],
        stepStart: DateTime.now().subtract(const Duration(seconds: 5)),
      );
      expect(out.addLap, isNull);
      expect(b.laps, isEmpty);
    });

    test('advancing past an intermediate step logs a lap', () {
      final b = make();
      b.items[0].done = true; // passed the start sentinel
      final stepStart = DateTime.now().subtract(const Duration(seconds: 10));
      final out = applyBoardTap(
        board: b,
        item: b.items[1],
        stepStart: stepStart,
      );
      expect(out.addLap, isNotNull);
      expect(out.addLap!.itemId, b.items[1].id);
      expect(out.addLap!.elapsedSeconds, 10);
      expect(b.laps.length, 1);
    });

    test('rewinding to start preserves laps, commands stop', () {
      final b = make();
      b.items[0].done = true;
      b.items[1].done = true;
      b.laps.add(Lap(itemId: b.items[1].id, elapsedSeconds: 5));
      final out = applyBoardTap(board: b, item: b.items[0]);
      expect(out.timer, TimerCommand.stop);
      expect(b.laps.length, 1); // preserved
      expect(b.items.every((i) => !i.done), true);
    });

    test('completing all commands freeze', () {
      final b = make();
      b.items[0].done = true;
      b.items[1].done = true;
      final out = applyBoardTap(
        board: b,
        item: b.items[2],
        stepStart: DateTime.now().subtract(const Duration(seconds: 3)),
      );
      expect(out.timer, TimerCommand.freeze);
    });

    test('mid-advance commands startOrContinue', () {
      final b = make();
      b.items[0].done = true;
      final out = applyBoardTap(
        board: b,
        item: b.items[1],
        stepStart: DateTime.now().subtract(const Duration(seconds: 2)),
      );
      expect(out.timer, TimerCommand.startOrContinue);
    });

    test('leapfrog (no stepStart) does not log a lap', () {
      final b = make();
      b.items[0].done = true;
      // Jump past the active step 1 to step 2, without providing stepStart.
      final out = applyBoardTap(board: b, item: b.items[2], stepStart: null);
      expect(out.addLap, isNull);
      expect(b.laps, isEmpty);
    });
  });

  group('Edge cases', () {
    test('item not in board is a no-op (no crash, no mutation)', () {
      final board = Board(name: 'x', type: BoardType.todo, items: [
        BoardItem(content: 'a'),
      ]);
      final orphan = BoardItem(content: 'not in this board');

      final out = applyBoardTap(board: board, item: orphan);

      expect(out.changed, false);
      expect(out.haptics, isEmpty);
      expect(board.items[0].done, false);
    });

    test('empty items list: indexOf returns -1, no-op', () {
      final board = Board(name: 'x', type: BoardType.checklist, items: []);
      final orphan = BoardItem(content: 'anything');
      final out = applyBoardTap(board: board, item: orphan);
      expect(out.changed, false);
      expect(out.timer, isNull);
    });
  });

  group('Sequential: countdown shares timer semantics', () {
    test('commands startOrContinue on mid-advance', () {
      final b = Board(name: 'x', type: BoardType.countdown, items: [
        BoardItem(content: 'Warm-up'),
        BoardItem(content: 'Round 1', durationSeconds: 20),
        BoardItem(content: 'Rest', durationSeconds: 10),
      ]);
      b.items[0].done = true;
      final out = applyBoardTap(
        board: b,
        item: b.items[1],
        stepStart: DateTime.now(),
      );
      expect(out.timer, TimerCommand.startOrContinue);
    });
  });
}

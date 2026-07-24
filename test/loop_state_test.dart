import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/features/journey/loop_state.dart';

/// Pins LoopState's phase-progression rules and the exact Window 2/3
/// boundaries from CLAUDE.md / PRD §7: Window 2 is day 5-7 inclusive,
/// Window 3 opens day 21 with no close.
void main() {
  DateTime day(int n) => DateTime(2026, 1, n);

  LoopState computeAt({
    required int startDay,
    required int nowDay,
    bool loopComplete = false,
    bool hasPhase2View = false,
    bool hasPhase3Drill = false,
    bool hasPhase4Session = false,
    bool hasWindow2Reassessment = false,
    bool hasWindow3Reassessment = false,
  }) {
    return LoopState.compute(
      loopStartedAt: day(startDay),
      loopComplete: loopComplete,
      hasPhase2View: hasPhase2View,
      hasPhase3Drill: hasPhase3Drill,
      hasPhase4Session: hasPhase4Session,
      hasWindow2Reassessment: hasWindow2Reassessment,
      hasWindow3Reassessment: hasWindow3Reassessment,
      now: day(nowDay),
    );
  }

  group('noActiveLoop', () {
    test('phase is assessment with no windows open', () {
      final state = LoopState.noActiveLoop();
      expect(state.currentPhase, JourneyPhase.assessment);
      expect(state.loopDay, 0);
      expect(state.window2Open, isFalse);
      expect(state.window3Open, isFalse);
    });
  });

  group('loopDay', () {
    test('day 1 is the start day itself', () {
      expect(computeAt(startDay: 1, nowDay: 1).loopDay, 1);
    });

    test('day 5 is four calendar days after start', () {
      expect(computeAt(startDay: 1, nowDay: 5).loopDay, 5);
    });
  });

  group('window2Open boundaries (day 5-7 inclusive)', () {
    test('day 4 is closed', () {
      expect(computeAt(startDay: 1, nowDay: 4).window2Open, isFalse);
    });
    test('day 5 is open', () {
      expect(computeAt(startDay: 1, nowDay: 5).window2Open, isTrue);
    });
    test('day 7 is open', () {
      expect(computeAt(startDay: 1, nowDay: 7).window2Open, isTrue);
    });
    test('day 8 is closed', () {
      expect(computeAt(startDay: 1, nowDay: 8).window2Open, isFalse);
    });
  });

  group('window3Open boundaries (day 21+, no close)', () {
    test('day 20 is closed', () {
      expect(computeAt(startDay: 1, nowDay: 20).window3Open, isFalse);
    });
    test('day 21 is open', () {
      expect(computeAt(startDay: 1, nowDay: 21).window3Open, isTrue);
    });
    test('day 40 is still open', () {
      expect(computeAt(startDay: 1, nowDay: 40).window3Open, isTrue);
    });
  });

  group('currentPhase progression', () {
    test('no phase2 view yet -> dashboard', () {
      expect(computeAt(startDay: 1, nowDay: 1).currentPhase, JourneyPhase.dashboard);
    });

    test('phase2 view exists, no drill -> drill', () {
      expect(
        computeAt(startDay: 1, nowDay: 1, hasPhase2View: true).currentPhase,
        JourneyPhase.drill,
      );
    });

    test('drill done, no track session -> track', () {
      expect(
        computeAt(
          startDay: 1,
          nowDay: 1,
          hasPhase2View: true,
          hasPhase3Drill: true,
        ).currentPhase,
        JourneyPhase.track,
      );
    });

    test('track session started, window2 not yet open -> track', () {
      expect(
        computeAt(
          startDay: 1,
          nowDay: 2,
          hasPhase2View: true,
          hasPhase3Drill: true,
          hasPhase4Session: true,
        ).currentPhase,
        JourneyPhase.track,
      );
    });

    test('window2 open and unanswered -> window2, even mid-track', () {
      expect(
        computeAt(
          startDay: 1,
          nowDay: 6,
          hasPhase2View: true,
          hasPhase3Drill: true,
          hasPhase4Session: true,
        ).currentPhase,
        JourneyPhase.window2,
      );
    });

    test('window2 answered, window3 not open -> track', () {
      expect(
        computeAt(
          startDay: 1,
          nowDay: 10,
          hasPhase2View: true,
          hasPhase3Drill: true,
          hasPhase4Session: true,
          hasWindow2Reassessment: true,
        ).currentPhase,
        JourneyPhase.track,
      );
    });

    test('window3 open -> window3, regardless of window2 state', () {
      expect(
        computeAt(
          startDay: 1,
          nowDay: 21,
          hasPhase2View: true,
          hasPhase3Drill: true,
          hasPhase4Session: true,
          hasWindow2Reassessment: true,
        ).currentPhase,
        JourneyPhase.window3,
      );
    });

    test('window3 answered -> complete', () {
      expect(
        computeAt(
          startDay: 1,
          nowDay: 21,
          hasWindow3Reassessment: true,
        ).currentPhase,
        JourneyPhase.complete,
      );
    });

    test('loop marked complete -> complete regardless of day', () {
      expect(
        computeAt(startDay: 1, nowDay: 2, loopComplete: true).currentPhase,
        JourneyPhase.complete,
      );
    });

    test(
      'loop marked complete via true_ascension still reaches window3 at day 21',
      () {
        expect(
          computeAt(startDay: 1, nowDay: 21, loopComplete: true).currentPhase,
          JourneyPhase.window3,
        );
      },
    );

    test(
      'loop marked complete AND window3 answered -> complete, not window3 again',
      () {
        expect(
          computeAt(
            startDay: 1,
            nowDay: 21,
            loopComplete: true,
            hasWindow3Reassessment: true,
          ).currentPhase,
          JourneyPhase.complete,
        );
      },
    );
  });
}

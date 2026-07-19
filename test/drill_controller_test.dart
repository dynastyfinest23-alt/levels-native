import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/features/drill/drill_controller.dart';
import 'package:levels_native/features/drill/drill_tokens.dart';

/// Records call order without touching Supabase, so
/// [DrillController.submit]'s save -> RPC -> read-back contract can be
/// pinned by a fake client (PRD M3.4 done-when). Models the production
/// `one_drill_per_loop` constraint (verified 2026-07-19): one row per loop,
/// updated in place on repeat saves.
class _FakeDrillDataSource implements DrillDataSource {
  final List<String> calls = [];
  final Map<String, Map<String, dynamic>> rowsByLoop = {};
  int _nextId = 1;

  @override
  Future<String> fetchBridgeQuestion(String loopId) async {
    calls.add('fetchBridgeQuestion');
    return 'What would it mean to let this be enough?';
  }

  @override
  Future<int?> fetchDeepestLayer(String loopId) async {
    calls.add('fetchDeepestLayer');
    return rowsByLoop[loopId]?['deepening_layer'] as int?;
  }

  @override
  Future<String> saveDrill({
    required String loopId,
    required OriginType originType,
    required OriginDomain originDomain,
    required CopingMechanism copingMechanism,
    required String q1FreeText,
    required String q2FreeText,
    required String q3FreeText,
    required int deepeningLayer,
  }) async {
    final existing = rowsByLoop[loopId];
    calls.add(existing == null ? 'insertDrill' : 'updateDrill');
    final id = existing?['id'] as String? ?? 'drill-${_nextId++}';
    rowsByLoop[loopId] = {
      'id': id,
      'loop_id': loopId,
      'q1_origin_type': originType.token,
      'q2_domain': originDomain.token,
      'q3_mechanism': copingMechanism.token,
      'q1_free_text': q1FreeText,
      'q2_free_text': q2FreeText,
      'q3_free_text': q3FreeText,
      'deepening_layer': deepeningLayer,
    };
    return id;
  }

  @override
  Future<void> processDrill(String drillId) async {
    calls.add('processDrill:$drillId');
  }

  @override
  Future<AscensionTrack> fetchAssignedTrack(String drillId) async {
    calls.add('fetchAssignedTrack:$drillId');
    return AscensionTrack.embodiment;
  }
}

DrillController _completedController(_FakeDrillDataSource fake, {String loopId = 'loop-1'}) {
  final controller = DrillController(loopId: loopId, dataSource: fake);
  controller
    ..selectOriginType(OriginType.childhoodConditioning)
    ..selectOriginDomain(OriginDomain.adequacyImpostor)
    ..selectCopingMechanism(CopingMechanism.collapseShutdown)
    ..setQ1FreeText('It started early.')
    ..setQ2FreeText('It shows up at work.')
    ..setQ3FreeText('I shut down.');
  return controller;
}

void main() {
  group('DrillController.submit', () {
    test('submits in insert -> process -> read-back order', () async {
      final fake = _FakeDrillDataSource();
      final controller = _completedController(fake);

      final result = await controller.submit();

      expect(fake.calls, ['insertDrill', 'processDrill:drill-1', 'fetchAssignedTrack:drill-1']);
      expect(result.drillId, 'drill-1');
      expect(result.assignedTrack, AscensionTrack.embodiment);
    });

    test('passes the loop id, answers, and deepening layer through to '
        'saveDrill', () async {
      final fake = _FakeDrillDataSource();
      final controller = _completedController(fake, loopId: 'loop-7');

      await controller.submit();

      final row = fake.rowsByLoop['loop-7']!;
      expect(row['q1_origin_type'], 'childhood_conditioning');
      expect(row['q2_domain'], 'adequacy_impostor');
      expect(row['q3_mechanism'], 'collapse_shutdown');
      expect(row['deepening_layer'], 1);
    });

    test("a repeat save updates the loop's one row instead of inserting a "
        'second (one_drill_per_loop, verified 2026-07-19)', () async {
      final fake = _FakeDrillDataSource();
      final first = _completedController(fake);
      await first.submit();

      final second = _completedController(fake);
      await second.submit();

      expect(fake.rowsByLoop.length, 1);
      expect(fake.calls.where((c) => c == 'insertDrill').length, 1);
      expect(fake.calls, contains('updateDrill'));
    });

    test('throws and never calls the data source when incomplete', () async {
      final fake = _FakeDrillDataSource();
      final controller = DrillController(loopId: 'loop-1', dataSource: fake);

      await expectLater(controller.submit(), throwsStateError);
      expect(fake.calls, isEmpty);
    });

    test('submitting flips false again after a failed submit', () async {
      final fake = _FakeDrillDataSource();
      final controller = DrillController(loopId: 'loop-1', dataSource: fake);

      await expectLater(controller.submit(), throwsStateError);
      expect(controller.submitting, isFalse);
    });
  });

  group('DrillController.load', () {
    test('fetches and exposes the bridge question, clearing loading', () async {
      final fake = _FakeDrillDataSource();
      final controller = DrillController(loopId: 'loop-1', dataSource: fake);

      await controller.load();

      expect(fake.calls, ['fetchBridgeQuestion']);
      expect(controller.bridgeQuestion, 'What would it mean to let this be enough?');
      expect(controller.loading, isFalse);
      expect(controller.error, isNull);
    });
  });

  group('DrillController deepen (PRD M5.4 deepening_protocol)', () {
    test('load resolves the layer to deepest existing + 1', () async {
      final fake = _FakeDrillDataSource()
        ..rowsByLoop['loop-1'] = {'id': 'drill-0', 'deepening_layer': 2};
      final controller =
          DrillController(loopId: 'loop-1', deepen: true, dataSource: fake);

      await controller.load();

      expect(fake.calls, ['fetchBridgeQuestion', 'fetchDeepestLayer']);
      expect(controller.deepeningLayer, 3);
    });

    test('load never queries layers without deepen', () async {
      final fake = _FakeDrillDataSource();
      final controller = DrillController(loopId: 'loop-1', dataSource: fake);

      await controller.load();

      expect(fake.calls, isNot(contains('fetchDeepestLayer')));
      expect(controller.deepeningLayer, 1);
    });

    test('a deepening drill updates the existing row at the resolved layer',
        () async {
      final fake = _FakeDrillDataSource()
        ..rowsByLoop['loop-1'] = {'id': 'drill-0', 'deepening_layer': 1};
      final controller =
          DrillController(loopId: 'loop-1', deepen: true, dataSource: fake);
      await controller.load();
      controller
        ..selectOriginType(OriginType.childhoodConditioning)
        ..selectOriginDomain(OriginDomain.adequacyImpostor)
        ..selectCopingMechanism(CopingMechanism.collapseShutdown)
        ..setQ1FreeText('It started early.')
        ..setQ2FreeText('It shows up at work.')
        ..setQ3FreeText('I shut down.');

      final result = await controller.submit();

      expect(result.drillId, 'drill-0');
      expect(fake.rowsByLoop['loop-1']!['deepening_layer'], 2);
      expect(fake.calls, contains('updateDrill'));
      expect(fake.calls, isNot(contains('insertDrill')));
    });
  });
}

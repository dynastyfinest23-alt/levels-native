import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/features/drill/drill_controller.dart';
import 'package:levels_native/features/drill/drill_tokens.dart';

/// Records call order without touching Supabase, so
/// [DrillController.submit]'s insert -> RPC -> read-back contract can be
/// pinned by a fake client (PRD M3.4 done-when).
class _FakeDrillDataSource implements DrillDataSource {
  final List<String> calls = [];
  String? insertedLoopId;
  OriginType? insertedOriginType;
  OriginDomain? insertedOriginDomain;
  CopingMechanism? insertedCopingMechanism;
  int? insertedDeepeningLayer;

  @override
  Future<String> fetchBridgeQuestion(String loopId) async {
    calls.add('fetchBridgeQuestion');
    return 'What would it mean to let this be enough?';
  }

  /// Set by a test to simulate existing drill rows for the deepen path.
  int? deepestLayer;

  @override
  Future<int?> fetchDeepestLayer(String loopId) async {
    calls.add('fetchDeepestLayer');
    return deepestLayer;
  }

  @override
  Future<String> insertDrill({
    required String loopId,
    required OriginType originType,
    required OriginDomain originDomain,
    required CopingMechanism copingMechanism,
    required String q1FreeText,
    required String q2FreeText,
    required String q3FreeText,
    required int deepeningLayer,
  }) async {
    calls.add('insertDrill');
    insertedLoopId = loopId;
    insertedOriginType = originType;
    insertedOriginDomain = originDomain;
    insertedCopingMechanism = copingMechanism;
    insertedDeepeningLayer = deepeningLayer;
    return 'drill-1';
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

    test('passes the loop id, answers, and deepening layer through to insertDrill', () async {
      final fake = _FakeDrillDataSource();
      final controller = _completedController(fake, loopId: 'loop-7');

      await controller.submit();

      expect(fake.insertedLoopId, 'loop-7');
      expect(fake.insertedOriginType, OriginType.childhoodConditioning);
      expect(fake.insertedOriginDomain, OriginDomain.adequacyImpostor);
      expect(fake.insertedCopingMechanism, CopingMechanism.collapseShutdown);
      expect(fake.insertedDeepeningLayer, 1);
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
      final fake = _FakeDrillDataSource()..deepestLayer = 2;
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

    test('a deepening drill inserts at the resolved layer', () async {
      final fake = _FakeDrillDataSource()..deepestLayer = 1;
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

      await controller.submit();

      expect(fake.insertedDeepeningLayer, 2);
    });
  });
}

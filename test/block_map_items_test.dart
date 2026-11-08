// Purpose: pins the block-map question bank structure (design section 4,
// approved 2026-11-08): 48 items, 4 per origin_domain in enum order, 3 forward
// + 1 reverse, reverse paired with _1 (relational: _3), keys = '<token>_<n>', short, no em dash.
import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/features/block_map/block_map_items.dart';
import 'package:levels_native/features/drill/drill_tokens.dart';

void main() {
  test('48 items, 4 per domain in enum order with canonical keys', () {
    expect(blockMapItems.length, 48);
    for (var d = 0; d < OriginDomain.values.length; d++) {
      final domain = OriginDomain.values[d];
      final items = blockMapItems.sublist(d * 4, d * 4 + 4);
      for (var n = 0; n < 4; n++) {
        expect(items[n].domain, domain);
        expect(items[n].key, '${domain.token}_${n + 1}');
        expect(items[n].reverse, n == 3);
      }
      // Reverse pairs with _1, except relational_attachment (_3), 2026-11-08.
      final fwd = domain == OriginDomain.relationalAttachment ? 2 : 0;
      for (var n = 0; n < 3; n++) {
        expect(items[n].pairKey, n == fwd ? '${domain.token}_pair' : isNull,
            reason: items[n].key);
      }
      expect(items[3].pairKey, '${domain.token}_pair');
    }
    expect(blockMapItems.map((i) => i.key).toSet().length, 48);
  });

  test('copy rules: <=16 words, no em dash, no digits', () {
    final copy = [
      ...blockMapItems.map((i) => i.text),
      blockMapPrimer,
      blockMapLowConfidenceCaption,
    ];
    for (final text in copy) {
      expect(text.contains('—'), isFalse, reason: text);
      expect(RegExp(r'\d').hasMatch(text), isFalse, reason: text);
    }
    for (final item in blockMapItems) {
      expect(item.text.split(' ').length, lessThanOrEqualTo(16),
          reason: item.text);
    }
  });
}

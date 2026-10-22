import 'package:flutter_test/flutter_test.dart';
import 'package:transit_orleans/core/util.dart';

void main() {
  test('normalisation des noms', () {
    expect(norm('Orléans Gare'), 'orleans gare');
    expect(hhmm(DateTime(2026, 1, 1, 7, 5)), '07:05');
  });
}

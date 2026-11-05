import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/core/jmdict_labels.dart';

void main() {
  test('posLabel turns JMdict codes into plain words', () {
    expect(posLabel('v5k-s,vi'), 'godan verb · intransitive');
    expect(posLabel('n,adj-no'), 'noun · takes の');
    expect(posLabel('v5r,v5r-i'), 'godan verb');
    expect(posLabel('xyz'), 'xyz');
    expect(posLabel(''), '');
  });
}

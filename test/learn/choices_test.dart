import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/learn/agent/choices.dart';

void main() {
  test('a choices block becomes the options; the question keeps the rest', () {
    final c = ChatChoices.parse('Which particle marks the topic?\n\n```choices\nは\nが\nを\n```')!;
    expect(c.text, 'Which particle marks the topic?');
    expect(c.options, ['は', 'が', 'を']);
  });

  test("bullets, blanks, repeats and the model's own I-don't-know are dropped", () {
    final c = ChatChoices.parse('Pick one.\n```choices\n- 食べる\n\n* 飲む\n+ 食べる\nI don’t know\n```')!;
    expect(c.options, ['食べる', '飲む']);
  });

  test('other code blocks and plain text carry no choices', () {
    expect(ChatChoices.parse('Say it politely:\n\n```\n食べます\n```'), isNull);
    expect(ChatChoices.parse('```dart\nprint(1);\n```'), isNull);
    expect(ChatChoices.parse('What does 猫 mean?'), isNull);
  });

  test('the last block wins and text after it stays', () {
    final c = ChatChoices.parse('```choices\nA\nB\n```\nSecond:\n~~~Choices\nC\nD\n~~~\nTake your time.')!;
    expect(c.options, ['C', 'D']);
    expect(c.text, '```choices\nA\nB\n```\nSecond:\nTake your time.');
  });

  test('a block still streaming in hides its fence and shows what arrived', () {
    expect(ChatChoices.parse('Which one?\n\n```choices')!.text, 'Which one?');
    expect(ChatChoices.parse('Which one?\n\n```choices')!.options, isEmpty);
    expect(ChatChoices.parse('Which one?\n\n```choices\nは\nが')!.options, ['は', 'が']);
  });
}

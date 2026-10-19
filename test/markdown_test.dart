import 'package:flutter_test/flutter_test.dart';
import 'package:rekhu_assistant/rekhu_assistant.dart';

void main() {
  test('paragraphs, lists, bold, italics, code and links', () {
    final b = parseRekhuMarkdown('Your order **ORD-1001** is *on its way*.\n- one `code`\n- two\n1. first\n2. [Open it](/orders/1001)');
    expect(b.length, 5);
    expect(b[0].inlines.where((i) => i.bold).single.text, 'ORD-1001');
    expect(b[0].inlines.where((i) => i.italic).single.text, 'on its way');
    expect(b[1].bullet, isTrue);
    expect(b[1].inlines.where((i) => i.code).single.text, 'code');
    expect([b[3].number, b[4].number], [1, 2]);
    expect(b[4].inlines.single.link, '/orders/1001');
  });

  test('only http(s) and the app\'s own paths become links', () {
    for (final unsafe in ['[x](javascript:alert(1))', '[x](data:text/html,hi)', '[x](//evil.example)']) {
      expect(parseRekhuMarkdown(unsafe).single.inlines.every((i) => i.link == null), isTrue, reason: unsafe);
    }
    expect(parseRekhuMarkdown('[site](https://example.com/a)').single.inlines.single.link, 'https://example.com/a');
  });
}

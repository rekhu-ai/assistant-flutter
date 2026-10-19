// Against a real back end, as a visitor: REKHU_LIVE_ENDPOINT=https://…/rekhu/assistant/visitor/chat flutter test test/live_test.dart
// Skipped without it. It makes real model calls on the back end's Rekhu account.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rekhu_assistant/rekhu_assistant.dart';

void main() {
  final endpoint = Platform.environment['REKHU_LIVE_ENDPOINT'];
  final skip = endpoint == null ? 'set REKHU_LIVE_ENDPOINT to a public chat route' : null;

  for (final locale in ['en-GB', 'ar-SA']) {
    test('a visitor gets the greeting and a streamed answer ($locale)', () async {
      final client = RekhuAssistantClient(endpoint: Uri.parse(endpoint!), visitor: true, locale: locale);
      final history = await client.history();
      expect(history.greeting, isNotEmpty);

      final events = await client.send(locale.startsWith('ar') ? 'ماذا يمكنك أن تفعل لي؟' : 'What can you do for me?').toList();
      expect(events.first, isA<RekhuStart>());
      expect(events.last, isA<RekhuDone>());
      final answer = events.whereType<RekhuText>().map((e) => e.text).join();
      expect(answer, isNotEmpty);
      // ignore: avoid_print
      print('$locale: ${answer.length > 160 ? '${answer.substring(0, 160)}…' : answer}');
      expect(client.conversation, isNotNull);

      final again = await client.history();
      expect(again.messages.length, greaterThanOrEqualTo(2));
      await client.forget();
      expect(client.conversation, isNull);
      client.close();
    }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));
  }
}

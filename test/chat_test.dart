import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rekhu_assistant/rekhu_assistant.dart';

String sse(List<Map<String, dynamic>> events) => events.map((e) => 'data: ${jsonEncode(e)}\n\n').join();

/// A back end: the greeting and quick questions on GET, the given answers on each POST, in turn.
MockClient backend(List<String> answers, {List<Map<String, dynamic>>? posted}) {
  var turn = 0;
  return MockClient((r) async {
    if (r.method == 'GET') return http.Response(jsonEncode({'messages': [], 'greeting': 'Hi! Ask me about **orders**.', 'quick': ['Where is my order?']}), 200);
    if (r.method == 'DELETE') return http.Response('', 204);
    posted?.add(jsonDecode(r.body) as Map<String, dynamic>);
    return http.Response(answers[turn++], 200, headers: {'content-type': 'text/event-stream'});
  });
}

void main() {
  testWidgets('greeting and quick questions, an answer, a confirmed action', (tester) async {
    final posted = <Map<String, dynamic>>[];
    final actions = <RekhuCard>[];
    final opened = <String>[];
    final client = RekhuAssistantClient(
      endpoint: Uri.parse('https://api.example.com/chat'),
      httpClient: backend([
        sse([
          {'type': 'start', 'conversation': 'c1', 'protocol': 1},
          {'type': 'step', 'label': 'Looking up your orders'},
          {'type': 'text', 'text': 'Order ORD-1001 can be cancelled.'},
          {'type': 'card', 'kind': 'confirm', 'id': 'k1', 'title': 'Cancel order', 'input': {'order': 'ORD-1001'}},
          {'type': 'done'},
        ]),
        sse([
          {'type': 'start', 'conversation': 'c1', 'protocol': 1},
          {'type': 'card', 'kind': 'done', 'title': 'Order cancelled', 'url': '/orders/1001'},
          {'type': 'done'},
        ]),
      ], posted: posted),
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RekhuChat(client: client, onAction: actions.add, onOpenPage: opened.add))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ask me about'), findsOneWidget);
    expect(find.text('Where is my order?'), findsOneWidget);

    await tester.tap(find.text('Where is my order?'));
    await tester.pumpAndSettle();
    expect(find.text('Order ORD-1001 can be cancelled.'), findsOneWidget);
    expect(find.text('Looking up your orders'), findsOneWidget);
    expect(find.text('Cancel order'), findsOneWidget);
    expect(find.textContaining('ORD-1001'), findsWidgets);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(posted.last['confirm'], 'k1');
    expect(find.text('Order cancelled'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(actions.single.title, 'Order cancelled');

    await tester.tap(find.text('Open'));
    expect(opened.single, '/orders/1001');
  });

  testWidgets('Arabic reads right to left, in its own words', (tester) async {
    final client = RekhuAssistantClient(endpoint: Uri.parse('https://api.example.com/chat'), locale: 'ar-SA', httpClient: backend([]));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RekhuChat(client: client))));
    await tester.pumpAndSettle();
    expect(find.text('المساعد'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('المساعد'))), TextDirection.rtl);
  });

  testWidgets('a signed-out user is told so', (tester) async {
    final client = RekhuAssistantClient(endpoint: Uri.parse('https://api.example.com/chat'), httpClient: MockClient((r) async => http.Response('{}', 401, headers: {'content-type': 'application/json'})));
    final chat = RekhuChatController(client: client);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RekhuChat(controller: chat))));
    await tester.pumpAndSettle();
    expect(chat.signedOut, isTrue);
    expect(find.text(RekhuTexts.en.signedOut), findsOneWidget);
  });
}

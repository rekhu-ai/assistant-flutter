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

  group('conversation history', () {
    /// A back end for a signed-in user with two earlier conversations; records each call.
    MockClient signedIn(List<String> calls) {
      final titles = {'c1': 'Where is my order?', 'c2': 'Show my invoices'};
      return MockClient((r) async {
        calls.add('${r.method} ${r.url.path}${r.url.hasQuery ? '?${r.url.query}' : ''}');
        final path = r.url.path;
        if (r.method == 'GET' && path.endsWith('/conversations')) {
          return http.Response(jsonEncode({
            'conversations': [
              for (final e in titles.entries) {'id': e.key, 'title': e.value, 'scope': null, 'updated_at': DateTime.now().toUtc().toIso8601String(), 'questions': e.key == 'c1' ? 1 : 3},
            ],
          }), 200);
        }
        if (r.method == 'GET') {
          final id = r.url.queryParameters['conversation'];
          return http.Response(jsonEncode({
            'conversation': id,
            'history': true,
            'messages': id == null ? [] : [{'role': 'user', 'text': 'Earlier: ${titles[id]}'}, {'role': 'bot', 'text': 'Earlier answer'}],
            'greeting': 'Hi!',
          }), 200);
        }
        if (r.method == 'PATCH') {
          final id = path.split('/').last;
          titles[id] = (jsonDecode(r.body) as Map)['title'] as String;
          return http.Response(jsonEncode({'conversation': {'id': id, 'title': titles[id], 'questions': 1}}), 200);
        }
        if (r.method == 'DELETE') {
          titles.remove(path.split('/').last);
          return http.Response('', 204);
        }
        return http.Response('{}', 404);
      });
    }

    testWidgets('the list shows its rows beside the chat and opens one', (tester) async {
      final calls = <String>[];
      final client = RekhuAssistantClient(endpoint: Uri.parse('https://api.example.com/chat'), httpClient: signedIn(calls));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: RekhuChat(client: client))));
      await tester.pumpAndSettle();
      expect(find.text('Conversations'), findsOneWidget);
      expect(find.text('Where is my order?'), findsOneWidget);
      expect(find.textContaining('3 questions'), findsOneWidget);
      expect(find.textContaining('1 question'), findsOneWidget);
      expect(calls, contains('GET /chat/conversations?limit=30'));

      await tester.tap(find.text('Show my invoices'));
      await tester.pumpAndSettle();
      expect(calls, contains('GET /chat?conversation=c2'));
      expect(client.conversation, 'c2');
      expect(find.text('Earlier: Show my invoices'), findsOneWidget);
      expect(tester.widget<ListTile>(find.byKey(const ValueKey('rekhu-conversation-c2'))).selected, isTrue);

      await tester.tap(find.text('New chat'));
      await tester.pumpAndSettle();
      expect(client.conversation, isNull);
      expect(calls.where((c) => c.startsWith('DELETE')), isEmpty);
      expect(find.text('Show my invoices'), findsOneWidget);
    });

    testWidgets('rename and delete from a row', (tester) async {
      final calls = <String>[];
      final client = RekhuAssistantClient(endpoint: Uri.parse('https://api.example.com/chat'), httpClient: signedIn(calls));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: RekhuChat(client: client))));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(of: find.byKey(const ValueKey('rekhu-conversation-c1')), matching: find.byIcon(Icons.more_horiz)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'Order questions');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(calls, contains('PATCH /chat/conversations/c1'));
      expect(find.text('Order questions'), findsOneWidget);

      await tester.tap(find.descendant(of: find.byKey(const ValueKey('rekhu-conversation-c2')), matching: find.byIcon(Icons.more_horiz)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this conversation?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(calls, contains('DELETE /chat/conversations/c2'));
      expect(find.text('Show my invoices'), findsNothing);
    });

    testWidgets('on a narrow screen the list covers the chat, right to left in Arabic, and closes after a pick', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final client = RekhuAssistantClient(endpoint: Uri.parse('https://api.example.com/chat'), locale: 'ar', httpClient: signedIn([]));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: RekhuChat(client: client))));
      await tester.pumpAndSettle();
      expect(find.text('Where is my order?'), findsNothing);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.text('محادثة جديدة'), findsOneWidget);
      expect(Directionality.of(tester.element(find.text('Where is my order?'))), TextDirection.rtl);

      await tester.tap(find.text('Where is my order?'));
      await tester.pumpAndSettle();
      expect(find.text('Earlier: Where is my order?'), findsOneWidget);
      expect(find.text('محادثة جديدة'), findsNothing);
    });

    testWidgets('the public chat has no list', (tester) async {
      final client = RekhuAssistantClient(endpoint: Uri.parse('https://api.example.com/chat'), httpClient: backend([]));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: RekhuChat(client: client))));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.menu), findsNothing);
      expect(find.text('Conversations'), findsNothing);
    });

    test('the next page is fetched and added after the first', () async {
      final before = <String?>[];
      final client = RekhuAssistantClient(endpoint: Uri.parse('https://api.example.com/chat'), httpClient: MockClient((r) async {
        if (!r.url.path.endsWith('/conversations')) return http.Response('{"history":true,"messages":[]}', 200);
        final cursor = r.url.queryParameters['before'];
        before.add(cursor);
        return http.Response(jsonEncode({'conversations': [{'id': cursor == null ? 'c2' : 'c1', 'title': 'x', 'questions': 1}], if (cursor == null) 'next': 'n1'}), 200);
      }));
      final chat = RekhuChatController(client: client);
      await chat.load();
      await chat.loadConversations();
      expect(chat.conversations.map((c) => c.id), ['c2']);
      expect(chat.conversationsNext, 'n1');
      await chat.moreConversations();
      expect(chat.conversations.map((c) => c.id), ['c2', 'c1']);
      expect(chat.conversationsNext, isNull);
      await chat.moreConversations();
      expect(before.last, 'n1');
    });

    test('the list is fetched again after each answer, so the open one moves to the top', () async {
      var lists = 0;
      final client = RekhuAssistantClient(endpoint: Uri.parse('https://api.example.com/chat'), httpClient: MockClient((r) async {
        if (r.url.path.endsWith('/conversations')) {
          lists++;
          return http.Response(jsonEncode({'conversations': [if (lists > 1) {'id': 'c9', 'title': 'Hello', 'questions': 1}]}), 200);
        }
        if (r.method == 'GET') return http.Response('{"history":true,"messages":[]}', 200);
        return http.Response(sse([{'type': 'start', 'conversation': 'c9', 'protocol': 1}, {'type': 'text', 'text': 'Hi'}, {'type': 'done'}]), 200, headers: {'content-type': 'text/event-stream'});
      }));
      final chat = RekhuChatController(client: client);
      await chat.load();
      await Future<void>.delayed(Duration.zero);
      expect(lists, 1);
      await chat.send('Hello');
      await Future<void>.delayed(Duration.zero);
      expect(lists, 2);
      expect(chat.conversations.single.id, 'c9');
      expect(chat.current, 'c9');
    });
  });
}

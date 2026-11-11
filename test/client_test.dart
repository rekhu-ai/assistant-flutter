import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rekhu_assistant/rekhu_assistant.dart';

String sse(List<Map<String, dynamic>> events) => events.map((e) => 'event: ${e['type']}\ndata: ${jsonEncode(e)}\n\n').join();

/// A server that answers a turn in small chunks, cut through the middle of events, as a network does.
MockClient streaming(String body, {int status = 200, void Function(http.BaseRequest r, String body)? seen}) => MockClient.streaming((request, bodyStream) async {
      final sent = await bodyStream.bytesToString();
      seen?.call(request, sent);
      final bytes = utf8.encode(body);
      final chunks = <List<int>>[for (var i = 0; i < bytes.length; i += 7) bytes.sublist(i, i + 7 > bytes.length ? bytes.length : i + 7)];
      return http.StreamedResponse(Stream.fromIterable(chunks), status, headers: {'content-type': status == 200 ? 'text/event-stream' : 'application/json'});
    });

void main() {
  final endpoint = Uri.parse('https://api.example.com/rekhu/assistant/chat');

  test('a turn streams its events and keeps the conversation for the next one', () async {
    final bodies = <Map<String, dynamic>>[];
    final client = RekhuAssistantClient(
      endpoint: endpoint,
      locale: 'ar-SA',
      headers: () => {'Authorization': 'Bearer token-1'},
      httpClient: streaming(
        sse([
          {'type': 'start', 'conversation': 'c-1', 'protocol': 1},
          {'type': 'step', 'label': 'أبحث عن طلباتك'},
          {'type': 'text', 'text': 'طلبك الأخير '},
          {'type': 'text', 'text': '**ORD-1001**'},
          {'type': 'card', 'kind': 'confirm', 'id': 'k1', 'title': 'Cancel order', 'input': {'order': 'ORD-1001'}, 'danger': true},
          {'type': 'future-kind', 'x': 1},
          {'type': 'done'},
        ]),
        seen: (r, body) {
          bodies.add(jsonDecode(body) as Map<String, dynamic>);
          expect(r.headers['Authorization'], 'Bearer token-1');
          expect(r.headers['X-Rekhu-Protocol'], '1');
          expect(r.headers['Accept'], 'text/event-stream');
          expect(r.headers.containsKey('X-Rekhu-Visitor'), isFalse);
        },
      ),
    );
    final events = await client.send('أين طلبي؟').toList();
    expect(events.map((e) => e.runtimeType.toString()), ['RekhuStart', 'RekhuStep', 'RekhuText', 'RekhuText', 'RekhuCard', 'RekhuDone']);
    final card = events[4] as RekhuCard;
    expect(card.kind, RekhuCardKind.confirm);
    expect(card.input['order'], 'ORD-1001');
    expect(card.danger, isTrue);
    expect(client.conversation, 'c-1');
    expect(bodies.single, {'message': 'أين طلبي؟', 'conversation': null, 'locale': 'ar-SA'});

    await client.confirm('k1').toList();
    expect(bodies.last, {'confirm': 'k1', 'conversation': 'c-1', 'locale': 'ar-SA'});
  });

  test('the conversation survives a restart in the store', () async {
    final store = RekhuMemoryStore();
    await store.write('rekhu-assistant:conversation', 'kept-7');
    String? asked;
    final client = RekhuAssistantClient(
      endpoint: endpoint,
      store: store,
      httpClient: MockClient((r) async {
        asked = r.url.queryParameters['conversation'];
        return http.Response(jsonEncode({'conversation': 'kept-7', 'messages': [{'role': 'user', 'text': 'hi'}, {'role': 'bot', 'text': 'Hello'}]}), 200);
      }),
    );
    final h = await client.history();
    expect(asked, 'kept-7');
    expect(h.messages.map((m) => m.fromUser), [true, false]);
  });

  test('a visitor sends the same anonymous id every time', () async {
    final ids = <String?>[];
    final store = RekhuMemoryStore();
    for (var i = 0; i < 2; i++) {
      final client = RekhuAssistantClient(endpoint: endpoint, visitor: true, store: store, httpClient: MockClient((r) async {
        ids.add(r.headers['X-Rekhu-Visitor']);
        return http.Response('{"messages":[],"greeting":"Hi"}', 200);
      }));
      expect((await client.history()).greeting, 'Hi');
    }
    expect(ids[0], matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(ids[1], ids[0]);
  });

  test('failures say what to tell the user, the server\'s own words first', () async {
    Future<RekhuException> fail(int status, [String body = '{}']) async {
      final client = RekhuAssistantClient(endpoint: endpoint, locale: 'nl', httpClient: streaming(body, status: status));
      try {
        await client.send('x').toList();
      } on RekhuException catch (e) {
        return e;
      }
      throw StateError('no failure');
    }

    expect((await fail(401)).signedOut, isTrue);
    expect((await fail(401)).message, RekhuTexts.nl.signedOut);
    expect((await fail(429, '{"message":"Je hebt vandaag 20 vragen gesteld."}')).message, 'Je hebt vandaag 20 vragen gesteld.');
    expect((await fail(503)).message, RekhuTexts.nl.unavailable);
  });

  test('forget asks the server to drop the conversation and starts fresh', () async {
    final store = RekhuMemoryStore();
    await store.write('rekhu-assistant:conversation', 'old');
    String? method;
    String? body;
    final client = RekhuAssistantClient(endpoint: endpoint, store: store, httpClient: MockClient((r) async {
      method = r.method;
      body = r.body;
      return http.Response('', 204);
    }));
    await client.forget();
    expect(method, 'DELETE');
    expect(jsonDecode(body!), {'conversation': 'old'});
    expect(client.conversation, isNull);
    expect(await store.read('rekhu-assistant:conversation'), isNull);
  });

  group('conversations', () {
    Map<String, dynamic> item(String id, {String title = 'Where is my order?', int questions = 2}) =>
        {'id': id, 'title': title, 'scope': null, 'updated_at': '2026-11-11T09:12:44+00:00', 'questions': questions};

    test('the list comes in pages, searched, with the same headers as every call', () async {
      final asked = <Uri>[];
      final client = RekhuAssistantClient(
        endpoint: endpoint,
        locale: 'nl',
        headers: () => {'Authorization': 'Bearer token-1'},
        httpClient: MockClient((r) async {
          asked.add(r.url);
          expect(r.method, 'GET');
          expect(r.headers['Authorization'], 'Bearer token-1');
          expect(r.headers['X-Rekhu-Protocol'], '1');
          expect(r.headers['Accept'], 'application/json');
          final first = r.url.queryParameters['before'] == null;
          return http.Response(jsonEncode({'conversations': [item(first ? 'c2' : 'c1')], if (first) 'next': 'cursor|c2'}), 200);
        }),
      );
      final first = await client.conversations(query: ' order ', limit: 1);
      expect(first.items.single.id, 'c2');
      expect(first.items.single.questions, 2);
      expect(first.items.single.updatedAt, DateTime.utc(2026, 11, 11, 9, 12, 44));
      expect(first.next, 'cursor|c2');
      final second = await client.conversations(query: 'order', before: first.next, limit: 1);
      expect(second.items.single.id, 'c1');
      expect(second.next, isNull);

      expect(asked[0].path, '/rekhu/assistant/chat/conversations');
      expect(asked[0].queryParameters, {'limit': '1', 'q': 'order'});
      expect(asked[1].queryParameters, {'limit': '1', 'before': 'cursor|c2', 'q': 'order'});
    });

    test('rename sends the title and gives back the item', () async {
      late http.Request seen;
      final client = RekhuAssistantClient(endpoint: endpoint, httpClient: MockClient((r) async {
        seen = r;
        return http.Response(jsonEncode({'conversation': item('c1', title: 'Order questions')}), 200);
      }));
      final renamed = await client.renameConversation('c1', ' Order questions ');
      expect(seen.method, 'PATCH');
      expect(seen.url.path, '/rekhu/assistant/chat/conversations/c1');
      expect(jsonDecode(seen.body), {'title': 'Order questions'});
      expect(renamed.title, 'Order questions');
    });

    test('renaming one that is gone fails with 404', () async {
      final client = RekhuAssistantClient(endpoint: endpoint, httpClient: MockClient((r) async => http.Response('{}', 404, headers: {'content-type': 'application/json'})));
      expect(() => client.renameConversation('gone', 'x'), throwsA(isA<RekhuException>().having((e) => e.status, 'status', 404)));
    });

    test('delete removes it by id and forgets it when it is the open one', () async {
      final store = RekhuMemoryStore();
      await store.write('rekhu-assistant:conversation', 'c1');
      final calls = <String>[];
      final client = RekhuAssistantClient(endpoint: endpoint, store: store, httpClient: MockClient((r) async {
        calls.add('${r.method} ${r.url.path}');
        return http.Response('', 204);
      }));
      await client.deleteConversation('c2');
      expect(client.conversation, 'c1');
      await client.deleteConversation('c1');
      expect(client.conversation, isNull);
      expect(calls, ['DELETE /rekhu/assistant/chat/conversations/c2', 'DELETE /rekhu/assistant/chat/conversations/c1']);
    });

    test('a new chat forgets the id here only and deletes nothing', () async {
      final store = RekhuMemoryStore();
      await store.write('rekhu-assistant:conversation', 'old');
      final calls = <String>[];
      final bodies = <Map<String, dynamic>>[];
      final client = RekhuAssistantClient(
        endpoint: endpoint,
        store: store,
        httpClient: streaming(sse([{'type': 'start', 'conversation': 'new', 'protocol': 1}, {'type': 'done'}]), seen: (r, body) {
          calls.add(r.method);
          bodies.add(jsonDecode(body) as Map<String, dynamic>);
        }),
      );
      await client.newChat();
      expect(client.conversation, isNull);
      expect(await store.read('rekhu-assistant:conversation'), isNull);
      await client.send('hi').toList();
      expect(calls, ['POST']);
      expect(bodies.single['conversation'], isNull);
      expect(client.conversation, 'new');
    });

    test('open loads that conversation and goes on in it', () async {
      final asked = <String?>[];
      final client = RekhuAssistantClient(endpoint: endpoint, httpClient: MockClient((r) async {
        asked.add(r.url.queryParameters['conversation']);
        return http.Response(jsonEncode({'conversation': 'c7', 'history': true, 'messages': [{'role': 'user', 'text': 'Earlier question'}]}), 200);
      }));
      final h = await client.open('c7');
      expect(asked, ['c7']);
      expect(client.conversation, 'c7');
      expect(h.messages.single.text, 'Earlier question');
      expect(h.history, isTrue);
    });

    test('the history flag is false when the server has no list', () async {
      final client = RekhuAssistantClient(endpoint: endpoint, visitor: true, httpClient: MockClient((r) async => http.Response('{"messages":[]}', 200)));
      expect((await client.history()).history, isFalse);
    });
  });
}

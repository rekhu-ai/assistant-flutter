import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'protocol.dart';
import 'texts.dart';

/// Where the client keeps the conversation id and, for the public chat, the visitor id between app starts. Keep them
/// with shared_preferences, secure storage or anything else; [RekhuMemoryStore] keeps them while the app runs.
abstract class RekhuStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

/// Keeps the ids while the app runs: a new conversation after every start.
class RekhuMemoryStore implements RekhuStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String? value) async => value == null ? _values.remove(key) : _values[key] = value;
}

/// The connection to your back end's chat route, for the [RekhuChat] widget or a chat screen of your own. It speaks
/// protocol 1 with a Rekhu server package (rekhu/assistant-laravel, @rekhu/assistant-node): the app never holds a
/// Rekhu key, it signs in to your back end as it always does.
///
/// ```dart
/// final client = RekhuAssistantClient(
///   endpoint: Uri.parse('https://api.example.com/rekhu/assistant/chat'),
///   headers: () async => {'Authorization': 'Bearer ${await auth.token()}'},
/// );
/// final history = await client.history();             // greeting, quick questions, earlier messages
/// await for (final event in client.send('Where is my order?')) { … }
/// ```
class RekhuAssistantClient {
  RekhuAssistantClient({
    required this.endpoint,
    this.headers,
    this.locale,
    this.visitor = false,
    RekhuStore? store,
    http.Client? httpClient,
  })  : store = store ?? RekhuMemoryStore(),
        _http = httpClient ?? http.Client(),
        _ownsHttp = httpClient == null;

  /// Your back end's chat route, for example https://api.example.com/rekhu/assistant/chat (or the public route for visitors).
  final Uri endpoint;

  /// Headers on every call, for example the user's token; called before each call, so a refreshed token is used.
  final FutureOr<Map<String, String>> Function()? headers;

  /// The language the user reads (BCP 47, "ar-SA", "en-GB"); answers come in it. Null sends none.
  final String? locale;

  /// The public chat for visitors who are not signed in: sends an anonymous id, kept in [store], as X-Rekhu-Visitor.
  final bool visitor;

  final RekhuStore store;
  final http.Client _http;
  final bool _ownsHttp;

  String? _conversation;
  bool _restored = false;
  String? _visitorId;

  RekhuTexts get _texts => RekhuTexts.of(locale);
  String get _prefix => visitor ? 'rekhu-assistant:visitor:' : 'rekhu-assistant:';

  /// The conversation id; null for a fresh chat.
  String? get conversation => _conversation;

  Future<void> _restore() async {
    if (_restored) return;
    _restored = true;
    _conversation = await store.read('${_prefix}conversation');
  }

  Future<void> _keep(String? id) async {
    _conversation = id;
    await store.write('${_prefix}conversation', id);
  }

  /// For the public chat: this install's anonymous id, made once and kept in [store].
  Future<String> visitorId() async {
    if (_visitorId != null) return _visitorId!;
    final kept = await store.read('rekhu-assistant:visitor-id');
    final uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
    if (kept != null && uuid.hasMatch(kept)) return _visitorId = kept;
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    _visitorId = '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
    await store.write('rekhu-assistant:visitor-id', _visitorId);
    return _visitorId!;
  }

  Future<Map<String, String>> _headers(String accept) async => {
        'Content-Type': 'application/json',
        'Accept': accept,
        'X-Requested-With': 'XMLHttpRequest',
        'X-Rekhu-Protocol': '$rekhuProtocol',
        if (locale != null) 'Accept-Language': locale!,
        if (visitor) 'X-Rekhu-Visitor': await visitorId(),
        ...?(await headers?.call()),
      };

  /// Why a call failed, in the user's language: the server's own words when it gave them.
  Future<RekhuException> _failure(http.BaseResponse response, String body) async {
    String said = '';
    if ((response.headers['content-type'] ?? '').contains('json')) {
      try {
        said = '${(jsonDecode(body) as Map)['message'] ?? ''}';
      } catch (_) {/* no message */}
    }
    final s = response.statusCode;
    if (s == 401 || s == 419) return RekhuException(_texts.signedOut, status: s);
    if (s == 429) return RekhuException(said.isNotEmpty ? said : _texts.busy, status: s);
    return RekhuException(said.isNotEmpty ? said : _texts.unavailable, status: s);
  }

  /// What the user saw of the conversation, and for a fresh chat the greeting and quick questions.
  Future<RekhuHistory> history() async {
    await _restore();
    final uri = _conversation == null ? endpoint : endpoint.replace(queryParameters: {...endpoint.queryParameters, 'conversation': _conversation!});
    final response = await _http.get(uri, headers: await _headers('application/json'));
    if (response.statusCode != 200) throw await _failure(response, response.body);
    try {
      return RekhuHistory.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
    } on FormatException {
      // a back end that is not a Rekhu server package (a login page, an error page) answers something else
      throw RekhuException(_texts.unavailable, status: response.statusCode);
    }
  }

  /// Sends a message and streams the answer's events; a call that fails before the answer starts throws [RekhuException].
  Stream<RekhuEvent> send(String message) => _turn({'message': message});

  /// Runs the action behind a confirm card, with the input the server keeps for it.
  Stream<RekhuEvent> confirm(String id) => _turn({'confirm': id});

  Stream<RekhuEvent> _turn(Map<String, dynamic> payload) async* {
    await _restore();
    final request = http.Request('POST', endpoint)
      ..headers.addAll(await _headers('text/event-stream'))
      ..body = jsonEncode({...payload, 'conversation': _conversation, 'locale': locale});
    final response = await _http.send(request);
    if (response.statusCode != 200) throw await _failure(response, await response.stream.bytesToString());
    var buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk.replaceAll('\r\n', '\n');
      var end = buffer.indexOf('\n\n');
      while (end != -1) {
        final block = buffer.substring(0, end);
        buffer = buffer.substring(end + 2);
        end = buffer.indexOf('\n\n');
        final data = block.split('\n').where((l) => l.startsWith('data:')).map((l) => l.substring(5).trimLeft()).join('\n');
        if (data.isEmpty) continue;
        final Object? json;
        try {
          json = jsonDecode(data);
        } on FormatException {
          continue;
        }
        if (json is! Map<String, dynamic>) continue;
        final event = RekhuEvent.fromJson(json);
        if (event == null) continue;
        if (event is RekhuStart && event.conversation.isNotEmpty) await _keep(event.conversation);
        yield event;
      }
    }
  }

  /// Forgets the conversation on the server and here; the next message starts a new one.
  Future<void> forget() async {
    await _restore();
    final id = _conversation;
    await _keep(null);
    if (id == null) return;
    try {
      final request = http.Request('DELETE', endpoint)
        ..headers.addAll(await _headers('application/json'))
        ..body = jsonEncode({'conversation': id});
      await (await _http.send(request)).stream.drain<void>();
    } catch (_) {/* forgotten here; the server lets it go in time */}
  }

  /// Closes the HTTP connection when the client made it.
  void close() {
    if (_ownsHttp) _http.close();
  }
}

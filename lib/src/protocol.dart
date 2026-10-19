/// What a Rekhu server package in your back end and this package say to each other: protocol 1 (PROTOCOL.md).
library;

/// The protocol version this package speaks.
const int rekhuProtocol = 1;

/// One event of an answer, in the order the server sends them: [RekhuStart] first, [RekhuDone] last.
sealed class RekhuEvent {
  const RekhuEvent();

  /// The event from its JSON; null for a type this version does not know (a newer server may add some).
  static RekhuEvent? fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'start':
        return RekhuStart(conversation: '${json['conversation'] ?? ''}', protocol: (json['protocol'] as num?)?.toInt() ?? rekhuProtocol);
      case 'text':
        return RekhuText('${json['text'] ?? ''}');
      case 'step':
        return RekhuStep('${json['label'] ?? ''}');
      case 'card':
        return RekhuCard.fromJson(json);
      case 'error':
        return RekhuError('${json['message'] ?? ''}');
      case 'done':
        return const RekhuDone();
    }
    return null;
  }
}

/// Always first: the conversation to send with the next turn.
class RekhuStart extends RekhuEvent {
  const RekhuStart({required this.conversation, required this.protocol});
  final String conversation;
  final int protocol;
}

/// A piece of the answer, in markdown: append it to the current answer.
class RekhuText extends RekhuEvent {
  const RekhuText(this.text);
  final String text;
}

/// The assistant is doing something ("Looking up your orders"); it ends when the next event comes.
class RekhuStep extends RekhuEvent {
  const RekhuStep(this.label);
  final String label;
}

/// The turn could not finish: show [message] to the user as it is.
class RekhuError extends RekhuEvent {
  const RekhuError(this.message);
  final String message;
}

/// Always last when the turn finished.
class RekhuDone extends RekhuEvent {
  const RekhuDone();
}

/// What a card is: a page to open, an action to confirm, an action that ran, an action that was refused or failed.
enum RekhuCardKind { page, confirm, done, failed, unknown }

/// Something to show or click (PROTOCOL.md, "Cards").
class RekhuCard extends RekhuEvent {
  const RekhuCard({required this.kind, this.label, this.url, this.title, this.message, this.id, this.input = const {}, this.danger = false});

  factory RekhuCard.fromJson(Map<String, dynamic> json) => RekhuCard(
        kind: RekhuCardKind.values.firstWhere((k) => k.name == json['kind'], orElse: () => RekhuCardKind.unknown),
        label: json['label'] as String?,
        url: json['url'] as String?,
        title: json['title'] as String?,
        message: json['message'] as String?,
        id: json['id'] as String?,
        input: json['input'] is Map ? Map<String, dynamic>.from(json['input'] as Map) : const {},
        danger: json['danger'] == true,
      );

  final RekhuCardKind kind;

  /// page: the button text.
  final String? label;

  /// page: where it goes; done or failed: a page to open afterwards.
  final String? url;

  /// confirm, done, failed: what the action is.
  final String? title;

  /// done, failed: what came of it.
  final String? message;

  /// confirm: the id to send back when the user confirms.
  final String? id;

  /// confirm: the input the action will run with, as shown to the user.
  final Map<String, dynamic> input;

  /// confirm: a destructive action.
  final bool danger;
}

/// One message of a conversation as the user saw it.
class RekhuMessage {
  const RekhuMessage({required this.fromUser, required this.text});
  final bool fromUser;

  /// Markdown for the assistant's answers, plain text for the user's.
  final String text;
}

/// What the server answers about a conversation (PROTOCOL.md, "GET").
class RekhuHistory {
  const RekhuHistory({this.conversation, this.messages = const [], this.greeting, this.quick = const []});

  factory RekhuHistory.fromJson(Map<String, dynamic> json) => RekhuHistory(
        conversation: json['conversation'] as String?,
        messages: [
          for (final m in (json['messages'] as List? ?? const []))
            if (m is Map) RekhuMessage(fromUser: m['role'] == 'user', text: '${m['text'] ?? ''}'),
        ],
        greeting: json['greeting'] as String?,
        quick: [for (final q in (json['quick'] as List? ?? const [])) '$q'],
      );

  final String? conversation;
  final List<RekhuMessage> messages;

  /// The server's first message for a fresh chat, in markdown, in the user's language.
  final String? greeting;

  /// The developer's quick questions for a fresh chat; a tap sends one as the user's message.
  final List<String> quick;
}

/// A call that failed before the answer started: [message] is what to tell the user; [status] the HTTP status.
class RekhuException implements Exception {
  const RekhuException(this.message, {this.status});
  final String message;
  final int? status;

  /// The user's session ended (401, 419): sign them in again.
  bool get signedOut => status == 401 || status == 419;

  @override
  String toString() => 'RekhuException($status): $message';
}

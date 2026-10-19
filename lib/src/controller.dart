import 'package:flutter/foundation.dart';

import 'client.dart';
import 'protocol.dart';
import 'texts.dart';

/// One thing in the chat, in order: the user's message, an answer, a step, a card, an error.
sealed class RekhuItem {}

class RekhuUserItem extends RekhuItem {
  RekhuUserItem(this.text);
  final String text;
}

/// An answer, in markdown; it grows while it streams.
class RekhuBotItem extends RekhuItem {
  RekhuBotItem(this.text);
  String text;
}

/// What the assistant is doing; [over] once the next event came.
class RekhuStepItem extends RekhuItem {
  RekhuStepItem(this.label);
  final String label;
  bool over = false;
}

enum RekhuCardState { open, confirmed, cancelled }

/// A card; a confirm card is [RekhuCardState.open] until the user confirms or cancels it.
class RekhuCardItem extends RekhuItem {
  RekhuCardItem(this.card);
  final RekhuCard card;
  RekhuCardState state = RekhuCardState.open;
}

class RekhuErrorItem extends RekhuItem {
  RekhuErrorItem(this.message);
  final String message;
}

/// The chat as state: what to show, and what the user can do. [RekhuChat] draws it; a screen of your own can too.
///
/// ```dart
/// final chat = RekhuChatController(client: client);
/// await chat.load();                 // the earlier messages, or the greeting and quick questions
/// await chat.send('Where is my order?');
/// ```
class RekhuChatController extends ChangeNotifier {
  RekhuChatController({required this.client, this.greeting, List<String>? quick, RekhuTexts? texts, this.onAction})
      : _quickOwn = quick,
        texts = texts ?? RekhuTexts.of(client.locale);

  final RekhuAssistantClient client;
  final RekhuTexts texts;

  /// Your own first message, in markdown, instead of the server's greeting.
  String? greeting;

  /// Called after an action ran (a done card): the app's data changed, so refresh what the screen shows.
  final void Function(RekhuCard card)? onAction;

  final List<String>? _quickOwn;
  final List<RekhuItem> items = [];
  List<String> quick = const [];
  bool sending = false;
  bool loaded = false;

  /// The user's session ended: the app signs them in again.
  bool signedOut = false;

  /// The earlier messages of this conversation, or for a fresh chat the greeting and quick questions.
  Future<void> load() async {
    try {
      final h = await client.history();
      items
        ..clear()
        ..addAll(h.messages.map((m) => m.fromUser ? RekhuUserItem(m.text) : RekhuBotItem(m.text)));
      greeting ??= h.greeting;
      quick = h.messages.isEmpty ? (_quickOwn ?? h.quick) : const [];
    } on RekhuException catch (e) {
      signedOut = e.signedOut;
      items.add(RekhuErrorItem(e.message));
    } catch (_) {
      items.add(RekhuErrorItem(texts.unavailable));
    }
    loaded = true;
    notifyListeners();
  }

  /// Sends what the user typed (or a quick question).
  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty || sending) return;
    items.add(RekhuUserItem(message));
    quick = const [];
    await _run(client.send(message));
  }

  /// Runs the action behind a confirm card.
  Future<void> confirm(RekhuCardItem item) async {
    if (sending || item.state != RekhuCardState.open || item.card.id == null) return;
    item.state = RekhuCardState.confirmed;
    await _run(client.confirm(item.card.id!));
  }

  /// Cancelling is an ordinary message: nothing runs.
  Future<void> cancel(RekhuCardItem item) async {
    if (sending || item.state != RekhuCardState.open) return;
    item.state = RekhuCardState.cancelled;
    await send(texts.cancelled);
  }

  /// A new conversation: the server forgets this one.
  Future<void> reset() async {
    await client.forget();
    items.clear();
    loaded = false;
    notifyListeners();
    await load();
  }

  Future<void> _run(Stream<RekhuEvent> events) async {
    sending = true;
    notifyListeners();
    RekhuBotItem? answer;
    void endSteps() {
      for (final i in items) {
        if (i is RekhuStepItem) i.over = true;
      }
    }

    try {
      await for (final e in events) {
        switch (e) {
          case RekhuText(:final text):
            // a text after a step or a card starts a new answer
            if (answer == null || items.last != answer) {
              answer = RekhuBotItem('');
              items.add(answer);
            }
            endSteps();
            answer.text += text;
          case RekhuStep(:final label):
            endSteps();
            items.add(RekhuStepItem(label));
          case RekhuCard card:
            endSteps();
            items.add(RekhuCardItem(card));
            if (card.kind == RekhuCardKind.done) onAction?.call(card);
          case RekhuError(:final message):
            endSteps();
            items.add(RekhuErrorItem(message.isEmpty ? texts.failed : message));
          case RekhuStart():
          case RekhuDone():
            endSteps();
        }
        notifyListeners();
      }
    } on RekhuException catch (e) {
      signedOut = e.signedOut;
      items.add(RekhuErrorItem(e.message));
    } catch (_) {
      items.add(RekhuErrorItem(texts.unavailable));
    } finally {
      endSteps();
      sending = false;
      notifyListeners();
    }
  }
}

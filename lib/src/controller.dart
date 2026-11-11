import 'dart:async';

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

  /// The user has a list of earlier conversations (signed in); false for the public chat.
  bool history = false;

  /// The earlier conversations loaded so far, newest first.
  final List<RekhuConversation> conversations = [];

  /// The list is being fetched.
  bool conversationsLoading = false;

  /// The list was fetched at least once, so an empty list means there is none.
  bool conversationsLoaded = false;

  /// The cursor of the next page; null on the last page.
  String? conversationsNext;

  /// What the list is searched for; empty for all.
  String conversationsQuery = '';

  /// Whether the list is shown; null lets [RekhuChat] decide by the screen's width.
  bool? conversationsShown;

  int _listRun = 0;

  /// The conversation that is open; null for a new chat.
  String? get current => client.conversation;

  /// The earlier messages of this conversation, or for a fresh chat the greeting and quick questions.
  Future<void> load() => _show(client.history);

  /// Opens an earlier conversation from the list.
  Future<void> open(String id) async {
    if (sending) return;
    items.clear();
    quick = const [];
    loaded = false;
    notifyListeners();
    await _show(() => client.open(id));
  }

  /// A new chat: the current conversation stays in the list, the next message starts a new one.
  Future<void> newChat() async {
    if (sending) return;
    await client.newChat();
    items.clear();
    loaded = false;
    notifyListeners();
    await load();
  }

  /// Fetches the history and shows it; the first time it says there is a list, the list is fetched too.
  Future<void> _show(Future<RekhuHistory> Function() fetch) async {
    try {
      final h = await fetch();
      items
        ..clear()
        ..addAll(h.messages.map((m) => m.fromUser ? RekhuUserItem(m.text) : RekhuBotItem(m.text)));
      greeting ??= h.greeting;
      quick = h.messages.isEmpty ? (_quickOwn ?? h.quick) : const [];
      history = h.history;
    } on RekhuException catch (e) {
      signedOut = e.signedOut;
      items.add(RekhuErrorItem(e.message));
    } catch (_) {
      items.add(RekhuErrorItem(texts.unavailable));
    }
    loaded = true;
    notifyListeners();
    if (history && !conversationsLoaded && !conversationsLoading) unawaited(loadConversations());
  }

  /// Fetches the first page of the list again, searched for [query] (the current search when left out).
  Future<void> loadConversations({String? query}) async {
    if (query != null) conversationsQuery = query.trim();
    final run = ++_listRun;
    conversationsLoading = true;
    notifyListeners();
    try {
      final page = await client.conversations(query: conversationsQuery);
      if (run != _listRun) return;
      conversations
        ..clear()
        ..addAll(page.items);
      conversationsNext = page.next;
    } catch (_) {
      if (run != _listRun) return;
    }
    conversationsLoading = false;
    conversationsLoaded = true;
    notifyListeners();
  }

  /// Fetches the next page of the list, when there is one.
  Future<void> moreConversations() async {
    final next = conversationsNext;
    if (next == null || conversationsLoading) return;
    final run = ++_listRun;
    conversationsLoading = true;
    notifyListeners();
    try {
      final page = await client.conversations(query: conversationsQuery, before: next);
      if (run != _listRun) return;
      final known = {for (final c in conversations) c.id};
      conversations.addAll(page.items.where((c) => !known.contains(c.id)));
      conversationsNext = page.next;
    } catch (_) {
      if (run != _listRun) return;
    }
    conversationsLoading = false;
    notifyListeners();
  }

  /// Names a conversation; an empty title goes back to its first question. One that is gone leaves the list.
  Future<void> renameConversation(String id, String title) async {
    try {
      final renamed = await client.renameConversation(id, title);
      final i = conversations.indexWhere((c) => c.id == id);
      if (i != -1) conversations[i] = renamed;
    } on RekhuException catch (e) {
      if (e.status != 404) rethrow;
      conversations.removeWhere((c) => c.id == id);
    }
    notifyListeners();
  }

  /// Deletes a conversation for good; when it is the open one, a new chat starts.
  Future<void> deleteConversation(String id) async {
    final wasOpen = current == id;
    await client.deleteConversation(id);
    conversations.removeWhere((c) => c.id == id);
    notifyListeners();
    if (wasOpen) {
      items.clear();
      loaded = false;
      notifyListeners();
      await load();
    }
  }

  /// Shows or hides the list of conversations.
  void showConversations(bool shown) {
    conversationsShown = shown;
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

  /// A new chat; the same as [newChat], which keeps the current conversation in the list.
  @Deprecated('Use newChat(); deleting is client.deleteConversation(id).')
  Future<void> reset() => newChat();

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
      // the conversation just answered moves to the top of the list
      if (history) unawaited(loadConversations());
    }
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import 'client.dart';
import 'controller.dart';
import 'markdown.dart';
import 'protocol.dart';
import 'texts.dart';

/// The chat's colours and shapes; anything left out follows the app's Theme.
class RekhuChatTheme {
  const RekhuChatTheme({this.accent, this.background, this.surface, this.border, this.radius = 14});
  final Color? accent;
  final Color? background;
  final Color? surface;
  final Color? border;
  final double radius;
}

/// A ready chat screen for Rekhu Assistant: answers as they stream, steps, page buttons, confirm cards, quick
/// questions, in the user's language and direction (Arabic right to left). Put it in a page, a tab or a sheet
/// ([RekhuChat.show]); for a design of your own, use [RekhuChatController] with your own widgets.
class RekhuChat extends StatefulWidget {
  const RekhuChat({super.key, this.client, this.controller, this.onOpenPage, this.onAction, this.greeting, this.quick, this.texts, this.theme = const RekhuChatTheme(), this.header = true})
      : assert(client != null || controller != null, 'give a client or a controller');

  final RekhuAssistantClient? client;

  /// Your own controller, to share the chat with other screens; made from [client] when left out.
  final RekhuChatController? controller;

  /// Opens a page card's address with the app's router: an app path such as "/orders/12", or a full URL.
  final void Function(String url)? onOpenPage;

  /// Called after an action ran: the app's data changed.
  final void Function(RekhuCard card)? onAction;

  /// Your own first message, in markdown, instead of the server's greeting.
  final String? greeting;

  /// Quick questions for a fresh chat, instead of the server's.
  final List<String>? quick;
  final RekhuTexts? texts;
  final RekhuChatTheme theme;

  /// The bar with the name, "New" and, for a signed-in user, the button that shows the conversations.
  final bool header;

  /// The chat in a bottom sheet over the current screen.
  static Future<void> show(BuildContext context, {RekhuAssistantClient? client, RekhuChatController? controller, void Function(String url)? onOpenPage, void Function(RekhuCard card)? onAction, RekhuChatTheme theme = const RekhuChatTheme()}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: RekhuChat(client: client, controller: controller, onOpenPage: onOpenPage, onAction: onAction, theme: theme),
        ),
      ),
    );
  }

  @override
  State<RekhuChat> createState() => _RekhuChatState();
}

class _RekhuChatState extends State<RekhuChat> {
  late final RekhuChatController chat;
  late final bool _own;
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _own = widget.controller == null;
    chat = widget.controller ?? RekhuChatController(client: widget.client!, greeting: widget.greeting, quick: widget.quick, texts: widget.texts, onAction: widget.onAction);
    chat.addListener(_changed);
    if (!chat.loaded) chat.load();
  }

  @override
  void dispose() {
    chat.removeListener(_changed);
    if (_own) chat.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    // the newest message stays in view while the answer streams
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty || chat.sending) return;
    _input.clear();
    chat.send(text);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) => _build(context, size.maxWidth));

  /// The chat, with the list of conversations beside it on a wide screen or over it on a narrow one.
  Widget _build(BuildContext context, double width) {
    final theme = Theme.of(context);
    final t = chat.texts;
    final accent = widget.theme.accent ?? theme.colorScheme.primary;
    final surface = widget.theme.surface ?? theme.colorScheme.surface;
    final border = widget.theme.border ?? theme.dividerColor;
    final background = widget.theme.background ?? theme.colorScheme.surfaceContainerLowest;
    final r = widget.theme.radius;

    Widget bubble(Widget child, {required bool mine}) => Align(
          alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: mine ? accent : surface,
                border: mine ? null : Border.all(color: border),
                borderRadius: BorderRadiusDirectional.only(
                  topStart: Radius.circular(r),
                  topEnd: Radius.circular(r),
                  bottomStart: Radius.circular(mine ? r : 4),
                  bottomEnd: Radius.circular(mine ? 4 : r),
                ),
              ),
              child: child,
            ),
          ),
        );

    Widget card(RekhuCardItem item) {
      final c = item.card;
      final good = c.kind == RekhuCardKind.done;
      final bad = c.kind == RekhuCardKind.failed;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: good ? const Color(0xFFECFDF5) : bad ? const Color(0xFFFEF2F2) : surface,
          border: Border.all(color: good ? const Color(0xFFA7F3D0) : bad ? const Color(0xFFFECACA) : border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c.title != null) Text(c.title!, style: theme.textTheme.titleSmall),
            if (c.message != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(c.message!, style: theme.textTheme.bodySmall)),
            if (c.kind == RekhuCardKind.confirm && c.input.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in c.input.entries)
                      Text.rich(TextSpan(children: [TextSpan(text: '${e.key}: ', style: TextStyle(color: theme.hintColor)), TextSpan(text: '${e.value}')]), style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            if (c.kind == RekhuCardKind.page || (c.url != null && c.kind != RekhuCardKind.confirm))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton(style: FilledButton.styleFrom(backgroundColor: accent), onPressed: c.url == null ? null : () => widget.onOpenPage?.call(c.url!), child: Text(c.label ?? t.open)),
              ),
            if (c.kind == RekhuCardKind.confirm)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: item.state == RekhuCardState.open
                    ? Wrap(spacing: 8, children: [
                        FilledButton(style: FilledButton.styleFrom(backgroundColor: c.danger ? const Color(0xFFDC2626) : accent), onPressed: chat.sending ? null : () => chat.confirm(item), child: Text(t.confirm)),
                        OutlinedButton(onPressed: chat.sending ? null : () => chat.cancel(item), child: Text(t.cancel)),
                      ])
                    : Text(item.state == RekhuCardState.confirmed ? t.confirmed : t.cancel, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
              ),
          ],
        ),
      );
    }

    final rows = <Widget>[
      if (chat.greeting != null)
        bubble(RekhuMarkdown(chat.greeting!, linkColor: accent, onLink: widget.onOpenPage), mine: false),
      for (final item in chat.items)
        switch (item) {
          RekhuUserItem(:final text) => bubble(Text(text, style: TextStyle(color: theme.colorScheme.onPrimary)), mine: true),
          RekhuBotItem(:final text) => bubble(RekhuMarkdown(text, linkColor: accent, onLink: widget.onOpenPage), mine: false),
          RekhuStepItem() => Row(children: [
              Icon(Icons.circle, size: 8, color: item.over ? theme.disabledColor : accent),
              const SizedBox(width: 6),
              Flexible(child: Text(item.label, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor))),
            ]),
          RekhuCardItem() => card(item),
          RekhuErrorItem(:final message) => Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
              child: Text(message, style: const TextStyle(color: Color(0xFF991B1B))),
            ),
        },
      if (chat.quick.isNotEmpty)
        Wrap(spacing: 6, runSpacing: 6, children: [for (final q in chat.quick) ActionChip(label: Text(q), onPressed: () => chat.send(q))]),
    ];

    final wide = width >= 720;
    final shown = chat.history && (chat.conversationsShown ?? wide);
    final body = Material(
      color: background,
      child: Column(
        children: [
          if (widget.header)
            Container(
              color: accent,
              padding: EdgeInsetsDirectional.fromSTEB(chat.history ? 4 : 16, 10, 8, 10),
              child: Row(children: [
                if (chat.history)
                  IconButton(tooltip: t.conversations, onPressed: () => chat.showConversations(!shown), icon: Icon(Icons.menu, color: theme.colorScheme.onPrimary)),
                Expanded(child: Text(t.name, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimary))),
                TextButton(onPressed: chat.sending ? null : chat.newChat, child: Text(t.newChat, style: TextStyle(color: theme.colorScheme.onPrimary))),
              ]),
            ),
          Expanded(
            child: !chat.loaded
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(controller: _scroll, padding: const EdgeInsets.all(14), itemCount: rows.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (_, i) => rows[i]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 4000,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(hintText: t.placeholder, counterText: '', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(style: IconButton.styleFrom(backgroundColor: accent), tooltip: t.send, onPressed: chat.sending ? null : _send, icon: const Icon(Icons.send)),
              ]),
            ),
          ),
        ],
      ),
    );

    final Widget page;
    if (!shown) {
      page = body;
    } else {
      final list = _RekhuConversations(chat: chat, accent: accent, wrap: _direction, onPicked: wide ? null : () => chat.showConversations(false));
      page = wide
          ? Row(children: [SizedBox(width: 280, child: list), VerticalDivider(width: 1, color: border), Expanded(child: body)])
          : Stack(children: [body, Positioned.fill(child: list)]);
    }
    return _direction(page);
  }

  /// The user's language decides the direction: Arabic reads right to left whatever the app's own locale.
  Widget _direction(Widget child) => RekhuTexts.rtl(chat.client.locale) ? Directionality(textDirection: TextDirection.rtl, child: child) : child;
}

/// The list of earlier conversations: new chat, search, rows that open one, rename and delete, more on scroll.
class _RekhuConversations extends StatefulWidget {
  const _RekhuConversations({required this.chat, required this.accent, required this.wrap, this.onPicked});
  final RekhuChatController chat;
  final Color accent;

  /// Puts a dialog in the chat's direction.
  final Widget Function(Widget child) wrap;

  /// Called after a conversation was picked or a new chat started; closes the list on a narrow screen.
  final VoidCallback? onPicked;

  @override
  State<_RekhuConversations> createState() => _RekhuConversationsState();
}

class _RekhuConversationsState extends State<_RekhuConversations> {
  late final _search = TextEditingController(text: widget.chat.conversationsQuery);
  Timer? _typing;

  @override
  void dispose() {
    _typing?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Searches a moment after the user stops typing.
  void _searchFor(String query) {
    _typing?.cancel();
    _typing = Timer(const Duration(milliseconds: 300), () => widget.chat.loadConversations(query: query));
  }

  /// The time for today, a short date otherwise, in the app's own date format.
  String _when(BuildContext context, DateTime? at) {
    if (at == null) return '';
    final l = MaterialLocalizations.of(context);
    final local = at.toLocal();
    final now = DateTime.now();
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      return l.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.maybeAlwaysUse24HourFormatOf(context) ?? false);
    }
    return local.year == now.year ? l.formatShortMonthDay(local) : l.formatShortDate(local);
  }

  /// Asks for a new name and saves it.
  Future<void> _rename(RekhuConversation c) async {
    final t = widget.chat.texts;
    final field = TextEditingController(text: c.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => widget.wrap(AlertDialog(
        title: Text(t.renameTitle),
        content: TextField(
          controller: field,
          autofocus: true,
          maxLength: 80,
          decoration: InputDecoration(hintText: t.renameHint),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, field.text), child: Text(t.save)),
        ],
      )),
    );
    if (title == null) return;
    try {
      await widget.chat.renameConversation(c.id, title);
    } catch (_) {/* the list keeps the old name */}
  }

  /// Asks before deleting for good.
  Future<void> _delete(RekhuConversation c) async {
    final t = widget.chat.texts;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => widget.wrap(AlertDialog(
        title: Text(t.deleteTitle),
        content: Text(t.deleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)), onPressed: () => Navigator.pop(context, true), child: Text(t.delete)),
        ],
      )),
    );
    if (sure != true) return;
    try {
      await widget.chat.deleteConversation(c.id);
    } catch (_) {/* it stays in the list */}
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final t = chat.texts;
    final theme = Theme.of(context);
    final list = chat.conversations;
    final rows = list.length + (chat.conversationsLoading || chat.conversationsNext != null ? 1 : 0);

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 12, 4),
              child: Row(children: [
                IconButton(tooltip: t.conversations, onPressed: () => chat.showConversations(false), icon: const Icon(Icons.menu)),
                Expanded(child: Text(t.conversations, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis)),
                FilledButton.tonalIcon(
                  onPressed: chat.sending
                      ? null
                      : () {
                          chat.newChat();
                          widget.onPicked?.call();
                        },
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(t.newConversation),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 8),
              child: TextField(
                controller: _search,
                onChanged: _searchFor,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(hintText: t.search, prefixIcon: const Icon(Icons.search, size: 20), isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
            Expanded(
              child: list.isEmpty && chat.conversationsLoaded && !chat.conversationsLoading
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(chat.conversationsQuery.isEmpty ? t.noConversations : t.nothingFound, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor), textAlign: TextAlign.center),
                    )
                  : ListView.builder(
                      itemCount: rows,
                      itemBuilder: (context, i) {
                        if (i >= list.length) {
                          // the last row in view fetches the next page
                          if (!chat.conversationsLoading) WidgetsBinding.instance.addPostFrameCallback((_) => chat.moreConversations());
                          return const Padding(padding: EdgeInsets.all(12), child: Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))));
                        }
                        final c = list[i];
                        final when = _when(context, c.updatedAt);
                        return ListTile(
                          key: ValueKey('rekhu-conversation-${c.id}'),
                          dense: true,
                          selected: c.id == chat.current,
                          selectedColor: widget.accent,
                          selectedTileColor: widget.accent.withAlpha(20),
                          contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 4),
                          title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text([if (when.isNotEmpty) when, t.questionCount(c.questions)].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: chat.sending
                              ? null
                              : () {
                                  if (c.id != chat.current) chat.open(c.id);
                                  widget.onPicked?.call();
                                },
                          trailing: PopupMenuButton<String>(
                            tooltip: t.more,
                            icon: const Icon(Icons.more_horiz),
                            onSelected: (v) => v == 'rename' ? _rename(c) : _delete(c),
                            itemBuilder: (context) => [
                              PopupMenuItem(value: 'rename', child: widget.wrap(Text(t.rename))),
                              PopupMenuItem(value: 'delete', child: widget.wrap(Text(t.delete))),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

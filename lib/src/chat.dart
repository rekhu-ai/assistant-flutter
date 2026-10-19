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

  /// The bar with the name and "New".
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
  Widget build(BuildContext context) {
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

    final body = Material(
      color: background,
      child: Column(
        children: [
          if (widget.header)
            Container(
              color: accent,
              padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 8, 10),
              child: Row(children: [
                Expanded(child: Text(t.name, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimary))),
                TextButton(onPressed: chat.sending ? null : chat.reset, child: Text(t.newChat, style: TextStyle(color: theme.colorScheme.onPrimary))),
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

    // the user's language decides the direction: Arabic reads right to left whatever the app's own locale
    return RekhuTexts.rtl(chat.client.locale) ? Directionality(textDirection: TextDirection.rtl, child: body) : body;
  }
}

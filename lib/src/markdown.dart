import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A piece of a line: plain, **bold**, *italic*, `code` or a link to http(s) or one of the app's own paths.
class RekhuInline {
  const RekhuInline(this.text, {this.bold = false, this.italic = false, this.code = false, this.link});
  final String text;
  final bool bold;
  final bool italic;
  final bool code;

  /// Where a link goes; never javascript:, data: or another host without a scheme.
  final String? link;
}

/// A paragraph, or an item of a "-" or "1." list.
class RekhuBlock {
  const RekhuBlock(this.inlines, {this.bullet, this.number});
  final List<RekhuInline> inlines;

  /// True for an item of a "-" list.
  final bool? bullet;

  /// The number of an item of a "1." list.
  final int? number;
}

/// The answers' small markdown (PROTOCOL.md, "Text"): paragraphs, lists, bold, italics, code and safe links. Nothing
/// else is interpreted, so a reply can never become anything but text and links.
List<RekhuBlock> parseRekhuMarkdown(String text) {
  final blocks = <RekhuBlock>[];
  var n = 0;
  for (final line in text.split('\n')) {
    final item = RegExp(r'^\s*([-*]|\d+\.)\s+(.*)$').firstMatch(line);
    if (item != null) {
      final numbered = item.group(1)!.endsWith('.');
      n = numbered ? n + 1 : 0;
      blocks.add(RekhuBlock(_inlines(item.group(2)!), bullet: !numbered, number: numbered ? n : null));
      continue;
    }
    n = 0;
    if (line.trim().isNotEmpty) blocks.add(RekhuBlock(_inlines(line)));
  }
  return blocks;
}

final _token = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`|\[([^\]]+)\]\(((?:https?://|/(?!/))[^\s)]+)\)|(?<![*\w])\*([^*]+)\*');

List<RekhuInline> _inlines(String line) {
  final out = <RekhuInline>[];
  var at = 0;
  for (final m in _token.allMatches(line)) {
    if (m.start > at) out.add(RekhuInline(line.substring(at, m.start)));
    if (m.group(1) != null) {
      out.add(RekhuInline(m.group(1)!, bold: true));
    } else if (m.group(2) != null) {
      out.add(RekhuInline(m.group(2)!, code: true));
    } else if (m.group(3) != null) {
      out.add(RekhuInline(m.group(3)!, link: m.group(4)));
    } else {
      out.add(RekhuInline(m.group(5)!, italic: true));
    }
    at = m.end;
  }
  if (at < line.length) out.add(RekhuInline(line.substring(at)));
  return out;
}

/// An answer's markdown as text: links call [onLink] with their address (an app path such as "/orders/12", or a full URL).
class RekhuMarkdown extends StatefulWidget {
  const RekhuMarkdown(this.text, {super.key, this.style, this.linkColor, this.onLink});
  final String text;
  final TextStyle? style;
  final Color? linkColor;
  final void Function(String url)? onLink;

  @override
  State<RekhuMarkdown> createState() => _RekhuMarkdownState();
}

class _RekhuMarkdownState extends State<RekhuMarkdown> {
  final _taps = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  InlineSpan _span(RekhuInline i, TextStyle base) {
    var style = base;
    if (i.bold) style = style.copyWith(fontWeight: FontWeight.w600);
    if (i.italic) style = style.copyWith(fontStyle: FontStyle.italic);
    if (i.code) style = style.copyWith(fontFamily: 'monospace', backgroundColor: const Color(0x14000000));
    if (i.link == null) return TextSpan(text: i.text, style: style);
    final tap = TapGestureRecognizer()..onTap = () => widget.onLink?.call(i.link!);
    _taps.add(tap);
    return TextSpan(text: i.text, style: style.copyWith(color: widget.linkColor, decoration: TextDecoration.underline), recognizer: tap);
  }

  @override
  Widget build(BuildContext context) {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    final base = widget.style ?? DefaultTextStyle.of(context).style;
    final blocks = parseRekhuMarkdown(widget.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == blocks.length - 1 ? 0 : 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (blocks[i].bullet == true) Text('•  ', style: base),
                if (blocks[i].number != null) Text('${blocks[i].number}.  ', style: base),
                Flexible(child: Text.rich(TextSpan(children: [for (final s in blocks[i].inlines) _span(s, base)]))),
              ],
            ),
          ),
      ],
    );
  }
}

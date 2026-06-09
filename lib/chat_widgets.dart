import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'agent_format.dart';
import 'api_service.dart';

// ====================================================================
// Typing dots — chat mode
// ====================================================================
class TypingDotsWidget extends StatelessWidget {
  const TypingDotsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 24,
      height: 24,
      child: CupertinoActivityIndicator(radius: 8),
    );
  }
}

// ====================================================================
// Web search animation — orbiting dots around a globe
// ====================================================================
class WebSearchingWidget extends StatefulWidget {
  const WebSearchingWidget({super.key});
  @override State<WebSearchingWidget> createState() => _WebSearchingState();
}
class _WebSearchingState extends State<WebSearchingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 28, height: 28,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            return CustomPaint(painter: _OrbitPainter(_ctrl.value));
          },
        ),
      ),
      const SizedBox(width: 10),
      const Text('Searching the web…',
        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93), fontStyle: FontStyle.italic)),
    ]);
  }
}

class _OrbitPainter extends CustomPainter {
  final double t;
  _OrbitPainter(this.t);
  @override void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = size.width / 2 - 3;
    // Globe lines
    final gray = Paint()..color = const Color(0xFFD1D1D6)..strokeWidth = 1..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(cx, cy), r, gray);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 0.9), gray);
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), gray);
    // Orbiting dot
    final angle = t * 2 * 3.14159;
    final dot = Paint()..color = const Color(0xFF8E8E93);
    canvas.drawCircle(Offset(cx + r * _orbitX(angle), cy + r * 0.5 * _orbitY(angle)), 3.5, dot);
  }
  double _orbitX(double a) => -lerpDouble(-1, 1, (a % (2 * 3.14159)) / (2 * 3.14159))!;
  double _orbitY(double a) => -lerpDouble(-1, 1, (a % (3.14159)) / 3.14159)!;
  @override bool shouldRepaint(_OrbitPainter old) => old.t != t;
}

// ====================================================================
// Thinking panel — opens during stream, collapses when done
// ====================================================================
class ThinkingPanel extends StatefulWidget {
  final String content;
  final bool isStreaming; // true = auto-open, false = auto-close
  const ThinkingPanel({super.key, required this.content, this.isStreaming = false});
  @override State<ThinkingPanel> createState() => _ThinkingPanelState();
}
class _ThinkingPanelState extends State<ThinkingPanel> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _expanded = false;
  bool _userToggled = false;

  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    // Auto-open when streaming starts
    if (widget.isStreaming) _setExpanded(true);
  }

  @override void didUpdateWidget(ThinkingPanel old) {
    super.didUpdateWidget(old);
    // When streaming ends, auto-collapse unless user manually opened it
    if (old.isStreaming && !widget.isStreaming && !_userToggled) {
      _setExpanded(false);
    }
    // When streaming starts, auto-open
    if (!old.isStreaming && widget.isStreaming && !_userToggled) {
      _setExpanded(true);
    }
  }

  void _setExpanded(bool v) {
    setState(() => _expanded = v);
    v ? _ctrl.forward() : _ctrl.reverse();
  }

  void _toggle() {
    _userToggled = true;
    _setExpanded(!_expanded);
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withOpacity(isDark ? 0.18 : 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              if (widget.isStreaming) ...[
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: _MiniCircleLoader(),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : CupertinoColors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.isStreaming ? 'Thinking live' : 'Reasoning',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              const Spacer(),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                child: const Icon(CupertinoIcons.chevron_down, size: 14, color: Color(0xFF8E8E93)),
              ),
            ]),
          ),
          SizeTransition(
            sizeFactor: _anim,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(widget.content,
                style: const TextStyle(fontSize: 13, height: 1.55, color: Color(0xFF6B7280), fontStyle: FontStyle.italic)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override State<_PulsingDot> createState() => _PulsingDotState();
}
class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Container(
      width: 6, height: 6,
      decoration: BoxDecoration(
        color: Color.lerp(CupertinoColors.systemGrey3, CupertinoColors.label, _c.value),
        shape: BoxShape.circle),
    ),
  );
}

class _MiniCircleLoader extends StatelessWidget {
  const _MiniCircleLoader();

  @override
  Widget build(BuildContext context) {
    return const CupertinoActivityIndicator(radius: 6);
  }
}

// ====================================================================
// Stable image widget — cached bytes to prevent blink
// ====================================================================
class _StableImage extends StatefulWidget {
  final String base64Data;
  final String cacheKey;
  final double? width;
  final BoxFit fit;
  const _StableImage({required this.base64Data, required this.cacheKey, this.width, this.fit = BoxFit.cover});
  @override State<_StableImage> createState() => _StableImageState();
}
class _StableImageState extends State<_StableImage> {
  late final List<int> _bytes;
  @override void initState() {
    super.initState();
    _bytes = base64Decode(widget.base64Data);
  }
  @override Widget build(BuildContext context) => Image.memory(
    Uint8List.fromList(_bytes),
    key: ValueKey(widget.cacheKey),
    width: widget.width, fit: widget.fit,
    gaplessPlayback: true,
  );
}

// ====================================================================
// Code block with copy button — custom builder
// ====================================================================
class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override Widget? visitElementAfter(element, TextStyle? preferredStyle) {
    if (element.tag != 'code') return null;
    final code = element.textContent;
    return _CopyableCodeBlock(code: code);
  }
}

class _CopyableCodeBlock extends StatefulWidget {
  final String code;
  const _CopyableCodeBlock({required this.code});
  @override State<_CopyableCodeBlock> createState() => _CopyableCodeBlockState();
}
class _CopyableCodeBlockState extends State<_CopyableCodeBlock> {
  bool _copied = false;
  void _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }
  @override Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? CupertinoColors.systemGrey6.darkColor : CupertinoColors.systemGrey6.color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 0),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _copy,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_copied ? CupertinoIcons.checkmark : CupertinoIcons.doc_on_doc,
                  size: 12, color: _copied ? const Color(0xFF34C759) : const Color(0xFF8E8E93)),
                const SizedBox(width: 4),
                Text(_copied ? 'Copied' : 'Copy',
                  style: TextStyle(fontSize: 11,
                    color: _copied ? const Color(0xFF34C759) : const Color(0xFF8E8E93))),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
          child: Text(widget.code,
            style: TextStyle(fontSize: 13, fontFamily: 'monospace', height: 1.5, color: CupertinoColors.label.resolveFrom(context))),
        ),
      ]),
    );
  }
}

// ====================================================================
// Agent Activity Widget
// ====================================================================
class AgentActivityWidget extends StatelessWidget {
  final String type;
  final String detail;
  final bool isStreaming;
  const AgentActivityWidget({
    super.key,
    required this.type,
    required this.detail,
    this.isStreaming = false,
  });

  @override Widget build(BuildContext context) {
    IconData icon;
    Color color;
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    color = const Color(0xFF6B7280);
    switch (type.toLowerCase()) {
      case 'search': icon = CupertinoIcons.search; break;
      case 'read_url': icon = CupertinoIcons.doc_text; break;
      case 'run_code': icon = CupertinoIcons.chevron_left_slash_chevron_right; break;
      case 'write_file': icon = CupertinoIcons.pencil_ellipsis_rectangle; break;
      case 'image_search': icon = CupertinoIcons.photo; break;
      case 'take_snapshot': icon = CupertinoIcons.camera_viewfinder; break;
      case 'create_diagram': icon = CupertinoIcons.flowchart; break;
      case 'create_chart': icon = CupertinoIcons.chart_bar_fill; break;
      default: icon = CupertinoIcons.bolt_fill;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF6F7F8),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withOpacity(isDark ? 0.16 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2E) : CupertinoColors.white,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _titleFor(type),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              detail.length > 80 ? '${detail.substring(0, 77)}...' : detail,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.35,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ]),
        ),
        if (isStreaming) ...[
          const SizedBox(width: 8),
          const SizedBox(width: 12, height: 12, child: _MiniCircleLoader()),
        ],
      ]),
    );
  }

  String _titleFor(String type) {
    switch (type.toLowerCase()) {
      case 'search':
        return 'Searching';
      case 'read_url':
        return 'Reading page';
      case 'run_code':
        return 'Running code';
      case 'write_file':
        return 'Writing file';
      case 'read_file':
        return 'Reading file';
      case 'image_search':
        return 'Finding images';
      case 'take_snapshot':
        return 'Capturing snapshot';
      case 'create_diagram':
        return 'Building diagram';
      case 'create_chart':
        return 'Building chart';
      case 'save_skill':
        return 'Saving skill';
      case 'load_skill':
        return 'Loading skill';
      default:
        return 'Working';
    }
  }
}

// ====================================================================
// Message bubble
// ====================================================================
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isPreStream;
  final bool isWebSearching;
  final bool isStreaming;
  final VoidCallback? onCopy;
  final VoidCallback? onRegenerate;
  final VoidCallback? onDoubleTapCopy; // user msg
  final VoidCallback? onEdit;          // user msg

  const MessageBubble({
    super.key,
    required this.message,
    this.isPreStream = false,
    this.isWebSearching = false,
    this.isStreaming = false,
    this.onCopy,
    this.onRegenerate,
    this.onDoubleTapCopy,
    this.onEdit,
  });

  @override Widget build(BuildContext context) {
    if (message.isUser) return _userBubble(context);
    if (isPreStream) return _preStreamBubble(context);
    return _aiBubble(context);
  }

  Widget _preStreamBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: BorderRadius.circular(18),
        ),
        child: isWebSearching ? const WebSearchingWidget() : const TypingDotsWidget(),
      ),
    );
  }

  Widget _userBubble(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final bubbleColor = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E7EB);
    final userTextColor = isDark ? CupertinoColors.white : const Color(0xFF1C1C1E);
    return GestureDetector(
      onDoubleTap: onDoubleTapCopy,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(maxWidth: w * 0.82),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (message.imageBase64 != null)
              RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _StableImage(
                    base64Data: message.imageBase64!,
                    cacheKey: 'uimg_${message.timestamp.millisecondsSinceEpoch}',
                    width: w * 0.55,
                  ),
                ),
              ),
            if (message.imageBase64 != null && message.text.isNotEmpty) const SizedBox(height: 6),
            if (message.text.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18), topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18), bottomRight: Radius.circular(4)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _linkDetect(message.text, isUser: true, userTextColor: userTextColor),
                  const SizedBox(height: 3),
                  Text(_time(message.timestamp),
                    style: TextStyle(fontSize: 10, color: userTextColor.withOpacity(0.68))),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _aiBubble(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final parsed = parseAgentContent(message.text, isStreaming: isStreaming);
    final thinkContent = parsed.thinking;
    final agentThought = parsed.thought;
    final agentAction = parsed.action?.name;
    final agentActionDetail = parsed.action?.input;
    final mainText = parsed.displayText;
    final showMessageActions = !isStreaming && (mainText.isNotEmpty || message.generatedImageBase64 != null || agentAction != null);

    // Detect images/snapshots in main text to show them properly
    final imageUrls = <String>[];
    final imgMatches = RegExp(r'https?://[^\s]+\.(?:png|jpg|jpeg|webp|gif)', caseSensitive: false).allMatches(mainText);
    for (final m in imgMatches) imageUrls.add(m.group(0)!);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: w * 0.92),
        padding: const EdgeInsets.only(left: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Thinking panel
          if (thinkContent != null && thinkContent.isNotEmpty)
            ThinkingPanel(content: thinkContent, isStreaming: isStreaming),

          // Agent Activity
          if (agentAction != null)
            AgentActivityWidget(
              type: agentAction,
              detail: (agentActionDetail == null || agentActionDetail.trim().isEmpty) ? 'Working…' : agentActionDetail,
              isStreaming: isStreaming,
            ),

          if (agentThought != null && isStreaming)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: CupertinoTheme.brightnessOf(context) == Brightness.dark
                    ? const Color(0xFF1C1C1E)
                    : const Color(0xFFF8F8F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                agentThought,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  fontStyle: FontStyle.italic,
                  height: 1.45,
                ),
              ),
            ),

          // Display found images or snapshots
          if (imageUrls.isNotEmpty && !isStreaming)
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: imageUrls.length,
                itemBuilder: (ctx, idx) => Container(
                  margin: const EdgeInsets.only(right: 8, bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(imageUrls[idx], height: 160, width: 220, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
                ),
              ),
            ),

          // Generated image — stable
          if (message.generatedImageBase64 != null) ...[
            RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _StableImage(
                  base64Data: message.generatedImageBase64!,
                  cacheKey: 'gen_${message.timestamp.millisecondsSinceEpoch}',
                  width: w * 0.75,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Main text with markdown + code copy + link detection
          if (mainText.isNotEmpty)
            MarkdownBody(
              data: mainText,
              onTapLink: (text, href, title) async {
                if (href != null) {
                  final uri = Uri.tryParse(href);
                  if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              builders: {'code': _CodeBlockBuilder()},
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(fontSize: 16, height: 1.5, color: CupertinoColors.label.resolveFrom(context)),
                code: TextStyle(fontSize: 13, fontFamily: 'monospace', color: CupertinoColors.label.resolveFrom(context)),
                codeblockDecoration: const BoxDecoration(),
                h1: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: CupertinoColors.label.resolveFrom(context)),
                h2: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: CupertinoColors.label.resolveFrom(context)),
                h3: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: CupertinoColors.label.resolveFrom(context)),
                a: const TextStyle(color: CupertinoColors.systemGrey, decoration: TextDecoration.underline),
              ),
            ),

          const SizedBox(height: 6),

          // Action buttons — only when not streaming
          if (showMessageActions)
            Row(children: [
              Text(_time(message.timestamp),
                style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93))),
              const SizedBox(width: 12),
              _actionBtn(CupertinoIcons.doc_on_doc, 'Copy', onCopy),
              const SizedBox(width: 4),
              _actionBtn(CupertinoIcons.arrow_counterclockwise, 'Retry', onRegenerate),
            ]),
        ]),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback? onTap) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F1F3), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: const Color(0xFF8E8E93)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
        ]),
      ),
    );
  }

  // Detect URLs in plain text and make them tappable
  Widget _linkDetect(String text, {bool isUser = false, Color? userTextColor}) {
    final urlRegex = RegExp(r'https?://[^\s]+');
    final matches = urlRegex.allMatches(text);
    final resolvedUserText = userTextColor ?? CupertinoColors.white;
    if (matches.isEmpty) {
      return Text(text, style: TextStyle(fontSize: 16, color: isUser ? resolvedUserText : CupertinoColors.label.resolveFrom(context)));
    }
    final spans = <InlineSpan>[];
    int last = 0;
    final textColor = isUser ? resolvedUserText : CupertinoColors.label.resolveFrom(context);
    final linkColor = isUser ? resolvedUserText.withOpacity(0.88) : CupertinoColors.systemGrey;
    for (final m in matches) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: TextStyle(color: textColor, fontSize: 16)));
      }
      final url = m.group(0)!;
      spans.add(WidgetSpan(child: GestureDetector(
        onTap: () async {
          final uri = Uri.tryParse(url);
          if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        child: Text(url, style: TextStyle(color: linkColor, fontSize: 16, decoration: TextDecoration.underline)),
      )));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: TextStyle(color: textColor, fontSize: 16)));
    }
    return RichText(text: TextSpan(children: spans));
  }

  String _time(DateTime t) => '${t.hour}:${t.minute.toString().padLeft(2,'0')}';
}

// ====================================================================
// Tools + Attach sheet (no image gen toggle — always on)
// ====================================================================
class ToolsSheet extends StatefulWidget {
  final bool searchEnabled;
  final ValueChanged<bool> onSearchChanged;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final bool hasBraveKey;
  final VoidCallback onSetBraveKey;

  const ToolsSheet({
    super.key,
    required this.searchEnabled,
    required this.onSearchChanged,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.hasBraveKey,
    required this.onSetBraveKey,
  });

  @override State<ToolsSheet> createState() => _ToolsSheetState();
}
class _ToolsSheetState extends State<ToolsSheet> {
  late bool _search;
  @override void initState() { super.initState(); _search = widget.searchEnabled; }

  @override Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(16)),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 36, height: 5,
          decoration: BoxDecoration(color: const Color(0xFFD1D1D6), borderRadius: BorderRadius.circular(2.5))),
        const SizedBox(height: 14),

        // ATTACH
        const Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          child: Align(alignment: Alignment.centerLeft,
            child: Text('ATTACH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93), letterSpacing: 0.6)))),
        const SizedBox(height: 6),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            _tile(CupertinoIcons.camera_fill, CupertinoColors.systemGrey, 'Take Photo', null,
              () { Navigator.pop(context); widget.onPickCamera(); }, true),
            _tile(CupertinoIcons.photo_fill_on_rectangle_fill, CupertinoColors.systemGrey, 'Choose from Library', null,
              () { Navigator.pop(context); widget.onPickGallery(); }, false),
          ]),
        ),
        const SizedBox(height: 16),

        // TOOLS
        const Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          child: Align(alignment: Alignment.centerLeft,
            child: Text('TOOLS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93), letterSpacing: 0.6)))),
        const SizedBox(height: 6),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context), borderRadius: BorderRadius.circular(14)),
          child: _tile(
            CupertinoIcons.globe, CupertinoColors.systemGrey, 'Web Search', 'Real-time results',
            null, false,
            trailing: CupertinoSwitch(
              value: _search,
              onChanged: (v) {
                if (v && !widget.hasBraveKey) {
                  Navigator.pop(context);
                  widget.onSetBraveKey();
                  return;
                }
                setState(() => _search = v);
                widget.onSearchChanged(v);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
      ])),
    );
  }

  Widget _tile(IconData icon, Color color, String label, String? sub, VoidCallback? onTap, bool div, {Widget? trailing}) {
    return Column(children: [
      CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Container(width: 34, height: 34,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 18, color: color)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 16, color: CupertinoColors.label.resolveFrom(context))),
              if (sub != null) Text(sub, style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
            ])),
            if (trailing != null) trailing,
          ]),
        ),
      ),
    ]);
  }
}

// ====================================================================
// Brave API key sheet
// ====================================================================
class BraveKeySheet extends StatefulWidget {
  final String initialKeys;
  final ValueChanged<String> onSave;
  const BraveKeySheet({super.key, required this.initialKeys, required this.onSave});
  @override State<BraveKeySheet> createState() => _BraveKeySheetState();
}
class _BraveKeySheetState extends State<BraveKeySheet> {
  late TextEditingController _ctrl;
  @override void initState() { super.initState(); _ctrl = TextEditingController(text: widget.initialKeys); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(16)),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 36, height: 5,
          decoration: BoxDecoration(color: const Color(0xFFD1D1D6), borderRadius: BorderRadius.circular(2.5))),
        const SizedBox(height: 14),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 20),
          child: Align(alignment: Alignment.centerLeft,
            child: Text('Brave Search API Keys', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)))),
        const SizedBox(height: 4),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('Add multiple keys separated by commas. Keys rotate automatically on errors.',
            style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)))),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: CupertinoColors.white, borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.all(14),
          child: CupertinoTextField(
            controller: _ctrl,
            placeholder: 'key1, key2, key3…',
            placeholderStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
            decoration: null, style: const TextStyle(fontSize: 15),
            maxLines: 4, minLines: 2, padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CupertinoButton(
            color: CupertinoColors.label.resolveFrom(context),
            borderRadius: BorderRadius.circular(12),
            onPressed: () { widget.onSave(_ctrl.text.trim()); Navigator.pop(context); },
            child: Center(child: Text('Save & Enable', style: TextStyle(color: CupertinoTheme.brightnessOf(context) == Brightness.dark ? CupertinoColors.black : CupertinoColors.white, fontWeight: FontWeight.w600))),
          ),
        ),
        const SizedBox(height: 8),
      ])),
    );
  }
}

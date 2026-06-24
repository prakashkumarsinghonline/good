import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'agent_format.dart';
import 'api_service.dart';
import 'chat_widgets.dart';
import 'profile_page.dart';
import 'web_search_service.dart';
import 'tool_service.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarBrightness: Brightness.light,
  ));
  runApp(const AhamAIApp());
}

class AhamAIApp extends StatelessWidget {
  const AhamAIApp({super.key});
  @override
  Widget build(BuildContext context) => const CupertinoApp(
    title: 'AhamAI',
    debugShowCheckedModeBanner: false,
    theme: CupertinoThemeData(
      primaryColor: CupertinoColors.label,
    ),
    home: ChatHomePage(),
  );
}

// ====================================================================
// Chat Home Page
// ====================================================================
class ChatHomePage extends StatefulWidget {
  const ChatHomePage({super.key});
  @override
  State<ChatHomePage> createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage> with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isLoading = false;
  bool _isWebSearching = false; // true while fetching search results
  bool _searchEnabled = false;
  String? _streamingMsgId;
  String _chatTitle = '';
  bool _titleGenerated = false;
  void Function()? _stopStream;

  bool _showScrollDown = false;
  bool _showScrollUp = false;

  bool _isDrawerOpen = false;
  late AnimationController _drawerCtrl;
  late Animation<double> _drawerAnim;

  ApiConfig? _apiConfig;
  String _visionModel = '';
  List<String> _availableModels = [];

  String? _pendingImageBase64;
  String? _pendingImagePath;

  // Brave keys stored as comma-separated string
  String _braveKeys = '';

  final _suggestions = [
    {'title': 'Write a message', 'icon': CupertinoIcons.pencil},
    {'title': 'Explain this topic', 'icon': CupertinoIcons.lightbulb},
    {'title': 'Summarize text', 'icon': CupertinoIcons.doc_text},
    {'title': 'Create a plan', 'icon': CupertinoIcons.list_bullet},
  ];

  String get _modelDisplayName {
    final model = _apiConfig?.model ?? '';
    if (model.isEmpty) return 'Model';
    return model.split('/').last;
  }

  @override
  void initState() {
    super.initState();
    _drawerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
    _drawerAnim = CurvedAnimation(parent: _drawerCtrl, curve: Curves.easeOutCubic);
    _scrollController.addListener(_onScroll);
    _loadConfig();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _drawerCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    setState(() {
      _showScrollDown = pos.pixels < pos.maxScrollExtent - 60;
      _showScrollUp = pos.pixels > 60 && pos.pixels >= pos.maxScrollExtent - 60;
    });
  }

  // ----------------------------------------------------------------
  // Config
  // ----------------------------------------------------------------
  Future<void> _loadConfig() async {
    final p = await SharedPreferences.getInstance();
    final ep = p.getString('api_endpoint') ?? 'https://api.openai.com/v1';
    final key = p.getString('api_key') ?? '';
    final model = p.getString('model') ?? '';
    final vModel = p.getString('vision_model') ?? '';
    final sys = p.getString('system_prompt') ?? '';
    final brave = p.getString('brave_keys') ?? '';
    setState(() {
      _apiConfig = ApiConfig(endpoint: ep, apiKey: key, model: model, systemPrompt: sys);
      _visionModel = vModel;
      _braveKeys = brave;
    });
    if (brave.isNotEmpty) {
      WebSearchService.setKeys(brave.split(',').map((k) => k.trim()).toList());
    }
    if (key.isNotEmpty) _fetchModels();
  }

  Future<void> _saveApiConfig(String ep, String key, String model, String vModel, String sys) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('api_endpoint', ep);
    await p.setString('api_key', key);
    await p.setString('model', model);
    await p.setString('vision_model', vModel);
    await p.setString('system_prompt', sys);
    setState(() {
      _apiConfig = ApiConfig(endpoint: ep, apiKey: key, model: model, systemPrompt: sys);
      _visionModel = vModel;
    });
  }

  Future<void> _saveBraveKeys(String keys) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('brave_keys', keys);
    setState(() => _braveKeys = keys);
    WebSearchService.setKeys(keys.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).toList());
    // Auto-enable search after saving key
    if (keys.isNotEmpty) setState(() => _searchEnabled = true);
  }

  Future<void> _fetchModels() async {
    if (_apiConfig == null || _apiConfig!.apiKey.isEmpty) return;
    try {
      final ids = await ApiService.fetchModels(_apiConfig!.endpoint, _apiConfig!.apiKey);
      setState(() => _availableModels = ids);
    } catch (_) {}
  }

  // ----------------------------------------------------------------
  // Scroll
  // ----------------------------------------------------------------
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  // ----------------------------------------------------------------
  // Drawer
  // ----------------------------------------------------------------
  Future<void> _openProfilePage() async {
    await Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => ProfilePage(
        initialEndpoint: _apiConfig?.endpoint ?? '',
        initialApiKey: _apiConfig?.apiKey ?? '',
        initialModel: _apiConfig?.model ?? '',
        initialVisionModel: _visionModel,
        initialSystemPrompt: _apiConfig?.systemPrompt ?? '',
        availableModels: _availableModels,
        onSave: (ep, key, model, vModel, sys) async {
          await _saveApiConfig(ep, key, model, vModel, sys);
          setState(() => _availableModels = []);
          await _fetchModels();
        },
        onFetchModels: (ep, key) async {
          try {
            final ids = await ApiService.fetchModels(ep, key);
            setState(() => _availableModels = ids);
            return ids;
          } catch (_) {
            return [];
          }
        },
      ),
    ));
  }

  void _showProfileMenu() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) {
        final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
        final modelName = (_apiConfig != null && _apiConfig!.model.isNotEmpty)
            ? _modelDisplayName
            : 'No model selected';

        Widget menuTile({
          required IconData icon,
          required String title,
          String? subtitle,
          required VoidCallback onTap,
        }) {
          return CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              Navigator.pop(context);
              onTap();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 18, color: CupertinoColors.label.resolveFrom(context)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(CupertinoIcons.chevron_right, size: 16, color: Color(0xFF8E8E93)),
                ],
              ),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111214) : const Color(0xFFF7F7F8),
            borderRadius: BorderRadius.circular(24),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D1D6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFF111827),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            '😺',
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profile',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: CupertinoColors.label.resolveFrom(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              modelName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                menuTile(
                  icon: CupertinoIcons.person_crop_circle,
                  title: 'Open profile',
                  subtitle: 'Manage API, model, and prompt settings',
                  onTap: _openProfilePage,
                ),
                const SizedBox(height: 8),
                menuTile(
                  icon: CupertinoIcons.search,
                  title: 'Search settings',
                  subtitle: WebSearchService.hasKeys ? 'Brave keys are configured' : 'Add Brave keys for live search',
                  onTap: _showBraveKeySheet,
                ),
                const SizedBox(height: 8),
                menuTile(
                  icon: CupertinoIcons.square_pencil,
                  title: 'Start new chat',
                  subtitle: 'Clear the current conversation',
                  onTap: _clearChat,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleDrawer() {
    if (_isDrawerOpen) _drawerCtrl.reverse();
    else _drawerCtrl.forward();
    setState(() => _isDrawerOpen = !_isDrawerOpen);
  }

  void _clearChat() => setState(() {
    _messages.clear();
    _chatTitle = '';
    _titleGenerated = false;
    _pendingImageBase64 = null;
    _pendingImagePath = null;
    _isWebSearching = false;
    _isLoading = false;
    _streamingMsgId = null;
    _stopStream?.call();
    _stopStream = null;
  });

  // ----------------------------------------------------------------
  // Image picking
  // ----------------------------------------------------------------
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1280, maxHeight: 1280);
    if (picked == null) return;
    final bytes = await File(picked.path).readAsBytes();
    setState(() {
      _pendingImageBase64 = base64Encode(bytes);
      _pendingImagePath = picked.path;
    });
  }

  // ----------------------------------------------------------------
  // Brave key sheet
  // ----------------------------------------------------------------
  void _showBraveKeySheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => BraveKeySheet(
        initialKeys: _braveKeys,
        onSave: (keys) async {
          await _saveBraveKeys(keys);
          // Now enable search
          setState(() => _searchEnabled = true);
        },
      ),
    );
  }

  // ----------------------------------------------------------------
  // Tools sheet
  // ----------------------------------------------------------------
  void _showToolsSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => ToolsSheet(
        searchEnabled: _searchEnabled,
        onSearchChanged: (v) {
          if (v && !WebSearchService.hasKeys) {
            _showBraveKeySheet();
            return;
          }
          setState(() => _searchEnabled = v);
        },
        onPickCamera: () => _pickImage(ImageSource.camera),
        onPickGallery: () => _pickImage(ImageSource.gallery),
        hasBraveKey: WebSearchService.hasKeys,
        onSetBraveKey: _showBraveKeySheet,
      ),
    );
  }

  // ----------------------------------------------------------------
  // Stop
  // ----------------------------------------------------------------
  void _stopResponse() {
    _stopStream?.call();
    _stopStream = null;
    setState(() { _isLoading = false; _isWebSearching = false; _streamingMsgId = null; });
  }

  // ----------------------------------------------------------------
  // Regenerate
  // ----------------------------------------------------------------
  void _regenerate() {
    if (_messages.isEmpty || _isLoading) return;
    // Remove last AI message, re-send
    if (!_messages.last.isUser) setState(() => _messages.removeLast());
    _doSendFromHistory();
  }

  // ----------------------------------------------------------------
  // Copy message
  // ----------------------------------------------------------------
  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    // Brief haptic
    HapticFeedback.lightImpact();
  }

  // ----------------------------------------------------------------
  // Send
  // ----------------------------------------------------------------
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final hasImage = _pendingImageBase64 != null;
    if ((text.isEmpty && !hasImage) || _isLoading || _apiConfig == null || _apiConfig!.apiKey.isEmpty) return;

    final imageB64 = _pendingImageBase64;
    final isFirst = _messages.isEmpty;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true, timestamp: DateTime.now(), imageBase64: imageB64));
      _controller.clear();
      _pendingImageBase64 = null;
      _pendingImagePath = null;
    });
    _scrollToBottom();

    if (isFirst && !_titleGenerated) {
      _titleGenerated = true;
      _ensureChatTitle(text.isNotEmpty ? text : 'Image');
    }

    await _doSendFromHistory();
  }

  Future<void> _doSendFromHistory() async {
    if (_apiConfig == null || _apiConfig!.apiKey.isEmpty) return;
    setState(() { _isLoading = true; });

    int loopCount = 0;
    bool continueLoop = true;
    const int maxLoops = 20;

    while (continueLoop && loopCount < maxLoops) {
      loopCount++;
      // Self-Correction Logic: Add a prompt to the history if we are deep in the loop
      if (loopCount % 4 == 0) {
        _messages.add(ChatMessage(
          text: 'Thought: I have been working on this for a while. Let me double check if my current approach is optimal or if I missed anything important from the previous steps.',
          isUser: true,
          timestamp: DateTime.now(),
          isInternal: true,
        ));
      }

      _streamingMsgId = DateTime.now().millisecondsSinceEpoch.toString();
      setState(() => _messages.add(ChatMessage(text: '', isUser: false, timestamp: DateTime.now())));
      _scrollToBottom();

      String accumulated = '';
      try {
        final history = _messages.sublist(0, _messages.length - 1);
        final imageB64 = history.isNotEmpty && history.last.isUser ? history.last.imageBase64 : null;

        // Vision Switching: Use vision model if image is present
        final activeConfig = (imageB64 != null && _visionModel.isNotEmpty)
            ? ApiConfig(
                endpoint: _apiConfig!.endpoint,
                apiKey: _apiConfig!.apiKey,
                model: _visionModel,
                systemPrompt: _apiConfig!.systemPrompt,
              )
            : _apiConfig!;

        final (stream, cancel) = ApiService.streamChat(
          config: activeConfig,
          history: history,
          searchEnabled: _searchEnabled,
          imageBase64: imageB64,
          availableModels: _availableModels,
        );
        _stopStream = cancel;

        await for (final token in stream) {
          accumulated += token;
          final idx = _messages.length - 1;
          setState(() {
            _streamingMsgId = null;
            _messages[idx] = ChatMessage(text: accumulated, isUser: false, timestamp: _messages[idx].timestamp);
          });
          _scrollToBottom();
        }

        // Handle Image Generation
        await _handleImageGen(accumulated);

        // Handle Agent Tools
        final toolResult = await _handleAgentTools(accumulated);
        if (toolResult != null) {
          setState(() {
            _messages.add(ChatMessage(
              text: 'Observation: $toolResult',
              isUser: true, // Internal observation treated as hidden user msg for next context
              timestamp: DateTime.now(),
              isInternal: true,
            ));
          });
          continueLoop = true;
        } else {
          continueLoop = false;
        }

      } catch (e) {
        final idx = _messages.length - 1;
        final fallbackText = accumulated.trim().isNotEmpty
            ? accumulated.trim()
            : 'I ran into a response issue. Tap retry and I’ll continue from the latest context.';
        setState(() {
          _streamingMsgId = null;
          _messages[idx] = ChatMessage(
            text: fallbackText,
            isUser: false,
            timestamp: _messages[idx].timestamp,
          );
        });
        continueLoop = false;
      } finally {
        _stopStream = null;
        _streamingMsgId = null;
      }
    }

    setState(() { _isLoading = false; _isWebSearching = false; });
    _scrollToBottom();
  }

  Future<String?> _handleAgentTools(String aiText) async {
    final action = parseAgentAction(aiText);
    if (action == null) return null;

    try {
      switch (action.name) {
        case 'search':
          final query = action.input.trim();
          if (query.isEmpty) return 'Search request ignored because the query was empty.';
          setState(() => _isWebSearching = true);
          final results = await WebSearchService.search(query);
          setState(() => _isWebSearching = false);
          return WebSearchService.formatForPrompt(results);

        case 'read_url':
          final url = _extractPlainInput(action.input, keys: const ['url', 'link']);
          if (url.isEmpty) return 'Read request ignored because the URL was empty.';
          return await ToolService.readUrl(url);

        case 'run_code':
          final json = _decodeActionJson(action.input);
          return await ToolService.runCode(
            (json['language'] ?? '').toString(),
            (json['code'] ?? '').toString(),
          );

        case 'write_file':
          final json = _decodeActionJson(action.input);
          return await ToolService.writeFile(
            (json['filename'] ?? '').toString(),
            (json['content'] ?? '').toString(),
          );

        case 'read_file':
          if (action.input.trim().isEmpty) return 'Read file request ignored because the filename was empty.';
          return await ToolService.readFile(action.input.trim());

        case 'list_files':
          return await ToolService.listFiles();

        case 'save_skill':
          final json = _decodeActionJson(action.input);
          return await ToolService.saveSkill(
            (json['name'] ?? '').toString(),
            (json['code'] ?? '').toString(),
          );

        case 'load_skill':
          if (action.input.trim().isEmpty) return 'Load skill request ignored because the skill name was empty.';
          return await ToolService.loadSkill(action.input.trim());

        case 'image_search':
          if (action.input.trim().isEmpty) return 'Image search request ignored because the query was empty.';
          final results = await WebSearchService.searchImages(action.input.trim());
          if (results.isEmpty) return 'No images found.';
          final buf = StringBuffer();
          buf.writeln('Found images:');
          for (final r in results) {
            buf.writeln('- ${r['title']}: ${r['image_url']}');
          }
          return buf.toString();

        case 'take_snapshot':
          final url = _extractPlainInput(action.input, keys: const ['url', 'link']);
          if (url.isEmpty) return 'Snapshot request ignored because the URL was empty.';
          return await ToolService.takeSnapshot(url);

        case 'create_diagram':
          final json = _decodeActionJson(action.input);
          return await ToolService.createDiagram(
            (json['type'] ?? '').toString(),
            (json['code'] ?? '').toString(),
          );

        case 'create_chart':
          if (action.input.trim().isEmpty) return 'Chart request ignored because the chart config was empty.';
          return await ToolService.createChart(action.input.trim());
      }
    } catch (e) {
      return 'Tool execution issue: $e';
    } finally {
      if (mounted) {
        setState(() => _isWebSearching = false);
      }
    }

    return null;
  }

  Map<String, dynamic> _decodeActionJson(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'^```[a-zA-Z0-9_-]*\n?'), '')
        .replaceAll(RegExp(r'\n?```$'), '')
        .trim();

    if (cleaned.isEmpty) {
      throw const FormatException('Missing JSON input');
    }

    final decoded = jsonDecode(cleaned);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.map((key, value) => MapEntry(key.toString(), value));
    throw const FormatException('Expected a JSON object');
  }

  String _extractPlainInput(String input, {List<String> keys = const []}) {
    // Robustly strip any XML tags the model might have included in the raw action input
    final cleaned = input.replaceAll(RegExp(r'<\/?(arg_value|tool_call)[^>]*>', caseSensitive: false), '').trim();
    if (cleaned.isEmpty) return '';
    if (cleaned.startsWith('{')) {
      try {
        final decoded = _decodeActionJson(cleaned);
        for (final key in keys) {
          final value = decoded[key];
          if (value != null && value.toString().trim().isNotEmpty) {
            return value.toString().trim();
          }
        }
      } catch (_) {}
    }
    return cleaned.replaceAll(RegExp(r'''^["']|["']$'''), '').trim();
  }

  Future<void> _ensureChatTitle(String sourceText) async {
    if (_apiConfig == null || _apiConfig!.apiKey.isEmpty) return;
    final title = await ApiService.generateTitle(_apiConfig!, sourceText);
    if (!mounted) return;
    setState(() => _chatTitle = title);
  }

  Future<void> _handleImageGen(String aiText) async {
    final match = RegExp(r'<image_gen>(\{.*?\})<\/image_gen>', dotAll: true).firstMatch(aiText);
    if (match == null) return;
    try {
      final json = jsonDecode(match.group(1)!);
      final prompt = json['prompt'] as String? ?? '';
      final modelId = json['model'] as String? ?? _apiConfig!.model;
      if (prompt.isEmpty) return;
      final idx = _messages.length - 1;
      final b64 = await ApiService.generateImage(
        endpoint: _apiConfig!.endpoint,
        apiKey: _apiConfig!.apiKey,
        prompt: prompt, modelId: modelId,
      );
      if (b64 != null && mounted) {
        final cleanText = _messages[idx].text.replaceAll(match.group(0)!, '').trim();
        setState(() {
          _messages[idx] = ChatMessage(
            text: cleanText, isUser: false,
            timestamp: _messages[idx].timestamp,
            generatedImageBase64: b64,
          );
        });
      }
    } catch (_) {}
  }

  // ----------------------------------------------------------------
  // Empty state
  // ----------------------------------------------------------------
  Widget _buildEmptyState() {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        const SizedBox(height: 80),
        RichText(text: TextSpan(
          style: TextStyle(fontSize: 38, letterSpacing: -0.8, color: CupertinoColors.label.resolveFrom(context)),
          children: [
            const TextSpan(text: 'Aham', style: TextStyle(fontWeight: FontWeight.w300)),
            TextSpan(text: '😺', style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? CupertinoColors.systemGrey : CupertinoColors.black)),
          ],
        )),
        const SizedBox(height: 8),
        const Text('How can I help you today?', style: TextStyle(fontSize: 17, color: Color(0xFF8E8E93))),
        const SizedBox(height: 56),
      ..._suggestions.map((s) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _controller.text = s['title'] as String,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(s['icon'] as IconData, size: 20, color: const Color(0xFF8E8E93)),
              const SizedBox(width: 12),
              Expanded(child: Text(s['title'] as String,
                style: const TextStyle(fontSize: 17, color: CupertinoColors.black))),
            ]),
          ),
        ),
      )),
      ]),
    );
  }

  // ----------------------------------------------------------------
  // Drawer widget
  // ----------------------------------------------------------------
  Widget _buildDrawer() {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return GestureDetector(
      onTap: _isDrawerOpen ? _toggleDrawer : null,
      child: AnimatedBuilder(
        animation: _drawerAnim,
        builder: (ctx, _) => Container(
          color: CupertinoColors.black.withOpacity(_drawerAnim.value * 0.22),
          child: Row(children: [
            GestureDetector(
              onTap: () {},
              child: Container(
                width: MediaQuery.of(ctx).size.width * 0.78,
                transform: Matrix4.translationValues(
                  -MediaQuery.of(ctx).size.width * 0.18 * (1 - _drawerAnim.value), 0, 0)
                  ..scale(0.96 + (_drawerAnim.value * 0.04)),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F1115) : const Color(0xFFF7F7F8),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(28), bottomRight: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withOpacity(isDark ? 0.28 : 0.08),
                      blurRadius: 30,
                      offset: const Offset(8, 0),
                    ),
                  ],
                ),
                child: SafeArea(child: Stack(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF171A20) : CupertinoColors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(
                              color: Color(0xFF111827),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                '😺',
                                style: TextStyle(
                                  color: CupertinoColors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AhamAI',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: CupertinoColors.label.resolveFrom(context),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _apiConfig != null && _apiConfig!.model.isNotEmpty
                                      ? _modelDisplayName
                                      : 'Ready for chat',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                                ),
                              ],
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              _toggleDrawer();
                              Future.delayed(const Duration(milliseconds: 220), _showProfileMenu);
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF22252B) : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(CupertinoIcons.ellipsis, size: 18, color: Color(0xFF6B7280)),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        'Workspace',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label.resolveFrom(context).withOpacity(0.45),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _drawerItem(
                      CupertinoIcons.square_pencil,
                      'New chat',
                      subtitle: 'Clear everything and start fresh',
                      onTap: () {
                        _toggleDrawer();
                        _clearChat();
                      },
                    ),
                    _drawerItem(
                      CupertinoIcons.person_crop_circle,
                      'Profile',
                      subtitle: 'API key, model, prompt, vision',
                      onTap: () {
                        _toggleDrawer();
                        Future.delayed(const Duration(milliseconds: 220), _openProfilePage);
                      },
                    ),
                    _drawerItem(
                      CupertinoIcons.search,
                      'Search settings',
                      subtitle: WebSearchService.hasKeys ? 'Live search is ready' : 'Add Brave key to enable search',
                      onTap: () {
                        _toggleDrawer();
                        Future.delayed(const Duration(milliseconds: 220), _showBraveKeySheet);
                      },
                    ),
                    _drawerItem(
                      CupertinoIcons.add_circled,
                      'Attachments',
                      subtitle: 'Camera, gallery, and tools',
                      onTap: () {
                        _toggleDrawer();
                        Future.delayed(const Duration(milliseconds: 220), _showToolsSheet);
                      },
                    ),

                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        'Session',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label.resolveFrom(context).withOpacity(0.45),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        children: [
                          _sessionTile(
                            _messages.isNotEmpty
                                ? (_chatTitle.isNotEmpty ? _chatTitle : 'Current conversation')
                                : 'No active conversation',
                            _messages.isNotEmpty
                                ? '${_messages.where((m) => !m.isInternal).length} visible messages'
                                : 'Start a chat to see it here',
                            _messages.isNotEmpty ? 'Active' : 'Idle',
                          ),
                          if (_searchEnabled || _pendingImageBase64 != null)
                            _sessionTile(
                              'Active tools',
                              _searchEnabled && _pendingImageBase64 != null
                                  ? 'Web search and image attachment ready'
                                  : _searchEnabled
                                      ? 'Web search is enabled'
                                      : 'Image attachment is ready',
                              'Ready',
                            ),
                        ],
                      ),
                    ),
                  ]),
                  Positioned(
                    right: 18, bottom: 18,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        _toggleDrawer();
                        _clearChat();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(CupertinoIcons.chat_bubble_text, color: CupertinoColors.white, size: 18),
                          const SizedBox(width: 8),
                          const Text('New chat', style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ),
                ])),
              ),
            ),
            Expanded(child: Container()),
          ]),
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, {String? subtitle, VoidCallback? onTap}) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap ?? () {},
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF171A20) : CupertinoColors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF22252B) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: CupertinoColors.label.resolveFrom(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: CupertinoColors.label.resolveFrom(context))),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                ],
              ],
            ),
          ),
          const Icon(CupertinoIcons.chevron_right, size: 16, color: Color(0xFF8E8E93)),
        ]),
      ),
    );
  }

  Widget _sessionTile(String title, String agent, String time) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171A20) : CupertinoColors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(agent, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF22252B) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(time, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  // ----------------------------------------------------------------
  // Build
  // ----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isStreaming = _streamingMsgId != null || _isLoading;
    final inChat = _messages.isNotEmpty;
    final showScrollBtn = inChat && !isStreaming && (_showScrollDown || _showScrollUp);
    final toolsActive = _searchEnabled || _pendingImageBase64 != null;
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (_isDrawerOpen) _toggleDrawer();
        FocusScope.of(context).unfocus();
      },
      child: Stack(children: [
        AbsorbPointer(
          absorbing: _isDrawerOpen,
          child: CupertinoPageScaffold(
            backgroundColor: isDark ? CupertinoColors.black : CupertinoColors.systemBackground,
            child: SafeArea(
              bottom: false,
              child: Column(children: [

                // AppBar
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                  child: Row(children: [
                    CupertinoButton(
                      padding: const EdgeInsets.all(6),
                      onPressed: _toggleDrawer,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF171A20) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(CupertinoIcons.line_horizontal_3, size: 20, color: CupertinoColors.label.resolveFrom(context)),
                      ),
                    ),
                    Expanded(child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _chatTitle.isNotEmpty
                          ? Text(_chatTitle, key: ValueKey(_chatTitle),
                              textAlign: TextAlign.center, maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CupertinoColors.label.resolveFrom(context)))
                          : const SizedBox.shrink(key: ValueKey('e')),
                    )),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CupertinoButton(
                          padding: const EdgeInsets.all(6),
                          onPressed: _clearChat,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF171A20) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(CupertinoIcons.square_pencil, size: 18, color: CupertinoColors.label.resolveFrom(context)),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.all(6),
                          onPressed: _showProfileMenu,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Color(0xFF111827),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                '😺',
                                style: TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ]),
                ),

                // Messages
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _messages.length,
                          itemBuilder: (ctx, i) {
                            final msg = _messages[i];
                        if (msg.isInternal) return const SizedBox.shrink();
                            final isLastAI = i == _messages.length - 1 && !msg.isUser;
                            final preStream = isLastAI && _streamingMsgId != null;
                            final streaming = isLastAI && isStreaming && !preStream;
                            return MessageBubble(
                              key: ValueKey('msg_$i'),
                              message: msg,
                              isPreStream: preStream,
                              isWebSearching: preStream && _isWebSearching,
                              isStreaming: streaming,
                              onCopy: msg.isUser ? null : () => _copyMessage(msg.text),
                              onRegenerate: (isLastAI && !isStreaming) ? _regenerate : null,
                              onDoubleTapCopy: msg.isUser ? () => _copyMessage(msg.text) : null,
                            );
                          },
                        ),
                ),

                // Pending image preview
                if (_pendingImagePath != null)
                  Container(
                    color: isDark ? CupertinoColors.black : CupertinoColors.systemBackground,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(children: [
                      Stack(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(File(_pendingImagePath!), width: 60, height: 60, fit: BoxFit.cover),
                        ),
                        Positioned(top: -4, right: -4,
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => setState(() { _pendingImageBase64 = null; _pendingImagePath = null; }),
                            child: Container(
                              width: 20, height: 20,
                              decoration: const BoxDecoration(color: CupertinoColors.systemGrey, shape: BoxShape.circle),
                              child: const Icon(CupertinoIcons.xmark, size: 12, color: CupertinoColors.white),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(width: 10),
                      const Text('Image ready', style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
                    ]),
                  ),

                // Input area
                Container(
                  color: isDark ? CupertinoColors.black : CupertinoColors.systemBackground,
                  padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF171A20) : const Color(0xFFF5F5F6),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CupertinoTextField(
                        controller: _controller,
                        placeholder: 'Ask anything... /commands',
                        placeholderStyle: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 16),
                        decoration: null,
                        style: TextStyle(fontSize: 16, color: CupertinoColors.label.resolveFrom(context)),
                        maxLines: 5, minLines: 1,
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _showToolsSheet,
                          child: Icon(CupertinoIcons.add, color: CupertinoColors.label.resolveFrom(context), size: 20),
                        ),
                        const Spacer(),
                        const Icon(CupertinoIcons.mic, size: 20, color: CupertinoColors.systemGrey),
                        const SizedBox(width: 12),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _isLoading ? _stopResponse : _sendMessage,
                          child: Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              color: _isLoading ? CupertinoColors.systemRed : const Color(0xFF111827),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isLoading ? CupertinoIcons.stop_fill : CupertinoIcons.arrow_up,
                              size: _isLoading ? 12 : 18,
                              color: CupertinoColors.white,
                            ),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),

        // Scroll button
        if (showScrollBtn)
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 140,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showScrollDown ? _scrollToBottom : _scrollToTop,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: CupertinoColors.white, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Icon(
                  _showScrollDown ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_up,
                  size: 16, color: const Color(0xFF1C1C1E),
                ),
              ),
            ),
          ),

        // Drawer
        if (_isDrawerOpen || _drawerCtrl.isAnimating) _buildDrawer(),
      ]),
    );
  }
}

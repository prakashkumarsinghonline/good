import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'web_search_service.dart';

// ====================================================================
// Data models
// ====================================================================
class ApiConfig {
  final String endpoint;
  final String apiKey;
  final String model;
  final String systemPrompt;

  ApiConfig({
    required this.endpoint,
    required this.apiKey,
    required this.model,
    this.systemPrompt = '',
  });
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? imageBase64;
  final String? generatedImageBase64;
  final bool isInternal; // hidden from UI

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imageBase64,
    this.generatedImageBase64,
    this.isInternal = false,
  });
}

// ====================================================================
// API Service
// ====================================================================
class ApiService {
  static const int _maxHistory = 20;

  static Future<List<String>> fetchModels(String endpoint, String apiKey) async {
    final url = Uri.parse('$endpoint/models');
    final response = await http.get(url,
      headers: {'Authorization': 'Bearer $apiKey'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final ids = (data['data'] as List? ?? []).map((m) => m['id'] as String).toList();
      ids.sort();
      return ids;
    }
    throw Exception('HTTP ${response.statusCode}');
  }

  static Future<String> generateTitle(ApiConfig config, String firstMessage) async {
    final fallback = fallbackTitle(firstMessage);
    try {
      final url = Uri.parse('${config.endpoint}/chat/completions');
      final response = await http.post(url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${config.apiKey}'},
        body: jsonEncode({
          'model': config.model,
          'messages': [
            {'role': 'system', 'content': 'You are a helpful assistant that generates short, punchy chat titles.'},
            {'role': 'user', 'content': 'Give a very short title (max 3-5 words, no punctuation) for a chat that starts with: "$firstMessage". Reply with ONLY the title text. Do not include quotes, prefix, or suffix.'}
          ],
          'max_tokens': 20, 'stream': false,
        }),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final raw = (jsonDecode(response.body)['choices'][0]['message']['content'] as String).trim();
        final clean = raw.replaceAll(RegExp('[\u201C\u201D\u2018\u2019"\']+'), '').trim();
        return clean.isNotEmpty ? clean : fallback;
      }
    } catch (_) {}
    return fallback;
  }

  static String fallbackTitle(String firstMessage) {
    final cleaned = firstMessage
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .trim();
    if (cleaned.isEmpty || cleaned.toLowerCase() == 'image') {
      return 'Image chat';
    }
    final words = cleaned
        .split(' ')
        .where((word) => word.trim().isNotEmpty)
        .take(5)
        .toList();
    final title = words.join(' ').trim();
    if (title.isEmpty) return 'New chat';
    return title[0].toUpperCase() + title.substring(1);
  }

  // Build windowed message history — strips old images to save tokens
  static List<Map<String, dynamic>> _buildMessages(
    ApiConfig config,
    List<ChatMessage> history,
    String? pendingImage,
  ) {
    final msgs = <Map<String, dynamic>>[];
    if (config.systemPrompt.isNotEmpty) {
      msgs.add({'role': 'system', 'content': config.systemPrompt});
    }
    final window = history.length > _maxHistory
        ? history.sublist(history.length - _maxHistory)
        : history;

    for (int i = 0; i < window.length; i++) {
      final msg = window[i];
      final isLast = i == window.length - 1;
      if (msg.isUser) {
        final img = isLast ? (pendingImage ?? msg.imageBase64) : null;
        if (img != null && img.isNotEmpty) {
          final content = <Map<String, dynamic>>[
            {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,$img'}},
          ];
          if (msg.text.isNotEmpty) content.add({'type': 'text', 'text': msg.text});
          msgs.add({'role': 'user', 'content': content});
        } else {
          // If it's an internal observation, use a system-like role or clear prefix
          final role = msg.isInternal ? 'user' : 'user';
          msgs.add({'role': role, 'content': msg.text});
        }
      } else {
        msgs.add({'role': 'assistant', 'content': msg.text});
      }
    }
    return msgs;
  }

  // ----------------------------------------------------------------
  // Stream chat — returns (stream, cancelFn)
  // searchEnabled: if true, AI decides search queries itself via tool-calling style prompt
  // ----------------------------------------------------------------
  static (Stream<String>, void Function()) streamChat({
    required ApiConfig config,
    required List<ChatMessage> history,
    bool searchEnabled = false,
    String? imageBase64,
    List<String> availableModels = const [],
    List<Map<String, String>>? webResults, // pre-fetched results to inject
  }) {
    final controller = StreamController<String>();
    final client = http.Client();
    bool cancelled = false;

    void cancel() {
      cancelled = true;
      client.close();
      if (!controller.isClosed) controller.close();
    }

    () async {
      try {
        // Build system prompt
        final now = DateTime.now();
        final timeStr =
          '${_weekday(now.weekday)}, ${_month(now.month)} ${now.day}, ${now.year} '
          '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')} local time';

        final parts = <String>[];
        if (config.systemPrompt.isNotEmpty) parts.add(config.systemPrompt);

        // Agentic capabilities
        parts.add('''
You are an autonomous AI agent. You solve complex tasks by using tools in a ReAct (Reasoning & Acting) loop.

TOOLS:
- search: Search the web for information.
- read_url: Read the full content of a web page.
- run_code: Execute code and see output. Input must be JSON like {"language":"python","code":"..."}.
- write_file: Save data to a local file. Input must be JSON like {"filename":"name.txt","content":"..."}.
- read_file: Read a local file.
- list_files: List all files in your workspace.
- save_skill: Save a reusable piece of code. Input must be JSON like {"name":"task_name","code":"..."}.
- load_skill: Load a previously saved skill. Prebuilt skills: "Stock Research", "Weather Forecast", "Web News Digest", "Code Architect", "Data Analyst".
- image_search: Find and display images from the web.
- take_snapshot: Take a visual screenshot of a webpage.
- create_diagram: Create diagrams. Input must be JSON like {"type":"mermaid","code":"..."}.
- create_chart: Create charts. Input must be raw QuickChart JSON.

PRIMARY FORMAT:
Thought: <brief reasoning>
Action: <tool_name>
Action Input: <plain text or JSON>

Wait for the observation before continuing.

IMPORTANT:
- Do not use XML, HTML, or angle-bracket tags for tool calls unless absolutely necessary.
- Do not wrap normal answers inside tags.
- Keep Thought concise and natural.
- If a tool input is JSON, output valid JSON only.

SELF-CORRECTION:
After every tool observation, critique your findings. If the information is incomplete or the code failed, try a different approach.

Once you have the final answer, output:
Final Answer: <your comprehensive response>

If the task is simple and no tool is needed, answer normally without Action lines.''');

        // Image generation instruction always available
        if (availableModels.isNotEmpty) {
          parts.add('''
You have image generation capability. When the user asks to generate/create/draw/make an image, output EXACTLY this on its own line:
<image_gen>{"prompt":"<detailed prompt>","model":"<best model from: ${availableModels.join(', ')}>"}></image_gen>''');
        }

        // Web search context injection
        if (searchEnabled && webResults != null && webResults.isNotEmpty) {
          parts.add('''
CURRENT DATE & TIME: $timeStr
You have NO knowledge cutoff — you are using LIVE web data from right now.
The following web search results were retrieved moments ago for the user's query. Use them to answer accurately with real-time information. Cite sources by number [1], [2] etc when referencing them.

${WebSearchService.formatForPrompt(webResults)}''');
        } else if (searchEnabled) {
          parts.add('CURRENT DATE & TIME: $timeStr\nYou have NO knowledge cutoff — you have access to real-time web data.');
        }

        final effectiveConfig = ApiConfig(
          endpoint: config.endpoint,
          apiKey: config.apiKey,
          model: config.model,
          systemPrompt: parts.join('\n\n'),
        );

        final body = <String, dynamic>{
          'model': config.model,
          'messages': _buildMessages(effectiveConfig, history, imageBase64),
          'stream': true,
        };

        final request = http.Request('POST', Uri.parse('${config.endpoint}/chat/completions'));
        request.headers.addAll({
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey}',
        });
        request.body = jsonEncode(body);

        final response = await client.send(request);
        if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');

        await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
          if (cancelled) break;
          if (chunk.startsWith('data: ')) {
            final dataStr = chunk.substring(6);
            if (dataStr.trim() == '[DONE]') break;
            try {
              final delta = jsonDecode(dataStr)['choices'][0]['delta']['content'];
              if (delta != null && !controller.isClosed) controller.add(delta as String);
            } catch (_) {}
          }
        }
      } catch (e) {
        if (!cancelled && !controller.isClosed) controller.addError(e);
      } finally {
        client.close();
        if (!controller.isClosed) controller.close();
      }
    }();

    return (controller.stream, cancel);
  }

  // ----------------------------------------------------------------
  // Ask AI to generate search queries for the user message
  // Returns list of distinct queries to run in parallel
  // ----------------------------------------------------------------
  static Future<List<String>> generateSearchQueries(ApiConfig config, String userMessage) async {
    final url = Uri.parse('${config.endpoint}/chat/completions');
    final response = await http.post(url,
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${config.apiKey}'},
      body: jsonEncode({
        'model': config.model,
        'messages': [
          {'role': 'system', 'content':
            'You generate optimal web search queries. Return ONLY a JSON array of 2-5 short, distinct search query strings. No explanation, no markdown, just the raw JSON array.'},
          {'role': 'user', 'content': 'Generate search queries for: $userMessage'},
        ],
        'max_tokens': 200, 'stream': false,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      try {
        final raw = (jsonDecode(response.body)['choices'][0]['message']['content'] as String).trim();
        final clean = raw.replaceAll(RegExp(r'```json|```'), '').trim();
        final list = jsonDecode(clean) as List;
        return list.map((q) => q.toString()).toList();
      } catch (_) {}
    }
    // Fallback: just use the user message as-is
    return [userMessage];
  }

  // Generate image
  static Future<String?> generateImage({
    required String endpoint,
    required String apiKey,
    required String prompt,
    required String modelId,
  }) async {
    final response = await http.post(
      Uri.parse('$endpoint/images/generations'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'},
      body: jsonEncode({
        'model': modelId, 'prompt': prompt,
        'n': 1, 'response_format': 'b64_json', 'size': '1024x1024',
      }),
    ).timeout(const Duration(seconds: 60));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data']?[0]?['b64_json'] as String?;
    }
    return null;
  }

  static String _weekday(int d) => ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d-1];
  static String _month(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m-1];
}

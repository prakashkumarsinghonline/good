import 'dart:convert';

class AgentAction {
  final String name;
  final String input;

  const AgentAction({
    required this.name,
    required this.input,
  });
}

class ParsedAgentContent {
  final String? thinking;
  final String? thought;
  final AgentAction? action;
  final bool hasFinalAnswer;
  final String displayText;

  const ParsedAgentContent({
    required this.thinking,
    required this.thought,
    required this.action,
    required this.hasFinalAnswer,
    required this.displayText,
  });
}

const _toolNames = <String>{
  'search',
  'read_url',
  'run_code',
  'write_file',
  'read_file',
  'list_files',
  'save_skill',
  'load_skill',
  'image_search',
  'take_snapshot',
  'create_diagram',
  'create_chart',
};

const _controlMarkers = <String>[
  '\nObservation:',
  '\nFinal Answer:',
  '\nThought:',
  '\nAction:',
  '\n<tool_call>',
];

ParsedAgentContent parseAgentContent(String raw, {bool isStreaming = false}) {
  final normalized = raw.replaceAll('\r\n', '\n');
  var working = normalized.trimLeft();

  String? thinking;
  final closedThinking = RegExp(
    r'^<(think|thinking|thought|thoughts|reasoning|reason|reflection|reflect)[^>]*>([\s\S]*?)<\/\1>',
    caseSensitive: false,
  ).firstMatch(working);

  if (closedThinking != null) {
    thinking = closedThinking.group(2)?.trim();
    working = working.substring(closedThinking.end).trimLeft();
  } else if (isStreaming) {
    final openThinking = RegExp(
      r'^<(think|thinking|thought|thoughts|reasoning|reason|reflection|reflect)[^>]*>',
      caseSensitive: false,
    ).firstMatch(working);

    if (openThinking != null) {
      final tail = working.substring(openThinking.end);
      final endIndex = _firstMarkerIndex(tail, const [
        '\nAction:',
        '\nAction Input:',
        '\nFinal Answer:',
        '\nObservation:',
      ]);
      final segment = tail.substring(0, endIndex).trim();
      if (segment.isNotEmpty) {
        thinking = segment;
        working = tail.substring(endIndex).trimLeft();
      }
    }
  }

  final thought = _extractThought(working);
  final action = parseAgentAction(working);
  final finalAnswerMatch = RegExp(r'Final Answer:\s*', caseSensitive: false).firstMatch(working);

  final hasFinalAnswer = finalAnswerMatch != null;
  var displayText = hasFinalAnswer
      ? working.substring(finalAnswerMatch.end).trimLeft()
      : _removeControlBlocks(working);

  displayText = _cleanupDisplayText(displayText);

  return ParsedAgentContent(
    thinking: thinking,
    thought: thought,
    action: action,
    hasFinalAnswer: hasFinalAnswer,
    displayText: displayText,
  );
}

AgentAction? parseAgentAction(String raw) {
  final text = raw.replaceAll('\r\n', '\n');

  if (text.contains('<list_files/>')) {
    return const AgentAction(name: 'list_files', input: '');
  }

  final structuredAction = RegExp(
    r'(^|\n)Action:\s*([a-z_]+)(?:\s+(.*))?(?=\n|$)',
    caseSensitive: false,
  ).firstMatch(text);

  if (structuredAction != null) {
    final name = structuredAction.group(2)!.trim().toLowerCase();
    if (_toolNames.contains(name)) {
      final remainder = text.substring(structuredAction.end).trimLeft();
      String input = (structuredAction.group(3) ?? '').trim();

      final inputMatch = RegExp(
        r'^Action Input:\s*',
        caseSensitive: false,
      ).firstMatch(remainder);

      if (inputMatch != null) {
        final inputTail = remainder.substring(inputMatch.end);
        final endIndex = _firstMarkerIndex(inputTail, _controlMarkers);
        input = inputTail.substring(0, endIndex).trim();
      }

      return AgentAction(name: name, input: _stripCodeFences(input));
    }
  }

  final toolCall = RegExp(
    r'<tool_call>([\s\S]*?)(?:<\/tool_call>|$)',
    caseSensitive: false,
  ).firstMatch(text);

  if (toolCall != null) {
    final payload = toolCall.group(1)?.trim() ?? '';
    final decoded = _tryDecodeJsonObject(payload);
    if (decoded != null) {
      final name = (decoded['name'] ?? decoded['tool_name'] ?? decoded['tool'] ?? '').toString().trim().toLowerCase();
      if (_toolNames.contains(name)) {
        final rawInput = decoded['input'] ?? decoded['arguments'] ?? decoded['args'] ?? decoded['argument'] ?? '';
        return AgentAction(name: name, input: _normalizeToolInput(rawInput));
      }
    }
  }

  final legacy = RegExp(
    r'<(search|read_url|run_code|write_file|read_file|save_skill|load_skill|image_search|take_snapshot|create_diagram|create_chart)[^>]*>([\s\S]*?)(?:<\/\1>|$)',
    caseSensitive: false,
  ).firstMatch(text);

  if (legacy != null) {
    return AgentAction(
      name: legacy.group(1)!.trim().toLowerCase(),
      input: _stripCodeFences((legacy.group(2) ?? '').trim()),
    );
  }

  return null;
}

String? _extractThought(String text) {
  final match = RegExp(
    r'(^|\n)Thought:\s*([\s\S]*?)(?=\n(?:Action:|Final Answer:|Observation:)|$)',
    caseSensitive: false,
  ).firstMatch(text);
  return match?.group(2)?.trim();
}

String _removeControlBlocks(String text) {
  var cleaned = text;
  cleaned = cleaned.replaceFirst(
    RegExp(
      r'(^|\n)Thought:\s*([\s\S]*?)(?=\n(?:Action:|Final Answer:|Observation:)|$)',
      caseSensitive: false,
    ),
    '',
  );
  cleaned = cleaned.replaceFirst(
    RegExp(
      r'(^|\n)Action:\s*[a-z_]+\s*(?:\nAction Input:\s*[\s\S]*?)?(?=\n(?:Observation:|Final Answer:|Thought:|Action:)|$)',
      caseSensitive: false,
    ),
    '',
  );
  cleaned = cleaned.replaceAll(
    RegExp(
      r'<(search|read_url|run_code|write_file|read_file|save_skill|load_skill|image_search|take_snapshot|create_diagram|create_chart)[^>]*>[\s\S]*?(?:<\/\1>|$)',
      caseSensitive: false,
    ),
    '',
  );
  cleaned = cleaned.replaceAll(
    RegExp(r'<tool_call>[\s\S]*?(?:<\/tool_call>|$)', caseSensitive: false),
    '',
  );
  cleaned = cleaned.replaceAll('<list_files/>', '');
  cleaned = cleaned.replaceFirst(
    RegExp(r'(^|\n)Observation:\s*', caseSensitive: false),
    '',
  );
  return cleaned.trim();
}

String _cleanupDisplayText(String text) {
  var cleaned = text.trim();
  cleaned = cleaned.replaceAll(
    RegExp(r'<\/?(think|thinking|thought|thoughts|reasoning|reason|reflection|reflect)[^>]*>', caseSensitive: false),
    '',
  );
  cleaned = cleaned.replaceAll(
    RegExp(r'<\/?(search|read_url|run_code|write_file|read_file|save_skill|load_skill|image_search|take_snapshot|create_diagram|create_chart)[^>]*>', caseSensitive: false),
    '',
  );
  cleaned = cleaned.replaceAll(
    RegExp(r'<\/?(tool_call|arg_value)[^>]*>', caseSensitive: false),
    '',
  );
  return cleaned.trim();
}

String _stripCodeFences(String input) {
  var text = input.trim();
  // Strip XML-like tags that some models wrap around tool inputs
  text = text.replaceAll(RegExp(r'<\/?(arg_value|tool_call)[^>]*>', caseSensitive: false), '');

  if (text.startsWith('```')) {
    text = text.replaceFirst(RegExp(r'^```[a-zA-Z0-9_-]*\n?'), '');
    text = text.replaceFirst(RegExp(r'\n?```$'), '');
  }
  return text.trim();
}

int _firstMarkerIndex(String input, List<String> markers) {
  var minIndex = input.length;
  for (final marker in markers) {
    final idx = input.indexOf(marker);
    if (idx >= 0 && idx < minIndex) {
      minIndex = idx;
    }
  }
  return minIndex;
}

Map<String, dynamic>? _tryDecodeJsonObject(String input) {
  final cleaned = _stripCodeFences(input);
  if (cleaned.isEmpty) return null;
  try {
    final decoded = jsonDecode(cleaned);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  } catch (_) {}
  return null;
}

String _normalizeToolInput(Object? rawInput) {
  if (rawInput == null) return '';
  if (rawInput is String) return _stripCodeFences(rawInput);
  if (rawInput is Map) {
    if (rawInput.containsKey('url')) return rawInput['url'].toString().trim();
    if (rawInput.containsKey('query')) return rawInput['query'].toString().trim();
    return jsonEncode(rawInput);
  }
  return rawInput.toString().trim();
}

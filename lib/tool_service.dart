import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'web_search_service.dart';

class ToolService {
  static const String _jinaBaseUrl = 'https://r.jina.ai/';
  static const String _pistonBaseUrl = 'https://emkc.org/api/v2/piston';
  static const String _microlinkBaseUrl = 'https://api.microlink.io';
  static const String _krokiBaseUrl = 'https://kroki.io';
  static const String _quickChartBaseUrl = 'https://quickchart.io/chart';

  // ----------------------------------------------------------------
  // Web Reading (Jina Reader)
  // ----------------------------------------------------------------
  static Future<String> readUrl(String url) async {
    try {
      final response = await http.get(
        Uri.parse('$_jinaBaseUrl$url'),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return response.body;
      }
      return 'Error reading URL: HTTP ${response.statusCode}';
    } catch (e) {
      return 'Error reading URL: $e';
    }
  }

  // ----------------------------------------------------------------
  // Code Runner (Piston API)
  // ----------------------------------------------------------------
  static Future<String> runCode(String language, String code) async {
    try {
      final response = await http.post(
        Uri.parse('$_pistonBaseUrl/execute'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'language': language,
          'version': '*',
          'files': [
            {'content': code}
          ],
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final run = data['run'];
        final stdout = run['stdout'] as String? ?? '';
        final stderr = run['stderr'] as String? ?? '';
        if (stderr.isNotEmpty) {
          return 'Output:\n$stdout\nErrors:\n$stderr';
        }
        return stdout.isEmpty ? 'Code executed successfully (no output).' : stdout;
      }
      return 'Error running code: HTTP ${response.statusCode}\n${response.body}';
    } catch (e) {
      return 'Error running code: $e';
    }
  }

  // ----------------------------------------------------------------
  // Local File Manager
  // ----------------------------------------------------------------
  static Future<Directory> get _workspaceDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/agent_workspace');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<String> writeFile(String filename, String content) async {
    try {
      final dir = await _workspaceDir;
      final file = File('${dir.path}/$filename');
      await file.writeAsString(content);
      return 'Successfully wrote to $filename';
    } catch (e) {
      return 'Error writing file: $e';
    }
  }

  static Future<String> readFile(String filename) async {
    try {
      final dir = await _workspaceDir;
      final file = File('${dir.path}/$filename');
      if (await file.exists()) {
        return await file.readAsString();
      }
      return 'File not found: $filename';
    } catch (e) {
      return 'Error reading file: $e';
    }
  }

  static Future<String> listFiles() async {
    try {
      final dir = await _workspaceDir;
      final list = dir.listSync();
      if (list.isEmpty) return 'Workspace is empty.';
      return list.map((e) => e.path.split('/').last).join('\n');
    } catch (e) {
      return 'Error listing files: $e';
    }
  }

  // ----------------------------------------------------------------
  // Skill Manager (Simple implementation using file system)
  // ----------------------------------------------------------------
  static Future<String> saveSkill(String name, String code) async {
    final skillFilename = 'skill_${name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.txt';
    return await writeFile(skillFilename, code);
  }

  static Future<String> loadSkill(String name) async {
    // Prebuilt skills
    final prebuilt = {
      'Stock Research': 'To research a stock, I will first <search>latest stock price and news for [SYMBOL]</search>, then <run_code>{"language": "python", "code": "import pandas as pd\\n# Mock data analysis\\nprint(\'Analyzing trends for [SYMBOL]...\')"} </run_code> and summarize the outlook.',
      'Weather Forecast': 'I will <search>current weather and 5-day forecast for [LOCATION]</search> and provide a detailed weather report with activity suggestions.',
      'Web News Digest': 'I will <search>top news headlines for [TOPIC] today</search>, then <read_url>[TOP_URL]</read_url> to provide a deep-dive summary of the most important story.',
      'Code Architect': 'I will analyze the provided code, <run_code>{"language": "python", "code": "# Test provided logic\\nprint(\'Testing performance...\')"} </run_code> and suggest improvements for readability, performance, and security.',
      'Data Analyst': 'I will <list_files/>, then <read_file>[FILENAME]</read_file>, and use <run_code>{"language": "python", "code": "import json\\n# Process data\\nprint(\'Data summary generated.\')"} </run_code> to provide insights.',
    };

    if (prebuilt.containsKey(name)) {
      return prebuilt[name]!;
    }

    final skillFilename = 'skill_${name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.txt';
    return await readFile(skillFilename);
  }

  // ----------------------------------------------------------------
  // Web Snapshot (Microlink API - Free tier)
  // ----------------------------------------------------------------
  static Future<String> takeSnapshot(String url) async {
    try {
      final uri = Uri.parse(_microlinkBaseUrl).replace(
        queryParameters: {'url': url, 'screenshot': 'true', 'meta': 'false'},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final imageUrl = data['data']?['screenshot']?['url'];
        if (imageUrl != null) {
          return 'Snapshot captured: $imageUrl';
        }
      }
      return 'Error capturing snapshot: HTTP ${response.statusCode}';
    } catch (e) {
      return 'Error capturing snapshot: $e';
    }
  }

  // ----------------------------------------------------------------
  // Diagram Creator (Kroki API - Free)
  // ----------------------------------------------------------------
  static Future<String> createDiagram(String type, String code) async {
    try {
      // type: mermaid, plantuml, graphviz, etc.
      final payload = base64Url.encode(utf8.encode(code));
      final url = '$_krokiBaseUrl/$type/png/$payload';
      return 'Diagram created: $url';
    } catch (e) {
      return 'Error creating diagram: $e';
    }
  }

  // ----------------------------------------------------------------
  // Chart Creator (QuickChart API - Free)
  // ----------------------------------------------------------------
  static Future<String> createChart(String configJson) async {
    try {
      final uri = Uri.parse(_quickChartBaseUrl).replace(
        queryParameters: {
          'c': configJson,
          'width': '500',
          'height': '300',
          'format': 'png',
        },
      );
      return 'Chart created: ${uri.toString()}';
    } catch (e) {
      return 'Error creating chart: $e';
    }
  }
}

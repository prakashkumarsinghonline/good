import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ====================================================================
// Brave Web Search — multi-key rotation, parallel queries
// ====================================================================
class WebSearchService {
  static List<String> _keys = [];
  static int _keyIndex = 0;

  static void setKeys(List<String> keys) {
    _keys = keys.where((k) => k.trim().isNotEmpty).toList();
    _keyIndex = 0;
  }

  static bool get hasKeys => _keys.isNotEmpty;

  static String _nextKey() {
    if (_keys.isEmpty) throw Exception('No Brave API keys configured');
    final key = _keys[_keyIndex % _keys.length];
    _keyIndex = (_keyIndex + 1) % _keys.length;
    return key;
  }

  // Single query → up to 20 results
  static Future<List<Map<String, String>>> search(String query) async {
    for (int attempt = 0; attempt < _keys.length; attempt++) {
      final key = _nextKey();
      try {
        final uri = Uri.parse('https://api.search.brave.com/res/v1/web/search').replace(
          queryParameters: {'q': query, 'count': '20', 'text_decorations': 'false'},
        );
        final resp = await http.get(uri, headers: {
          'Accept': 'application/json',
          'Accept-Encoding': 'gzip',
          'X-Subscription-Token': key,
        }).timeout(const Duration(seconds: 10));

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final results = <Map<String, String>>[];
          final webResults = data['web']?['results'] as List? ?? [];
          for (final r in webResults) {
            results.add({
              'title': r['title'] ?? '',
              'url': r['url'] ?? '',
              'snippet': r['description'] ?? '',
            });
          }
          return results;
        }
        // On rate-limit (429) or auth error (401), rotate key
        if (resp.statusCode == 429 || resp.statusCode == 401) continue;
        break;
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  // Run multiple queries in parallel and merge deduplicated results
  static Future<List<Map<String, String>>> parallelSearch(List<String> queries) async {
    final futures = queries.map((q) => search(q)).toList();
    final results = await Future.wait(futures);
    final seen = <String>{};
    final merged = <Map<String, String>>[];
    for (final batch in results) {
      for (final r in batch) {
        final url = r['url'] ?? '';
        if (url.isNotEmpty && seen.add(url)) {
          merged.add(r);
        }
      }
    }
    return merged;
  }

  // Image search → up to 10 image results
  static Future<List<Map<String, String>>> searchImages(String query) async {
    for (int attempt = 0; attempt < _keys.length; attempt++) {
      final key = _nextKey();
      try {
        final uri = Uri.parse('https://api.search.brave.com/res/v1/images/search').replace(
          queryParameters: {'q': query, 'count': '10'},
        );
        final resp = await http.get(uri, headers: {
          'Accept': 'application/json',
          'X-Subscription-Token': key,
        }).timeout(const Duration(seconds: 10));

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final results = <Map<String, String>>[];
          final imgResults = data['results'] as List? ?? [];
          for (final r in imgResults) {
            results.add({
              'title': r['title'] ?? '',
              'url': r['url'] ?? '',
              'image_url': r['properties']?['url'] ?? r['thumbnail']?['src'] ?? '',
            });
          }
          return results;
        }
        if (resp.statusCode == 429 || resp.statusCode == 401) continue;
        break;
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  // Format results as a clean context block for the AI
  static String formatForPrompt(List<Map<String, String>> results) {
    if (results.isEmpty) return '[No web results found]';
    final buf = StringBuffer();
    buf.writeln('=== WEB SEARCH RESULTS (${results.length} sources) ===');
    for (int i = 0; i < results.length; i++) {
      final r = results[i];
      buf.writeln('[${i + 1}] ${r['title']}');
      buf.writeln('URL: ${r['url']}');
      buf.writeln('${r['snippet']}');
      buf.writeln();
    }
    buf.writeln('=== END RESULTS ===');
    return buf.toString();
  }
}

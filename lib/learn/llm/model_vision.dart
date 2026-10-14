import 'dart:convert';

import 'package:http/http.dart' as http;

/// Where a photo goes when the learner's model cannot read one. The
/// default tutor model, DeepSeek V4 Flash, is text-only; its 4.1 sibling
/// takes images and costs about the same.
const String kPhotoFallbackModel = 'deepseek/deepseek-v4.1-flash';

/// Whether a model can be shown a photo, asked of OpenRouter once per
/// model per run. A model that cannot be checked — offline, an id that
/// no longer exists — counts as text-only, so the photo goes to a model
/// that certainly can read it rather than to one that would refuse it.
class VisionModels {
  VisionModels({http.Client? client, this.timeout = const Duration(seconds: 8)})
      : _client = client;

  final http.Client? _client;
  final Duration timeout;
  final Map<String, bool> _known = {};

  Future<bool> accepts(String modelId) async {
    final id = _bare(modelId);
    if (id.isEmpty) return false;
    final cached = _known[id];
    if (cached != null) return cached;
    final answer = await _ask(id);
    _known[id] = answer;
    return answer;
  }

  Future<bool> _ask(String id) async {
    final client = _client ?? http.Client();
    try {
      final resp = await client
          .get(Uri.parse('https://openrouter.ai/api/v1/models/$id/endpoints'))
          .timeout(timeout);
      if (resp.statusCode != 200) return false;
      final json = jsonDecode(resp.body);
      final data = json is Map ? json['data'] : null;
      final arch = data is Map ? data['architecture'] : null;
      final modalities = arch is Map ? arch['input_modalities'] : null;
      return modalities is List && modalities.contains('image');
    } catch (_) {
      return false;
    } finally {
      if (_client == null) client.close();
    }
  }

  /// `vendor/model:free` and friends are the same model as far as its
  /// modalities go, and only the bare id has an endpoints page.
  static String _bare(String modelId) {
    final id = modelId.trim();
    final colon = id.indexOf(':');
    return colon < 0 ? id : id.substring(0, colon);
  }
}

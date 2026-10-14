import 'package:flutter/material.dart';

import '../../theme/iuna_theme.dart';
import '../../widgets/section_header.dart';
import '../../widgets/snack.dart';
import '../../widgets/text_input_dialog.dart';
import '../learn.dart';
import '../learn_settings.dart';
import '../llm/model_vision.dart';
import '../llm/openrouter_client.dart';

/// Settings → AI tutor: the OpenRouter key, whose presence is what shows
/// the Learn tab, the model, and what the tutor has cost so far.
class TutorSettingsSection extends StatefulWidget {
  const TutorSettingsSection({super.key});

  @override
  State<TutorSettingsSection> createState() => _TutorSettingsSectionState();
}

class _TutorSettingsSectionState extends State<TutorSettingsSection> {
  LearnSettings get _settings => LearnSettings.instance;

  String? _key;
  String _model = kDefaultLearnModel;
  double _spent = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadSpent();
  }

  Future<void> _load() async {
    final key = await _settings.apiKey();
    final model = await _settings.model();
    if (!mounted) return;
    setState(() {
      _key = key;
      _model = model;
    });
  }

  /// Kept out of [_load]: it may open the tutor's database.
  Future<void> _loadSpent() async {
    final repo = await Learn.instance.existingRepo();
    final spent = await repo?.totalCost() ?? 0.0;
    if (mounted) setState(() => _spent = spent);
  }

  Future<void> _editApiKey() async {
    final result = await showTextInputDialog(
      context,
      title: 'OpenRouter API key',
      message: 'Kuma-sensei calls OpenRouter straight from this phone with '
          'your key. It is kept in the Android Keystore and never goes into '
          'a backup.',
      hint: 'sk-or-v1-…',
      obscure: true,
      removeLabel: _key == null ? null : 'Remove',
    );
    if (result == null || !mounted) return;
    if (result.remove) {
      await _settings.clearApiKey();
      if (!mounted) return;
      setState(() => _key = null);
      showSnack(context, 'Key removed — the Learn tab is hidden');
      return;
    }
    if (result.text.isEmpty) return;
    setState(() => _busy = true);
    final check = await checkOpenRouterKey(result.text);
    if (!mounted) return;
    if (check is KeyRejected) {
      setState(() => _busy = false);
      showSnack(context, 'OpenRouter rejected that key');
      return;
    }
    await _settings.setApiKey(result.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _key = result.text;
    });
    showSnack(context, check is KeyUnverified
        ? "Saved, but OpenRouter couldn't be reached to check it"
        : 'Key saved — Kuma-sensei is in the Learn tab');
  }

  Future<void> _editModel() async {
    final result = await showTextInputDialog(
      context,
      title: 'Tutor model',
      message: 'Any OpenRouter model id that supports tool calling. '
          'Default: $kDefaultLearnModel.',
      initial: _model,
      hint: kDefaultLearnModel,
      removeLabel: 'Reset',
    );
    if (result == null) return;
    await _settings.setModel(result.remove ? null : result.text);
    final model = await _settings.model();
    if (!mounted) return;
    setState(() => _model = model);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const IunaSectionHeader('AI tutor'),
        ListTile(
          leading: const Icon(Icons.key_rounded, color: IunaPalette.pawBrown),
          title: const Text('OpenRouter API key'),
          subtitle: Text(
            _key == null
                ? 'Not set. The Learn tab appears once a key is saved.'
                : 'In the Android Keystore · ${LearnSettings.mask(_key!)}',
          ),
          trailing: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : _key == null
                  ? FilledButton(onPressed: _editApiKey, child: const Text('Add'))
                  : OutlinedButton(onPressed: _editApiKey, child: const Text('Change')),
        ),
        ListTile(
          leading: const Icon(Icons.psychology_rounded, color: IunaPalette.pawBrown),
          title: const Text('Tutor model'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_model),
              const SizedBox(height: 2),
              Text(
                'Photos go to $kPhotoFallbackModel when this one cannot read them.',
                style: const TextStyle(fontSize: 11, color: IunaPalette.ink3),
              ),
            ],
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right_rounded, color: IunaPalette.ink3),
          onTap: _editModel,
        ),
        ListTile(
          leading: const Icon(Icons.receipt_long_rounded, color: IunaPalette.pawBrown),
          title: const Text('Tutor usage'),
          subtitle: const Text('Spent on this phone, as OpenRouter reports it.'),
          trailing: Text(
            _formatCost(_spent),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: IunaPalette.ink2),
          ),
        ),
      ],
    );
  }
}

String _formatCost(double usd) {
  if (usd <= 0) return r'$0.00';
  if (usd < 0.01) return r'< $0.01';
  return '\$${usd.toStringAsFixed(2)}';
}

import 'package:flutter/cupertino.dart';
import 'api_service.dart';

class ProfilePage extends StatefulWidget {
  final String initialEndpoint;
  final String initialApiKey;
  final String initialModel;
  final String initialVisionModel;
  final String initialSystemPrompt;
  final List<String> availableModels;
  final Future<void> Function(String ep, String key, String model, String vModel, String sys) onSave;
  final Future<List<String>> Function(String ep, String key) onFetchModels;

  const ProfilePage({
    super.key,
    required this.initialEndpoint,
    required this.initialApiKey,
    required this.initialModel,
    required this.initialVisionModel,
    required this.initialSystemPrompt,
    required this.availableModels,
    required this.onSave,
    required this.onFetchModels,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _ep, _key, _manualModel, _manualVisionModel, _sysPrompt;
  List<String> _models = [];
  String _selectedModel = '';
  String _selectedVisionModel = '';
  bool _fetching = false, _saving = false, _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _ep = TextEditingController(text: widget.initialEndpoint);
    _key = TextEditingController(text: widget.initialApiKey);
    _manualModel = TextEditingController(text: widget.initialModel);
    _manualVisionModel = TextEditingController(text: widget.initialVisionModel);
    _sysPrompt = TextEditingController(text: widget.initialSystemPrompt);
    _selectedModel = widget.initialModel;
    _selectedVisionModel = widget.initialVisionModel;
    _models = List.from(widget.availableModels);
  }

  @override
  void dispose() {
    _ep.dispose(); _key.dispose(); _manualModel.dispose(); _manualVisionModel.dispose(); _sysPrompt.dispose();
    super.dispose();
  }

  Future<void> _fetchModels() async {
    if (_ep.text.trim().isEmpty || _key.text.trim().isEmpty) {
      _alert('Enter endpoint and API key first.');
      return;
    }
    setState(() => _fetching = true);
    final result = await widget.onFetchModels(_ep.text.trim(), _key.text.trim());
    setState(() { _models = result; _fetching = false; });
    if (result.isEmpty) _alert('No models returned. Check endpoint/key.');
  }

  void _showModelPicker({bool isVision = false}) {
    if (_models.isEmpty) { _alert('Fetch models first.'); return; }
    showCupertinoModalPopup(
      context: context,
      builder: (_) => _ModelPickerSheet(
        models: _models,
        selected: isVision ? _selectedVisionModel : _selectedModel,
        onSelected: (m) => setState(() {
          if (isVision) {
            _selectedVisionModel = m; _manualVisionModel.text = m;
          } else {
            _selectedModel = m; _manualModel.text = m;
          }
        }),
      ),
    );
  }

  void _alert(String msg) => showCupertinoDialog(
    context: context,
    builder: (_) => CupertinoAlertDialog(
      title: const Text('Notice'), content: Text(msg),
      actions: [CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(context))],
    ),
  );

  Future<void> _save() async {
    final model = _selectedModel.isNotEmpty ? _selectedModel : _manualModel.text.trim();
    final vModel = _selectedVisionModel.isNotEmpty ? _selectedVisionModel : _manualVisionModel.text.trim();
    if (model.isEmpty) { _alert('Enter or select a model.'); return; }
    setState(() => _saving = true);
    await widget.onSave(_ep.text.trim(), _key.text.trim(), model, vModel, _sysPrompt.text.trim());
    setState(() => _saving = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final primaryColor = CupertinoColors.label.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: isDark ? CupertinoColors.black : CupertinoColors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: isDark ? CupertinoColors.black : CupertinoColors.systemBackground,
        border: null,
        middle: const Text('Profile'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: Text('Back', style: TextStyle(color: primaryColor)),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saving ? null : _save,
          child: _saving
              ? const CupertinoActivityIndicator()
              : Text('Save', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600)),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _header('API Configuration'),
            _card([
              _fieldRow(CupertinoIcons.link, CupertinoColors.systemGrey, _ep, 'Endpoint',
                keyboardType: TextInputType.url),
              _customRow(CupertinoIcons.lock_fill, CupertinoColors.systemGrey,
                Row(children: [
                  Expanded(child: CupertinoTextField(
                    controller: _key,
                    placeholder: 'API Key',
                    obscureText: _obscureKey,
                    decoration: null,
                    style: TextStyle(fontSize: 16, color: primaryColor),
                    placeholderStyle: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 16),
                    padding: EdgeInsets.zero,
                  )),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                    child: Icon(_obscureKey ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                      size: 18, color: CupertinoColors.systemGrey),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 20),

            _header('Models'),
            _card([
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  _iconBox(CupertinoIcons.arrow_2_circlepath, CupertinoColors.systemGrey),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Available Models', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: primaryColor)),
                    Text(_models.isEmpty ? 'Tap Fetch to load' : '${_models.length} models',
                      style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
                  ])),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _fetching ? null : _fetchModels,
                    child: _fetching
                        ? const CupertinoActivityIndicator()
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(20)),
                            child: Text('Fetch', style: TextStyle(color: isDark ? CupertinoColors.black : CupertinoColors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                  ),
                ]),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _models.isNotEmpty ? _showModelPicker : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    _iconBox(CupertinoIcons.cube_box, CupertinoColors.systemGrey),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Select Model', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: primaryColor)),
                      Text(_selectedModel.isNotEmpty ? _selectedModel : 'Choose from list',
                        style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey), overflow: TextOverflow.ellipsis),
                    ])),
                    const Icon(CupertinoIcons.chevron_right, size: 16, color: CupertinoColors.systemGrey),
                  ]),
                ),
              ),
              _fieldRow(CupertinoIcons.pencil, CupertinoColors.systemGrey, _manualModel,
                'Manual model entry',
                onChanged: (v) => setState(() => _selectedModel = v)),
            ]),
            const SizedBox(height: 20),

            _header('Capabilities'),
            _card([
              _fieldRow(CupertinoIcons.eye_fill, CupertinoColors.systemGrey, _manualVisionModel,
                'Vision model'),
            ]),
            const SizedBox(height: 20),

            _header('Custom Instructions'),
            _card([
              Padding(
                padding: const EdgeInsets.all(16),
                child: CupertinoTextField(
                  controller: _sysPrompt,
                  placeholder: 'System prompt...',
                  placeholderStyle: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 14, height: 1.5),
                  decoration: null,
                  style: TextStyle(fontSize: 15, height: 1.5, color: primaryColor),
                  maxLines: 6, minLines: 3,
                  padding: EdgeInsets.zero,
                ),
              ),
            ]),
            const SizedBox(height: 32),

            CupertinoButton(
              color: primaryColor,
              borderRadius: BorderRadius.circular(14),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? CupertinoActivityIndicator(color: isDark ? CupertinoColors.black : CupertinoColors.white)
                  : Text('Save Profile', style: TextStyle(color: isDark ? CupertinoColors.black : CupertinoColors.white, fontWeight: FontWeight.w600, fontSize: 17)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _header(String t) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93), letterSpacing: 0.5)),
  );

  Widget _card(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(children: children),
  );

  Widget _iconBox(IconData icon, Color color) => Container(
    width: 32, height: 32,
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Icon(icon, size: 18, color: color),
  );

  Widget _fieldRow(IconData icon, Color color, TextEditingController ctrl, String placeholder,
      {TextInputType? keyboardType, ValueChanged<String>? onChanged}) {
    final primaryColor = CupertinoColors.label.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        _iconBox(icon, color), const SizedBox(width: 14),
        Expanded(child: CupertinoTextField(
          controller: ctrl, placeholder: placeholder,
          keyboardType: keyboardType, decoration: null,
          style: TextStyle(fontSize: 16, color: primaryColor),
          placeholderStyle: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 16),
          padding: EdgeInsets.zero, onChanged: onChanged,
        )),
      ]),
    );
  }

  Widget _customRow(IconData icon, Color color, Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: [_iconBox(icon, color), const SizedBox(width: 14), Expanded(child: child)]),
  );
}

// ====================================================================
// Model picker sheet
// ====================================================================
class _ModelPickerSheet extends StatefulWidget {
  final List<String> models;
  final String selected;
  final ValueChanged<String> onSelected;
  const _ModelPickerSheet({required this.models, required this.selected, required this.onSelected});
  @override
  State<_ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends State<_ModelPickerSheet> {
  late String _current;
  final _search = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _current = widget.selected;
    _filtered = widget.models;
    _search.addListener(() {
      final q = _search.text.toLowerCase();
      setState(() => _filtered = q.isEmpty
          ? widget.models
          : widget.models.where((m) => m.toLowerCase().contains(q)).toList());
    });
  }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? CupertinoColors.systemGrey6.darkColor : CupertinoColors.systemGrey6.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 5,
            decoration: BoxDecoration(color: CupertinoColors.systemGrey3, borderRadius: BorderRadius.circular(2.5))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Select Model', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: CupertinoColors.label.resolveFrom(context))),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
                child: Text('Done', style: TextStyle(color: CupertinoColors.label.resolveFrom(context), fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CupertinoTextField(
                controller: _search,
                placeholder: 'Search models…',
                prefix: const Padding(padding: EdgeInsets.only(left: 12),
                  child: Icon(CupertinoIcons.search, size: 16, color: CupertinoColors.systemGrey)),
                decoration: null,
                style: TextStyle(fontSize: 15, color: CupertinoColors.label.resolveFrom(context)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => Container(height: 0.5, color: const Color(0xFFE5E5EA), margin: const EdgeInsets.only(left: 16)),
                itemBuilder: (_, i) {
                  final m = _filtered[i];
                  final sel = m == _current;
                  return CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() => _current = m);
                      widget.onSelected(m);
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(children: [
                        Expanded(child: Text(m, style: TextStyle(fontSize: 15,
                          color: sel ? CupertinoColors.systemGrey : CupertinoColors.label.resolveFrom(context),
                          fontWeight: sel ? FontWeight.w600 : FontWeight.normal))),
                        if (sel) const Icon(CupertinoIcons.checkmark, size: 16, color: CupertinoColors.systemGrey),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

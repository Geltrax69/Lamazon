import 'package:flutter/material.dart';
import '../data/api.dart';
import '../data/campaigns.dart';
import '../data/categories.dart';
import '../widgets/app_shell.dart';
import '../widgets/design_system.dart';
import '../widgets/photo_picker.dart';
import '../widgets/screen_header.dart';
import '../widgets/storefront.dart';

class CampaignManager extends StatefulWidget {
  const CampaignManager({super.key});
  @override
  State<CampaignManager> createState() => _CampaignManagerState();
}

class _CampaignManagerState extends State<CampaignManager> {
  late Future<List<Campaign>> _future = Api.instance.campaigns(admin: true);
  void _reload() =>
      setState(() => _future = Api.instance.campaigns(admin: true));
  Future<void> _edit([Campaign? campaign]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CampaignEditor(campaign: campaign)),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _delete(Campaign c) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this banner?'),
        content: Text(
          '“${c.title}” will be removed from the storefront. You can hide it in Edit instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep banner'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await Api.instance.deleteCampaign(c.id);
      if (mounted) _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not delete banner. $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          const Text(
            'Storefront banners',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          FilledButton.icon(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Create banner'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'Set the mood for your store. Edit the image, message, category and display order. Published changes appear when shoppers refresh Home.',
      ),
      const SizedBox(height: 20),
      FutureBuilder<List<Campaign>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Skeleton(height: 220);
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off,
              title: 'Banners could not load',
              message:
                  'Check your connection and that the updated API is running.',
              action: 'Try again',
              onAction: _reload,
            );
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return EmptyState(
              icon: Icons.photo_library_outlined,
              title: 'Start with a story',
              message: 'Create a banner for a category or your whole store.',
              action: 'Create banner',
              onAction: () => _edit(),
            );
          }
          return Column(
            children: [
              for (final c in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CampaignBanner(campaign: c, onTap: () => _edit(c)),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${c.enabled ? 'Published' : 'Hidden'} · Order ${c.position} · ${c.department.isEmpty ? 'All departments' : c.department}',
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: () => _edit(c),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit banner'),
                              ),
                              IconButton(
                                tooltip: 'Delete ${c.title}',
                                onPressed: () => _delete(c),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class CampaignEditor extends StatefulWidget {
  final Campaign? campaign;
  const CampaignEditor({super.key, this.campaign});
  @override
  State<CampaignEditor> createState() => _CampaignEditorState();
}

class _CampaignEditorState extends State<CampaignEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.campaign?.title ?? '');
  late final _subtitle = TextEditingController(
    text: widget.campaign?.subtitle ?? '',
  );
  late final _cta = TextEditingController(
    text: widget.campaign?.cta ?? 'Shop collection',
  );
  late final _image = TextEditingController(
    text: widget.campaign?.imageUrl ?? '',
  );
  late final _colour = TextEditingController(
    text: widget.campaign?.colour ?? '#F2E8CE',
  );
  late final _position = TextEditingController(
    text: '${widget.campaign?.position ?? 0}',
  );
  late String _category = widget.campaign?.category ?? '';
  late String _department = widget.campaign?.department ?? '';
  late bool _enabled = widget.campaign?.enabled ?? false;
  late final String _id =
      widget.campaign?.id ?? 'banner-${DateTime.now().microsecondsSinceEpoch}';
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_title, _subtitle, _cta, _image, _colour, _position]) {
      c.dispose();
    }
    super.dispose();
  }

  Campaign get _draft => Campaign(
    id: _id,
    title: _title.text.trim(),
    subtitle: _subtitle.text.trim(),
    cta: _cta.text.trim(),
    category: _category,
    department: _department,
    imageUrl: _image.text.trim(),
    colour: _colour.text.trim(),
    enabled: _enabled,
    position: int.tryParse(_position.text) ?? 0,
  );
  Future<void> _upload() async {
    try {
      final photos = await pickPhotos(multiple: false);
      if (photos.isEmpty || !mounted) return;
      setState(() {
        _busy = true;
        _error = null;
      });
      final url = await Api.instance.uploadCampaignPhoto(photos.first);
      if (mounted) setState(() => _image.text = url);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Image upload failed. Your other edits are still here; try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.instance.saveCampaign(_draft);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'Could not save banner. ${e.toString().replaceFirst('ClientException: ', '')}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int? max,
    int lines = 1,
    String? Function(String?)? validate,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: !_busy,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: lines > 1,
      ),
      maxLength: max,
      maxLines: lines,
      onChanged: (_) => setState(() {}),
      validator: validate,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final categories = <String>{
      '',
      for (final d in departments.where((d) => d.name != 'All')) d.name,
      ...sellableCategories(),
      for (final d in departments) ...d.categories.map((c) => c.name),
    };
    final depts = <String>{
      '',
      ...departments.where((d) => d.name != 'All').map((d) => d.name),
    };
    // Deleted destinations stay visible to staff, who must replace them before saving.
    if (_category.isNotEmpty) categories.add(_category);
    if (_department.isNotEmpty) depts.add(_department);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: widget.campaign == null ? 'Create banner' : 'Edit banner',
            ),
            Expanded(
              child: ReadableBody(
                maxWidth: 720,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Live preview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CampaignBanner(campaign: _draft),
                    const SizedBox(height: 24),
                    Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _field(
                            'Headline',
                            _title,
                            max: 65,
                            validate: (s) =>
                                s!.trim().isEmpty ? 'Add a headline' : null,
                          ),
                          _field('Description', _subtitle, max: 120, lines: 2),
                          _field(
                            'Button label',
                            _cta,
                            max: 28,
                            validate: (s) => s!.trim().isEmpty
                                ? 'Name the button action'
                                : null,
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: _category,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Open this category',
                            ),
                            items: [
                              for (final c in categories)
                                DropdownMenuItem(
                                  value: c,
                                  child: Text(c.isEmpty ? 'All products' : c),
                                ),
                            ],
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _category = v!),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _department,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Show banner in',
                            ),
                            items: [
                              for (final d in depts)
                                DropdownMenuItem(
                                  value: d,
                                  child: Text(
                                    d.isEmpty
                                        ? 'Home + all departments'
                                        : 'Home + $d',
                                  ),
                                ),
                            ],
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _department = v!),
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _upload,
                            icon: const Icon(Icons.file_upload_outlined),
                            label: Text(
                              _busy ? 'Please wait…' : 'Upload campaign image',
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              'Use a clear photo with the subject centred. The app adds the headline and button. Leave the image empty for category artwork.',
                            ),
                          ),
                          _field(
                            'Image URL (optional)',
                            _image,
                            validate: (s) {
                              final u = Uri.tryParse(s!.trim());
                              return s.trim().isEmpty ||
                                      (u != null &&
                                          u.scheme == 'https' &&
                                          u.host.isNotEmpty &&
                                          u.userInfo.isEmpty)
                                  ? null
                                  : 'Use a valid HTTPS image URL';
                            },
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final hex in [
                                '#F2E8CE',
                                '#DCEACD',
                                '#F7DCCB',
                                '#E7DFF3',
                                '#DCE9F5',
                                '#1D4A3C',
                              ])
                                IconButton(
                                  tooltip: 'Use $hex',
                                  onPressed: _busy
                                      ? null
                                      : () =>
                                            setState(() => _colour.text = hex),
                                  icon: Icon(
                                    _colour.text == hex
                                        ? Icons.check_circle
                                        : Icons.circle,
                                    color: Campaign(
                                      id: '',
                                      title: '',
                                      subtitle: '',
                                      colour: hex,
                                    ).background,
                                  ),
                                  style: IconButton.styleFrom(
                                    side: const BorderSide(
                                      color: LamazonTheme.line,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _field(
                            'Background colour',
                            _colour,
                            validate: (s) =>
                                RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(s!.trim())
                                ? null
                                : 'Use a hex colour such as #F2E8CE',
                          ),
                          _field(
                            'Display order (lowest first)',
                            _position,
                            validate: (s) {
                              final n = int.tryParse(s ?? '');
                              return n != null && n >= 0 && n <= 9999
                                  ? null
                                  : 'Enter a number from 0 to 9999';
                            },
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Published'),
                            subtitle: Text(
                              _enabled
                                  ? 'Visible to shoppers after saving'
                                  : 'Hidden from shoppers',
                            ),
                            value: _enabled,
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _enabled = v),
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _busy ? null : _save,
                            child: Text(_busy ? 'Saving…' : 'Save banner'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

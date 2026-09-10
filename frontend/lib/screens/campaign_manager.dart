import 'dart:async';

import 'package:flutter/material.dart';
import '../data/api.dart';
import '../data/catalog.dart';
import '../data/campaigns.dart';
import '../data/categories.dart';
import '../widgets/app_shell.dart';
import '../widgets/design_system.dart';
import '../widgets/photo_picker.dart';
import '../widgets/campaign_palette.dart';
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
      const SectionHeading(title: 'Storefront banners'),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: ActionButton(
          onPressed: () => _edit(),
          icon: Icons.add,
          label: 'Create banner',
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Set the mood for your store. Edit the image, message, category and display order. Published changes appear when shoppers refresh Home.',
        style: LamazonTheme.mutedBodyText,
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
                      const SizedBox(height: 8),
                      ElevatedSurface(
                        radius: LamazonTheme.smallRadius,
                        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${c.enabled ? 'Published' : 'Hidden'} · Order ${c.position} · ${c.department.isEmpty ? 'All departments' : c.department}',
                              style: LamazonTheme.mutedBodyText,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ActionButton(
                                  onPressed: () => _edit(c),
                                  icon: Icons.edit_outlined,
                                  label: 'Edit banner',
                                  primary: false,
                                ),
                                TactileIconButton(
                                  label: 'Delete ${c.title}',
                                  onPressed: () => _delete(c),
                                  icon: Icons.delete_outline,
                                  foreground: LamazonTheme.danger,
                                  size: 40,
                                ),
                              ],
                            ),
                          ],
                        ),
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
    text: widget.campaign?.colour ?? CampaignPalette.forest.hex,
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

  /// What the preview is currently showing. It trails the field by a moment:
  /// every keystroke in a URL is a different address, and handing each of them
  /// to a video player in turn starts and abandons a request per character.
  late String _preview = _image.text.trim();
  Timer? _settle;

  void _previewSoon() {
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 350), () {
      final now = _image.text.trim();
      if (mounted && now != _preview) setState(() => _preview = now);
    });
  }

  @override
  void dispose() {
    _settle?.cancel();
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
  /// Takes the pasted link, whatever it is, and comes back with something the
  /// banner can actually show.
  static String _reason(Object error) =>
      error.toString().replaceFirst('ClientException: ', '');

  Future<void> _fetchLink() async {
    final link = _image.text.trim();
    if (link.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = await Api.instance.importCampaignMedia(link);
      if (mounted) {
        setState(() {
          _image.text = url;
          _preview = url;
        });
      }
    } catch (error) {
      // The server's message is the useful one — it says which part of the
      // link it could not make sense of, and what to paste instead.
      if (mounted) setState(() => _error = _reason(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// What the link in the field appears to be, said plainly under it.
  (String, bool) get _detected {
    if (_preview.isEmpty) {
      return (
        'Paste a link to a photo, GIF or clip — or a Pinterest, Instagram or '
            'blog page, then press Fetch and we will pull the picture out of it.',
        false,
      );
    }
    final uri = Uri.tryParse(_preview);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return ('Use a full https:// link.', true);
    }
    return switch (bannerKind(_preview)) {
      BannerKind.video => ('Clip — plays muted, loops, no sound.', false),
      BannerKind.animation => ('Animation — delivered as a clip, not as a GIF.', false),
      BannerKind.picture => (
        'Photo. If this is a page rather than a file, press Fetch.',
        false,
      ),
    };
  }

  Future<void> _upload() async {
    try {
      final picked = await pickBannerMedia();
      if (picked == null || !mounted) return;
      setState(() {
        _busy = true;
        _error = null;
      });
      final url = await Api.instance.uploadCampaignPhoto(
        picked.bytes,
        filename: picked.name,
      );
      if (mounted) {
        setState(() {
          _image.text = url;
          _preview = url;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Artwork upload failed. Your other edits are still here; try again.',
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
    VoidCallback? onChanged,
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
      onChanged: (_) {
        setState(() {});
        onChanged?.call();
      },
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
                    const SectionHeading(title: 'Live preview'),
                    const SizedBox(height: 12),
                    CampaignBanner(campaign: _draft.withArtwork(_preview)),
                    const SizedBox(height: 24),
                    ElevatedSurface(
                      padding: const EdgeInsets.all(16),
                      child: Form(
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
                            _field(
                              'Description',
                              _subtitle,
                              max: 120,
                              lines: 2,
                            ),
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
                            SizedBox(
                              width: double.infinity,
                              child: ActionButton(
                                onPressed: _busy ? null : _upload,
                                icon: Icons.file_upload_outlined,
                                label: _busy
                                    ? 'Please wait…'
                                    : 'Upload banner artwork',
                                primary: false,
                                expand: true,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                'A 16:9 photo, GIF or short clip, with the subject on the right — the template keeps the headline and action legible on the left. Clips play muted and on a loop, so keep them under about ten seconds and let the picture carry the message. You can also paste a link below instead of uploading.',
                                style: LamazonTheme.mutedBodyText,
                              ),
                            ),
                            _field(
                              'Artwork URL (optional)',
                              _image,
                              onChanged: _previewSoon,
                              validate: (s) {
                                final u = Uri.tryParse(s!.trim());
                                return s.trim().isEmpty ||
                                        (u != null &&
                                            u.scheme == 'https' &&
                                            u.host.isNotEmpty &&
                                            u.userInfo.isEmpty)
                                    ? null
                                    : 'Use a valid HTTPS URL';
                              },
                            ),
                            _LinkStatus(
                              message: _detected.$1,
                              wrong: _detected.$2,
                              onFetch: _busy || _image.text.trim().isEmpty
                                  ? null
                                  : _fetchLink,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Choose a banner theme',
                              style: LamazonTheme.bodyText,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final palette in CampaignPalette.presets)
                                  TactileIconButton(
                                    label: 'Use ${palette.name}',
                                    onPressed: _busy
                                        ? null
                                        : () => setState(
                                            () => _colour.text = palette.hex,
                                          ),
                                    icon:
                                        _colour.text.trim().toUpperCase() ==
                                            palette.hex
                                        ? Icons.check_circle
                                        : Icons.circle,
                                    background: palette.background,
                                    foreground: palette.foreground,
                                    selected:
                                        _colour.text.trim().toUpperCase() ==
                                        palette.hex,
                                    size: 40,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _field(
                              'Background colour',
                              _colour,
                              validate: (s) =>
                                  RegExp(
                                    r'^#[0-9a-fA-F]{6}$',
                                  ).hasMatch(s!.trim())
                                  ? null
                                  : 'Use a hex colour such as #143E32',
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: LamazonTheme.danger,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                            ActionButton(
                              onPressed: _busy ? null : _save,
                              label: _busy ? 'Saving…' : 'Save banner',
                              expand: true,
                            ),
                          ],
                        ),
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

/// What the pasted link appears to be, and the one button that fixes it when
/// it is a page rather than a file.
class _LinkStatus extends StatelessWidget {
  final String message;
  final bool wrong;
  final VoidCallback? onFetch;
  const _LinkStatus({
    required this.message,
    required this.wrong,
    this.onFetch,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          message,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: wrong ? LamazonTheme.warning : LamazonTheme.muted,
          ),
        ),
      ),
      const SizedBox(width: 12),
      ActionButton(
        onPressed: onFetch,
        icon: Icons.link,
        label: 'Fetch',
        primary: false,
      ),
    ],
  );
}

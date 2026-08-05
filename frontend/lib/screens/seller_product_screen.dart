import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/api.dart';
import '../data/categories.dart';
import '../models/product.dart';
import '../data/seller.dart';
import '../widgets/photo_picker.dart';
import '../widgets/product_card.dart';
import '../widgets/screen_header.dart';
import '../widgets/seller_form.dart';

const _muted = Color(0xFF6B6B6B);
const _amber = Color(0xFFEF6C00);

/// Add or edit one inventory line.
class SellerProductScreen extends StatefulWidget {
  final InventoryItem? existing;
  const SellerProductScreen({super.key, this.existing});

  @override
  State<SellerProductScreen> createState() => _SellerProductScreenState();
}

class _SellerProductScreenState extends State<SellerProductScreen> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _desc = TextEditingController(text: widget.existing?.description);
  late final _price = TextEditingController(
    text: widget.existing?.price.toStringAsFixed(0),
  );
  // Blank rather than "0" when there is no discount: a zero in the box reads
  // as a price the seller has to clear before typing.
  late final _mrp = TextEditingController(
    text: (widget.existing?.mrp ?? 0) > 0
        ? widget.existing!.mrp.toStringAsFixed(0)
        : '',
  );
  late final _stock = TextEditingController(
    text: widget.existing?.stock.toString(),
  );
  late List<Uint8List> _photos = [...?widget.existing?.photos];
  late final List<ItemOption> _options = [...?widget.existing?.options];
  late String _group = widget.existing?.compareGroup ?? '';
  late final Map<String, String> _attrs = {...?widget.existing?.attributes};

  /// Loaded once. A seller cannot invent a group — the admin owns the list,
  /// because two shops typing "Chargers" and "charger" would compare against
  /// nothing.
  late final Future<List<CompareGroup>> _groups = Api.instance.compareGroups();
  late String _category =
      widget.existing?.category ??
      (Seller.instance.store?.categories.first ?? _categoryOptions.first);

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    _mrp.dispose();
    _stock.dispose();
    super.dispose();
  }

  /// What this seller may file an item under: the admin's categories inside
  /// the departments this store signed up for. A department with no
  /// categories yet offers itself, so a new one is never unsellable in.
  List<String> get _categoryOptions {
    final mine = Seller.instance.store?.categories ?? const <String>[];
    final out = [for (final d in mine) ...sellableCategories(d)];
    return out.isEmpty ? sellableCategories() : out;
  }

  /// A group with no values is one the seller started and abandoned; saving it
  /// would show the buyer a heading with nothing to pick under it.
  List<ItemOption> get _liveOptions =>
      [for (final o in _options) if (o.values.isNotEmpty) o];

  double? get _priceValue => double.tryParse(_price.text.trim());
  int? get _stockValue => int.tryParse(_stock.text.trim());

  /// Empty means no discount, which is different from a typo. A blank box
  /// gives 0; anything unparseable gives null, and the blocker catches it.
  double? get _mrpValue {
    final text = _mrp.text.trim();
    if (text.isEmpty) return 0;
    return double.tryParse(text);
  }

  int get _percentOff {
    final mrp = _mrpValue ?? 0, price = _priceValue ?? 0;
    if (mrp <= price || mrp <= 0) return 0;
    return (((mrp - price) / mrp) * 100).round();
  }

  /// A saved listing keeps its photos on Cloudinary, not in memory — the edit
  /// screen only holds bytes for pictures picked in this session. Counting
  /// only those made "Add at least one photo" block every edit of an item
  /// that already had photos, which is to say every edit.
  List<String> get _savedPhotos => widget.existing?.imageUrls ?? const [];

  bool get _hasPhotos => _photos.isNotEmpty || _savedPhotos.isNotEmpty;

  String? get _blocker {
    if (!_hasPhotos) return 'Add at least one photo';
    if (_title.text.trim().isEmpty) return 'Give the product a title';
    if ((_priceValue ?? 0) <= 0) return 'Set a price above ₹0';
    if (_mrpValue == null) return 'MRP must be a number, or left blank';
    if (_mrpValue! > 0 && _mrpValue! < (_priceValue ?? 0)) {
      return 'MRP cannot be below the selling price';
    }
    if ((_stockValue ?? -1) < 0) return 'Enter how many units you have';
    return null;
  }

  /// The percentage is never typed, only shown: it is the one number here
  /// that is a consequence of the other two rather than a decision.
  Widget _discountNote() {
    final mrp = _mrpValue ?? 0, price = _priceValue ?? 0;
    if (mrp <= 0 || price <= 0) return const SizedBox.shrink();
    final bad = mrp < price;
    final same = mrp == price;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(
            bad ? LucideIcons.circleAlert : LucideIcons.badgePercent,
            size: 14,
            color: bad ? _amber : const Color(0xFF1B7F3B),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              bad
                  ? 'MRP is below your selling price — buyers would see a '
                        'markup, not a discount.'
                  : same
                  ? 'Same as the selling price, so no discount is shown.'
                  : 'Buyers see $_percentOff% OFF — '
                        '₹${(mrp - price).toStringAsFixed(0)} saved.',
              style: TextStyle(
                fontSize: 12,
                color: bad ? _amber : _muted,
                fontWeight: bad ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Only the fields the chosen group asks for. Switching group leaves the
  /// old answers in the map; sending them would file a charger's Wattage
  /// under a shampoo.
  Map<String, String> _liveAttrs(List<CompareGroup> groups) {
    if (_group.isEmpty) return const {};
    final template = groups
        .where((g) => g.name == _group)
        .expand((g) => g.attributes)
        .map((a) => a.name)
        .toSet();
    return {
      for (final e in _attrs.entries)
        if (template.contains(e.key) && e.value.trim().isNotEmpty)
          e.key: e.value.trim(),
    };
  }

  void _save(List<CompareGroup> groups) {
    final attrs = _liveAttrs(groups);
    final item = widget.existing;
    if (item == null) {
      Seller.instance.addItem(
        InventoryItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: _title.text.trim(),
          description: _desc.text.trim(),
          category: _category,
          price: _priceValue!,
          mrp: _mrpValue!,
          options: _liveOptions,
          compareGroup: _group,
          attributes: attrs,
          stock: _stockValue!,
          photos: _photos,
        ),
      );
    } else {
      item
        ..title = _title.text.trim()
        ..description = _desc.text.trim()
        ..category = _category
        ..price = _priceValue!
        ..mrp = _mrpValue!
        ..options = _liveOptions
        ..compareGroup = _group
        ..attributes = attrs
        ..stock = _stockValue!
        ..photos = _photos;
      Seller.instance.itemChanged(item);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final categories = _categoryOptions;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: ReadableBody(
        maxWidth: 620,
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: editing ? 'Edit product' : 'Add product'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    SellerSection(
                      title:
                          'Photos (${_photos.length + _savedPhotos.length})',
                      hint: 'Add as many as you like — the first is the cover',
                    ),
                    // The ones already live, so an edit screen does not look
                    // like a listing that lost its pictures. Anything picked
                    // below is added to these, not swapped for them.
                    if (_savedPhotos.isNotEmpty) ...[
                      SizedBox(
                        height: 74,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _savedPhotos.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 74,
                              child: NetImage(url: _savedPhotos[i]),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    PhotoStrip(
                      photos: _photos,
                      onChanged: (list) => setState(() => _photos = list),
                    ),
                    const SizedBox(height: 22),
                    const SellerSection(title: 'Title'),
                    SellerField(
                      controller: _title,
                      icon: LucideIcons.tag,
                      hint: 'e.g. Cold Coffee 300ml',
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 22),
                    const SellerSection(
                      title: 'Description',
                      hint: 'What the buyer gets',
                    ),
                    SellerField(
                      controller: _desc,
                      icon: LucideIcons.alignLeft,
                      hint: 'Size, flavour, condition…',
                      maxLines: 3,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 22),
                    // MRP beside the selling price, because the discount is
                    // the relationship between them and reading it means
                    // seeing both at once.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SellerSection(
                                title: 'MRP',
                                hint: 'Optional',
                              ),
                              SellerField(
                                controller: _mrp,
                                icon: LucideIcons.tag,
                                hint: '0',
                                keyboard: TextInputType.number,
                                onChanged: () => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SellerSection(
                                title: 'Selling price',
                                hint: 'What they pay',
                              ),
                              SellerField(
                                controller: _price,
                                icon: LucideIcons.indianRupee,
                                hint: '0',
                                keyboard: TextInputType.number,
                                onChanged: () => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    _discountNote(),
                    const SizedBox(height: 22),
                    const SellerSection(title: 'Stock'),
                    SellerField(
                      controller: _stock,
                      icon: LucideIcons.boxes,
                      hint: 'units',
                      keyboard: TextInputType.number,
                      onChanged: () => setState(() {}),
                    ),
                    if ((_stockValue ?? 1) == 0) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: const [
                          Icon(
                            LucideIcons.circleAlert,
                            size: 14,
                            color: _amber,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'With 0 units this shows as Sold out to buyers.',
                              style: TextStyle(fontSize: 12, color: _muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 22),
                    SellerSection(
                      title: 'Options',
                      hint: _options.isEmpty
                          ? 'Only if buyers have to choose — size, colour…'
                          : 'Buyers pick one of each before ordering',
                    ),
                    _OptionsEditor(
                      options: _options,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 22),
                    FutureBuilder<List<CompareGroup>>(
                      future: _groups,
                      builder: (context, snap) => _CompareSection(
                        groups: snap.data ?? const [],
                        chosen: _group,
                        values: _attrs,
                        onGroup: (g) => setState(() => _group = g),
                        onChanged: () => setState(() {}),
                      ),
                    ),
                    if (categories.length > 1) ...[
                      const SizedBox(height: 22),
                      const SellerSection(title: 'Category'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in categories)
                            SellerChoice(
                              label: c,
                              selected: _category == c,
                              onTap: () => setState(() => _category = c),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SellerSubmitBar(
                label: editing ? 'Save changes' : 'Add to inventory',
                blocker: _blocker,
                onSubmit: () async => _save(await _groups),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Presets, so the common cases are one tap and not a form. A clothes shop
/// wants Size with S–XL; making them type five boxes to get there is what
/// makes a seller decide options are not worth it.
const _presets = <String, ItemOption>{
  'Size': ItemOption(
    name: 'Size',
    values: ['S', 'M', 'L', 'XL'],
  ),
  'Colour': ItemOption(
    name: 'Colour',
    kind: 'colour',
    values: ['#1A1A1A', '#FFFFFF', '#D32F2F', '#2F6FED'],
  ),
  'Weight': ItemOption(
    name: 'Weight',
    values: ['250g', '500g', '1kg'],
  ),
  'Spice': ItemOption(
    name: 'Spice',
    values: ['Mild', 'Medium', 'Hot'],
  ),
};

/// Colours a swatch can be. A named row rather than a colour wheel: a shop is
/// picking "the red one", not #B71C1C exactly, and a wheel is a decision they
/// did not ask to make.
const _swatches = <String, String>{
  'Black': '#1A1A1A',
  'White': '#FFFFFF',
  'Grey': '#9E9E9E',
  'Red': '#D32F2F',
  'Pink': '#F06292',
  'Orange': '#FF8A3D',
  'Yellow': '#FBC02D',
  'Green': '#43A047',
  'Blue': '#2F6FED',
  'Navy': '#1A237E',
  'Purple': '#9C6ADE',
  'Brown': '#6D4C41',
  'Beige': '#D7CCC8',
  'Gold': '#C9A227',
};

Color _hexColour(String hex) => Color(
  0xFF000000 |
      (int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0),
);

/// The option groups on a listing, and the two taps that add one. Mutates the
/// list it is given — the screen owns it and saves it, this only edits.
class _OptionsEditor extends StatelessWidget {
  final List<ItemOption> options;
  final VoidCallback onChanged;
  const _OptionsEditor({required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final unused = _presets.keys
        .where((k) => !options.any((o) => o.name == k))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, option) in options.indexed) ...[
          _OptionGroup(
            option: option,
            onRemove: () {
              options.removeAt(i);
              onChanged();
            },
            onValues: (values) {
              options[i] = ItemOption(
                name: option.name,
                kind: option.kind,
                values: values,
              );
              onChanged();
            },
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Named presets come filled in; the shop deletes what it does not
            // sell rather than typing what it does.
            for (final name in unused)
              _AddChip(
                label: '+ $name',
                onTap: () {
                  options.add(_presets[name]!);
                  onChanged();
                },
              ),
            _AddChip(
              label: '+ Something else',
              onTap: () async {
                final name = await _askName(context);
                if (name == null || name.isEmpty) return;
                options.add(ItemOption(name: name));
                onChanged();
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<String?> _askName(BuildContext context) {
    final field = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('What do buyers choose?'),
        content: TextField(
          controller: field,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'e.g. Flavour, Length, Material',
          ),
          onSubmitted: (v) => Navigator.pop(dialog, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, field.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

/// One group: its name, its values as removable chips, and one field to add
/// another. Colour groups swap the field for swatches.
class _OptionGroup extends StatefulWidget {
  final ItemOption option;
  final VoidCallback onRemove;
  final ValueChanged<List<String>> onValues;
  const _OptionGroup({
    required this.option,
    required this.onRemove,
    required this.onValues,
  });

  @override
  State<_OptionGroup> createState() => _OptionGroupState();
}

class _OptionGroupState extends State<_OptionGroup> {
  final _entry = TextEditingController();

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  void _add(String value) {
    value = value.trim();
    // Duplicates would render as two identical chips the buyer cannot tell
    // apart, so silently ignore rather than warn about it.
    if (value.isEmpty || widget.option.values.contains(value)) return;
    widget.onValues([...widget.option.values, value]);
    _entry.clear();
  }

  @override
  Widget build(BuildContext context) {
    final option = widget.option;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  option.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove ${option.name}',
                onPressed: widget.onRemove,
                icon: const Icon(LucideIcons.trash2, size: 15, color: _amber),
              ),
            ],
          ),
          if (option.values.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Add at least one choice, or this group is dropped.',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in option.values)
                _ValueChip(
                  label: option.isColour ? _nameOf(value) : value,
                  swatch: option.isColour ? _hexColour(value) : null,
                  onRemove: () => widget.onValues(
                    [...option.values]..remove(value),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (option.isColour)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in _swatches.entries)
                  if (!option.values.contains(entry.value))
                    GestureDetector(
                      onTap: () => _add(entry.value),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _hexColour(entry.value),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black12),
                        ),
                      ),
                    ),
              ],
            )
          else
            SizedBox(
              height: 42,
              child: TextField(
                controller: _entry,
                textInputAction: TextInputAction.done,
                onSubmitted: _add,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Add a choice, then Enter',
                  hintStyle: const TextStyle(fontSize: 13, color: _muted),
                  filled: true,
                  fillColor: const Color(0xFFF4F4F2),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () => _add(_entry.text),
                    icon: const Icon(LucideIcons.plus, size: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The nearest name we have for a hex value, so a chip reads "Red" rather
  /// than "#D32F2F". Unknown values keep their hex — it is still true.
  String _nameOf(String hex) {
    for (final entry in _swatches.entries) {
      if (entry.value.toLowerCase() == hex.toLowerCase()) return entry.key;
    }
    return hex;
  }
}

class _ValueChip extends StatelessWidget {
  final String label;
  final Color? swatch;
  final VoidCallback onRemove;
  const _ValueChip({
    required this.label,
    required this.swatch,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1EF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (swatch != null) ...[
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: swatch,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(label, style: const TextStyle(fontSize: 12.5)),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(LucideIcons.x, size: 12, color: _muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AddChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDDDDD8)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Which products this one can be lined up against, and the fields that
/// comparison runs on. Collapsed to a single row of chips until one is
/// picked: most stock is not comparable to anything, and asking every seller
/// for Wattage is how a form starts feeling like paperwork.
class _CompareSection extends StatelessWidget {
  final List<CompareGroup> groups;
  final String chosen;
  final Map<String, String> values;
  final ValueChanged<String> onGroup;
  final VoidCallback onChanged;
  const _CompareSection({
    required this.groups,
    required this.chosen,
    required this.values,
    required this.onGroup,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    final template = groups
        .where((g) => g.name == chosen)
        .expand((g) => g.attributes)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SellerSection(
          title: 'Compare with',
          hint: 'Optional — puts this beside similar products',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in groups)
              _AddChip(
                label: g.name == chosen ? '✓ ${g.name}' : g.name,
                // Tapping the chosen one clears it, so opting out is the same
                // gesture as opting in.
                onTap: () => onGroup(g.name == chosen ? '' : g.name),
              ),
          ],
        ),
        if (template.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What buyers compare $chosen on',
                  style: const TextStyle(fontSize: 12.5, color: _muted),
                ),
                const SizedBox(height: 10),
                for (final field in template) ...[
                  Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          field.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: TextFormField(
                            initialValue: values[field.name] ?? '',
                            onChanged: (v) {
                              values[field.name] = v;
                              onChanged();
                            },
                            decoration: InputDecoration(
                              isDense: true,
                              // The unit sits in the box, so the seller types
                              // 20 rather than guessing whether to write 20W.
                              suffixText: field.unit,
                              hintText: '—',
                              filled: true,
                              fillColor: const Color(0xFFF4F4F2),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(11),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

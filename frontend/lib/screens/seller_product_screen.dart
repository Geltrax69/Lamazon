import '../data/money.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../widgets/design_system.dart';

import '../widgets/app_shell.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/api.dart';
import '../data/categories.dart';
import '../models/product.dart';
import '../data/seller.dart';
import '../widgets/photo_manager.dart';
import '../widgets/screen_header.dart';
import '../widgets/seller_form.dart';

const _muted = LamazonTheme.muted;
const _amber = LamazonTheme.warning;

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
    text: widget.existing?.price.moneyText,
  );
  // Blank rather than "0" when there is no discount: a zero in the box reads
  // as a price the seller has to clear before typing.
  late final _mrp = TextEditingController(
    text: (widget.existing?.mrp ?? 0) > 0 ? widget.existing!.mrp.moneyText : '',
  );
  late final _stock = TextEditingController(
    text: widget.existing?.stock.toString(),
  );

  /// Uploaded photos and just-picked ones in one list, because reordering has
  /// to work across the join — a photo added today can be dragged in front of
  /// one added last week.
  late List<Shot> _shots = [
    for (final url in widget.existing?.imageUrls ?? const <String>[])
      Shot.remote(url),
    for (final bytes in widget.existing?.photos ?? const <Uint8List>[])
      Shot.local(bytes),
  ];
  bool _savingPhotos = false;

  List<Uint8List> get _newPhotos => [
    for (final s in _shots)
      if (s.isNew) s.bytes!,
  ];
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

  /// The same options, kept under their section. The picker shows the sections
  /// first — a food shop has eighty leaves, and a wall of them is not a menu.
  Map<String, List<String>> get _categorySections {
    final mine = Seller.instance.store?.categories ?? const <String>[];
    final out = <String, List<String>>{};
    for (final d in mine) {
      out.addAll(sellableGroups(d));
    }
    return out.isEmpty ? sellableGroups() : out;
  }

  /// Which section chip is open. Follows the chosen category, so editing an
  /// item lands on the section it was already filed under.
  late String _section = _sectionOf(_category);

  String _sectionOf(String category) {
    for (final e in _categorySections.entries) {
      if (e.value.contains(category)) return e.key;
    }
    return _categorySections.keys.first;
  }

  /// A group with no values is one the seller started and abandoned; saving it
  /// would show the buyer a heading with nothing to pick under it.
  List<ItemOption> get _liveOptions => [
    for (final o in _options)
      if (o.values.isNotEmpty) o,
  ];

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
  bool get _hasPhotos => _shots.isNotEmpty;

  /// On a listing that already exists, a photo change is saved when it is
  /// made rather than waiting for Save — an upload takes seconds and holding
  /// the whole form hostage to it is how a seller loses their typing.
  ///
  /// A new listing has nothing to upload to yet, so its photos ride along
  /// with the form.
  Future<void> _onPhotos(List<Shot> next) async {
    final id = widget.existing?.serverId;
    if (id == null) {
      setState(() => _shots = next);
      return;
    }
    setState(() {
      _shots = next;
      _savingPhotos = true;
    });
    try {
      // Upload the new ones first, so the order can then be sent as a single
      // list of URLs that the server already knows about.
      var urls = [
        for (final s in next)
          if (!s.isNew) s.url!,
      ];
      final fresh = [
        for (final s in next)
          if (s.isNew) s.bytes!,
      ];
      if (fresh.isNotEmpty) {
        final after = await Api.instance.addItemPhotos(id, fresh);
        // The server appends, so whatever is new to it is what we just sent,
        // in the order we sent it.
        urls = [...urls, ...after.where((u) => !urls.contains(u))];
      }
      final saved = await Api.instance.setItemPhotos(id, urls);
      widget.existing!.imageUrls = saved;
      if (mounted) {
        setState(() => _shots = [for (final u in saved) Shot.remote(u)]);
      }
    } catch (e) {
      logApiFailure('item photos', e);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('ClientException: ', '')),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
    if (mounted) setState(() => _savingPhotos = false);
  }

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
                        '₹${(mrp - price).moneyText} saved.',
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
          photos: _newPhotos,
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
        ..photos = _newPhotos;
      Seller.instance.itemChanged(item);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final categories = _categoryOptions;
    final sections = _categorySections;
    return Scaffold(
      backgroundColor: LamazonTheme.canvas,
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
                      title: 'Photos (${_shots.length})',
                      hint:
                          'Use clear, well-lit photos of the actual product. Keep it fully visible. Drag to reorder; the first photo is the cover.',
                    ),
                    PhotoManager(
                      shots: _shots,
                      busy: _savingPhotos,
                      onChanged: _onPhotos,
                    ),
                    const SizedBox(height: 22),
                    const SellerSection(title: 'Title'),
                    SellerField(
                      controller: _title,
                      icon: LucideIcons.tag,
                      hint: 'e.g. Cold Coffee 300ml',
                      onChanged: () => setState(() {}),
                    ),
                    // Above the rest because it decides the rest: the options
                    // a food stall is offered are not the ones a phone shop is.
                    if (categories.length > 1) ...[
                      const SizedBox(height: 22),
                      const SellerSection(title: 'Category'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in sections.keys)
                            SellerChoice(
                              label: s,
                              selected: _section == s,
                              onTap: () => setState(() {
                                _section = s;
                                _category = sections[s]!.first;
                              }),
                            ),
                        ],
                      ),
                      // A section holding only itself has nothing to narrow to.
                      if ((sections[_section] ?? const []).length > 1) ...[
                        const SizedBox(height: 12),
                        SellerSection(title: _section),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final c in sections[_section]!)
                              SellerChoice(
                                label: c,
                                selected: _category == c,
                                onTap: () => setState(() => _category = c),
                              ),
                          ],
                        ),
                      ],
                    ],
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
                          ? 'Only if buyers have to choose — '
                                '${_presetHint(_category)}…'
                          : 'Buyers pick one of each before ordering',
                    ),
                    _OptionsEditor(
                      options: _options,
                      presets: presetsFor(departmentOf(_category)),
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
///
/// Offered by department, because "Size" means S–XL to one shop and 30ml to
/// another, and a thali seller has no use for a storage chip. Anything not
/// listed here falls back to [_anyPresets]; the seller can still name their
/// own, so a wrong guess costs a tap, not the option.
const _colourOption = ItemOption(
  name: 'Colour',
  kind: 'colour',
  values: ['#1A1A1A', '#FFFFFF', '#D32F2F', '#2F6FED'],
);

const _presetsByDepartment = <String, List<ItemOption>>{
  'Food': [
    ItemOption(name: 'Portion', values: ['Half', 'Full']),
    ItemOption(name: 'Spice', values: ['Mild', 'Medium', 'Hot']),
    ItemOption(name: 'Serves', values: ['1', '2', '4']),
  ],
  'Grocery': [
    ItemOption(name: 'Weight', values: ['250g', '500g', '1kg', '5kg']),
    ItemOption(name: 'Pack', values: ['Pack of 1', 'Pack of 2', 'Pack of 6']),
  ],
  'Snacks & Drinks': [
    ItemOption(name: 'Size', values: ['250ml', '500ml', '1L']),
    ItemOption(name: 'Pack', values: ['Pack of 1', 'Pack of 4', 'Pack of 12']),
  ],
  'Electronics': [
    _colourOption,
    ItemOption(name: 'Storage', values: ['64GB', '128GB', '256GB']),
    ItemOption(name: 'Warranty', values: ['6 months', '1 year', '2 years']),
  ],
  'Beauty': [
    ItemOption(name: 'Shade', kind: 'colour', values: ['#D7CCC8', '#6D4C41']),
    ItemOption(name: 'Size', values: ['30ml', '50ml', '100ml']),
  ],
  'Household Essentials': [
    ItemOption(name: 'Size', values: ['500ml', '1L', '5L']),
    ItemOption(name: 'Pack', values: ['Pack of 1', 'Pack of 2', 'Pack of 6']),
  ],
  'Gifts': [
    _colourOption,
    ItemOption(name: 'Size', values: ['Small', 'Medium', 'Large']),
  ],
};

const _anyPresets = <ItemOption>[
  ItemOption(name: 'Size', values: ['S', 'M', 'L', 'XL']),
  _colourOption,
  ItemOption(name: 'Weight', values: ['250g', '500g', '1kg']),
];

List<ItemOption> presetsFor(String department) =>
    _presetsByDepartment[department] ?? _anyPresets;

/// The first two presets, named in the hint, so the example matches what the
/// chips below actually offer.
String _presetHint(String category) => presetsFor(
  departmentOf(category),
).take(2).map((p) => p.name.toLowerCase()).join(', ');

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
  0xFF000000 | (int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0),
);

/// The option groups on a listing, and the two taps that add one. Mutates the
/// list it is given — the screen owns it and saves it, this only edits.
class _OptionsEditor extends StatelessWidget {
  final List<ItemOption> options;
  final List<ItemOption> presets;
  final VoidCallback onChanged;
  const _OptionsEditor({
    required this.options,
    required this.presets,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final unused = presets
        .where((p) => !options.any((o) => o.name == p.name))
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
            for (final preset in unused)
              _AddChip(
                label: '+ ${preset.name}',
                onTap: () {
                  options.add(preset);
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
                  onRemove: () =>
                      widget.onValues([...option.values]..remove(value)),
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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
        color: LamazonTheme.canvas,
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
    // Fields the shopper's table actually ranks, that this listing has not
    // answered. A field with no mode is displayed rather than ranked, so
    // leaving it blank costs the seller nothing and is not nagged about.
    final unwinnable = [
      for (final f in template)
        if (f.ranked && (values[f.name] ?? '').trim().isEmpty) f.name,
    ];
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
                // A ranked field left blank is a row this product cannot win —
                // the shopper sees a dash while a rival shows a number. Worth
                // saying plainly here, where it takes ten seconds to fix,
                // rather than never. Only the ranked ones: leaving Flavour
                // blank costs nothing, because nobody wins Flavour.
                if (unwinnable.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        LucideIcons.circleAlert,
                        size: 14,
                        color: Color(0xFFB4531F),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          unwinnable.length == 1
                              ? 'Fill in ${unwinnable.first} — buyers rank on '
                                    'it, and a blank never wins.'
                              : 'Fill in ${unwinnable.join(', ')} — buyers '
                                    'rank on these, and a blank never wins.',
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: Color(0xFFB4531F),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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

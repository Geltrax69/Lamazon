import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/categories.dart';
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
  late String _category =
      widget.existing?.category ??
      (Seller.instance.store?.categories.first ?? _options.first);

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
  List<String> get _options {
    final mine = Seller.instance.store?.categories ?? const <String>[];
    final out = [for (final d in mine) ...sellableCategories(d)];
    return out.isEmpty ? sellableCategories() : out;
  }

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

  void _save() {
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
        ..stock = _stockValue!
        ..photos = _photos;
      Seller.instance.itemChanged(item);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final categories = _options;
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
                onSubmit: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

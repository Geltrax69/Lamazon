import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/seller.dart';
import '../widgets/photo_picker.dart';
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
  late final _stock = TextEditingController(
    text: widget.existing?.stock.toString(),
  );
  late List<Uint8List> _photos = [...?widget.existing?.photos];
  late String _category =
      widget.existing?.category ??
      (Seller.instance.store?.categories.first ?? sellCategories.first);

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  double? get _priceValue => double.tryParse(_price.text.trim());
  int? get _stockValue => int.tryParse(_stock.text.trim());

  String? get _blocker {
    if (_photos.isEmpty) return 'Add at least one photo';
    if (_title.text.trim().isEmpty) return 'Give the product a title';
    if ((_priceValue ?? 0) <= 0) return 'Set a price above ₹0';
    if ((_stockValue ?? -1) < 0) return 'Enter how many units you have';
    return null;
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
        ..stock = _stockValue!
        ..photos = _photos;
      Seller.instance.itemChanged();
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final categories = Seller.instance.store?.categories ?? const <String>[];
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
                      title: 'Photos (${_photos.length})',
                      hint: 'Add as many as you like — the first is the cover',
                    ),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SellerSection(title: 'Price'),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SellerSection(title: 'Stock'),
                              SellerField(
                                controller: _stock,
                                icon: LucideIcons.boxes,
                                hint: 'units',
                                keyboard: TextInputType.number,
                                onChanged: () => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                      ],
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

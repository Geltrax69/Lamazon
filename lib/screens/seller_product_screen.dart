import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/seller.dart';
import '../widgets/product_card.dart';
import '../widgets/screen_header.dart';
import 'seller_onboarding_screen.dart';

const _ink = Color(0xFF1A1A1A);
const _green = Color(0xFF2E7D32);

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
  late final _price =
      TextEditingController(text: widget.existing?.price.toStringAsFixed(0));
  late final _stock =
      TextEditingController(text: widget.existing?.stock.toString());
  late final _image = TextEditingController(text: widget.existing?.imageUrl);
  late String _category = widget.existing?.category ??
      (Seller.instance.store?.categories.first ?? sellCategories.first);

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    _stock.dispose();
    _image.dispose();
    super.dispose();
  }

  double? get _priceValue => double.tryParse(_price.text.trim());
  int? get _stockValue => int.tryParse(_stock.text.trim());

  bool get _complete =>
      _title.text.trim().isNotEmpty &&
      (_priceValue ?? 0) > 0 &&
      (_stockValue ?? -1) >= 0;

  void _save() {
    final item = widget.existing;
    if (item == null) {
      Seller.instance.addItem(InventoryItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: _title.text.trim(),
        description: _desc.text.trim(),
        category: _category,
        price: _priceValue!,
        stock: _stockValue!,
        imageUrl: _image.text.trim().isEmpty
            ? _placeholder
            : _image.text.trim(),
      ));
    } else {
      item
        ..title = _title.text.trim()
        ..description = _desc.text.trim()
        ..category = _category
        ..price = _priceValue!
        ..stock = _stockValue!
        ..imageUrl =
            _image.text.trim().isEmpty ? _placeholder : _image.text.trim();
      Seller.instance.itemChanged();
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final image = _image.text.trim();
    final categories =
        Seller.instance.store?.categories ?? const <String>[];
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(title: editing ? 'Edit product' : 'Add product'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  const SellerLabel('Product image'),
                  SellerField(
                    controller: _image,
                    icon: LucideIcons.image,
                    hint: 'Paste an image link (optional)',
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: NetImage(
                          url: image.isEmpty ? _placeholder : image),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SellerLabel('Title'),
                  SellerField(
                    controller: _title,
                    icon: LucideIcons.tag,
                    hint: 'e.g. Cold Coffee 300ml',
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  const SellerLabel('Description'),
                  SellerField(
                    controller: _desc,
                    icon: LucideIcons.alignLeft,
                    hint: 'What the buyer gets',
                    maxLines: 3,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SellerLabel('Price (₹)'),
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
                            const SellerLabel('Stock (units)'),
                            SellerField(
                              controller: _stock,
                              icon: LucideIcons.boxes,
                              hint: '0',
                              keyboard: TextInputType.number,
                              onChanged: () => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (categories.length > 1) ...[
                    const SizedBox(height: 16),
                    const SellerLabel('Category'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in categories)
                          GestureDetector(
                            onTap: () => setState(() => _category = c),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: _category == c ? _ink : Colors.white,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Text(c,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _category == c
                                        ? Colors.white
                                        : _ink,
                                  )),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if ((_stockValue ?? 1) == 0) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Saved with 0 units it shows as Sold out to buyers.',
                      style:
                          TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    disabledBackgroundColor: const Color(0xFFDDDDD9),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: _complete ? _save : null,
                  child: Text(editing ? 'Save changes' : 'Add to inventory',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _placeholder =
    'https://images.unsplash.com/photo-1553456558-aff63285bdd1?w=600';

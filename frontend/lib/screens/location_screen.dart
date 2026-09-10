import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/addresses.dart';
import '../widgets/design_system.dart';
import '../widgets/screen_header.dart';

// The system's own tokens, not three neutrals of this screen's invention.
// #1A1A1A / #2E7D32 / #D32F2F were a cool ink and two stock Material greens
// in an app whose palette is warm.
const _ink = LamazonTheme.text;
const _green = LamazonTheme.strong;
const _red = LamazonTheme.danger;

/// Enter a delivery location manually, check whether porters cover it, and
/// save it under Home / Office / Other.
class LocationScreen extends StatefulWidget {
  /// Pre-filled when we arrive from a confirmed device location: the city is
  /// already known, so only the parts GPS cannot tell us are left to type.
  final String? city;
  final Address? address;
  const LocationScreen({super.key, this.city, this.address});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  @override
  void initState() {
    super.initState();
    final address = widget.address;
    if (address != null) {
      _name.text = address.name;
      _phone.text = address.phone;
      _line.text = address.line;
      _city.text = address.city;
      _label = address.label;
      _touched = true;
    }
    if (widget.city != null) _city.text = widget.city!;
  }

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _line = TextEditingController();
  // We deliver to one campus, so the city is chosen rather than typed: a
  // field whose only right answer is already known is a field that can only
  // be got wrong. The pincode went with it — nothing uses it, and a porter
  // walking to a hostel block has never needed one.
  final _city = TextEditingController(text: serviceableCities.first);
  AddressLabel _label = AddressLabel.home;
  bool _touched = false;
  bool _saving = false;

  /// What is still missing, or null when the form is ready. One message at a
  /// time, in the order the fields are read.
  String? get _problem {
    if (_name.text.trim().isEmpty) return 'Enter the recipient name.';
    if (!RegExp(r'^(?:\+91[ -]?)?[6-9][0-9]{9}$').hasMatch(_phone.text.trim())) {
      return 'Enter a valid 10-digit Indian mobile number.';
    }
    if (_line.text.trim().isEmpty) {
      return 'Enter the hostel and room, or block and shop.';
    }
    if (!_serviceable) {
      return 'We do not deliver to ${_city.text.trim()} yet.';
    }
    return null;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _line.dispose();
    _city.dispose();
    super.dispose();
  }

  bool get _serviceable => isServiceable(_city.text);

  /// A porter needs someone to hand the bag to and a number to call, so the
  /// two are required rather than optional extras. One source of truth: the
  /// button and the message under it used to test the same fields twice, in
  /// two different orders.
  bool get _complete => _problem == null;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final a = Address(
      // A placeholder only until the server answers with the real one.
      id: widget.address?.id ?? '',
      label: _label,
      line: _line.text.trim(),
      city: _city.text.trim(),
      // Nothing asks for one any more; the column stays for the rows that
      // already have it.
      pincode: '',
      name: _name.text.trim(),
      phone: _phone.text.trim(),
    );
    try {
      if (widget.address == null) {
        await AddressBook.instance.add(a);
      } else {
        await AddressBook.instance.edit(a);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('ClientException: ', '')),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Delivering to ${a.label.title} • ${a.city}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LamazonTheme.canvas,
      body: ReadableBody(
        maxWidth: 620,
        child: SafeArea(
          child: Column(
            children: [
              // ScreenHeader, so the back button lands where it does on
              // every other screen and is a real focusable button. And the
              // title names the thing being made: this form's first field is
              // "Full name", which "Enter Location" never explained.
              ScreenHeader(
                title: widget.address == null
                    ? 'Add delivery address'
                    : 'Edit delivery address',
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  children: [
                    _Field(
                      controller: _name,
                      hint: 'Full name',
                      icon: LucideIcons.user,
                      onChanged: (_) => setState(() => _touched = true),
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _phone,
                      hint: 'Mobile number',
                      icon: LucideIcons.phone,
                      keyboardType: TextInputType.phone,
                      onChanged: (_) => setState(() => _touched = true),
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _line,
                      hint: 'Hostel and room, or block and shop',
                      icon: LucideIcons.house,
                      onChanged: (_) => setState(() => _touched = true),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Save as',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // One of three, so it is announced as a radio group
                    // rather than three unrelated checkboxes — and every
                    // chip is reachable with Tab and takes Enter or Space.
                    Semantics(
                      container: true,
                      label: 'Save as',
                      child: Row(
                        children: [
                          for (final l in AddressLabel.values) ...[
                            _LabelChip(
                              label: l,
                              selected: _label == l,
                              onTap: () => setState(() => _label = l),
                            ),
                            const SizedBox(width: 10),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Serviceability result. Shown from the start rather
                    // than behind a press: the city is chosen from a list, so
                    // the answer is known the moment the screen opens.
                    if (_city.text.trim().isNotEmpty)
                      _serviceable
                          ? const _Banner(
                              icon: LucideIcons.circleCheck,
                              color: _green,
                              background: Color(0xFFE8F5E9),
                              title: 'We deliver here',
                              body: 'Porters reach this area in about 12 mins.',
                            )
                          : _Banner(
                              icon: LucideIcons.circleAlert,
                              color: _red,
                              background: const Color(0xFFFDECEA),
                              title: 'Not available in your location',
                              body:
                                  'We do not deliver to ${_city.text.trim()} yet. '
                                  'We currently serve '
                                  '${serviceableCities.join(", ")}.',
                            ),
                    if (_city.text.trim().isNotEmpty)
                      const SizedBox(height: 16),
                    const Text(
                      'Where we deliver',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in serviceableCities)
                          ChoiceChip(
                            label: Text(c),
                            selected: _city.text.trim() == c,
                            onSelected: (_) =>
                                setState(() => _city.text = c),
                            showCheckmark: false,
                            backgroundColor: LamazonTheme.surface,
                            selectedColor: LamazonTheme.lime,
                            side: const BorderSide(
                              color: LamazonTheme.track,
                            ),
                            labelStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Only after the person has typed something. It used to greet
              // an untouched form with "Enter the recipient name.", which
              // reads as an accusation before any input.
              if (_touched && _problem != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.circleAlert,
                          size: 15,
                          color: _red,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _problem!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // One button, not two. The serviceability check runs off the
              // city selection above — there is exactly one serviceable city,
              // so gating submit behind a separate press bought nothing and
              // cost every person a tap.
              //
              // ActionButton, not a GestureDetector: the old control had no
              // role and no tabindex, so it could not be focused or activated
              // from a keyboard, and a delivery address is required to order.
              // That closed the whole purchase funnel to keyboard users.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: ActionButton(
                  label: _saving ? 'Saving…' : 'Save address',
                  expand: true,
                  onPressed: _saving || !_complete ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: LamazonTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Decorative: the field's own label is what names it, so the icon
          // must not add a second announcement.
          ExcludeSemantics(child: Icon(icon, size: 18, color: LamazonTheme.muted)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              onChanged: onChanged,
              decoration: InputDecoration(
                // labelText only. Setting hintText to the same string printed
                // the label twice, stacked, the moment the field took focus.
                labelText: hint,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: LamazonTheme.strong, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  final AddressLabel label;
  final bool selected;
  final VoidCallback onTap;
  const _LabelChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  IconData get _icon => switch (label) {
    AddressLabel.home => LucideIcons.house,
    AddressLabel.office => LucideIcons.briefcase,
    AddressLabel.other => LucideIcons.mapPin,
  };

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : _ink;
    // inMutuallyExclusiveGroup makes this a radio option rather than a
    // checkbox, and InkWell is what puts it in the tab order at all — as a
    // GestureDetector it had no role and could not be reached or activated
    // without a pointer.
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: label.title,
      child: Material(
        color: selected ? _ink : LamazonTheme.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: LamazonTheme.touch),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icon, size: 15, color: foreground),
                  const SizedBox(width: 6),
                  ExcludeSemantics(
                    child: Text(
                      label.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String body;

  const _Banner({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(fontSize: 12, height: 1.4, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

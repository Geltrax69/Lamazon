import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/addresses.dart';
import '../widgets/design_system.dart';
import '../widgets/screen_header.dart';
import 'location_screen.dart';

// The system's ink, not this screen's. #1A1A1A and #6B6B6B are cool neutrals
// in a warm palette, and between them accounted for 62 of the app's off-system
// colour uses.
const _ink = LamazonTheme.text;

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  static IconData iconFor(AddressLabel l) => switch (l) {
    AddressLabel.home => LucideIcons.house,
    AddressLabel.office => LucideIcons.briefcase,
    AddressLabel.other => LucideIcons.mapPin,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LamazonTheme.canvas,
      body: ReadableBody(
        maxWidth: 620,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: AddressBook.instance,
            builder: (context, _) {
              final list = AddressBook.instance.addresses;
              final selected = AddressBook.instance.selected;
              return Column(
                children: [
                  // The same header every other sub-screen uses: a real,
                  // focusable back button in the one place users look for it.
                  // "Delivery addresses" rather than "Saved Addresses" —
                  // the app called this one thing three different names.
                  const ScreenHeader(title: 'Delivery addresses'),
                  Expanded(
                    child: list.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.mapPinOff,
                                  size: 44,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No saved addresses',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: LamazonTheme.muted,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                            itemCount: list.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) {
                              final a = list[i];
                              final isSelected = a.id == selected?.id;
                              return _SelectableCard(
                                selected: isSelected,
                                label: '${a.label.title}, ${a.full}',
                                onTap: () => _change(
                                  context,
                                  () => AddressBook.instance.select(a.id),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: isSelected
                                        ? Border.all(color: _ink, width: 1.5)
                                        : null,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: const BoxDecoration(
                                          color: LamazonTheme.canvas,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          iconFor(a.label),
                                          size: 18,
                                          color: _ink,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  a.label.title,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                if (isSelected) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 3,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: _ink,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      'DELIVERING HERE',
                                                      style: TextStyle(
                                                        fontSize: 8,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              [a.name, a.phone, a.full]
                                                  .where((v) => v.isNotEmpty)
                                                  .join(' · '),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                height: 1.4,
                                                color: LamazonTheme.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Edit address',
                                        icon: const Icon(
                                          LucideIcons.pencil,
                                          size: 16,
                                        ),
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                LocationScreen(address: a),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete address',
                                        icon: const Icon(
                                          LucideIcons.trash2,
                                          size: 16,
                                          color: LamazonTheme.muted,
                                        ),
                                        onPressed: () => _delete(context, a),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    // ActionButton: the old control had role=button but no
                    // tabindex, so the primary action of this screen could
                    // not be reached from a keyboard at all.
                    child: ActionButton(
                      label: 'Add new address',
                      icon: LucideIcons.plus,
                      expand: true,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LocationScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

Future<void> _change(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('ClientException: ', '')),
        ),
      );
    }
  }
}

Future<void> _delete(BuildContext context, Address address) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Delete address?'),
      content: Text(address.full),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: const Text('Keep'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await _change(context, () => AddressBook.instance.remove(address.id));
  }
}

/// One address in the list. A radio option, not a plain tappable box: exactly
/// one of them is the delivery address at any time, and as a GestureDetector
/// none of them were focusable or announced as choosable.
class _SelectableCard extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;
  final Widget child;
  const _SelectableCard({
    required this.selected,
    required this.label,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    inMutuallyExclusiveGroup: true,
    selected: selected,
    label: label,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: child),
    ),
  );
}

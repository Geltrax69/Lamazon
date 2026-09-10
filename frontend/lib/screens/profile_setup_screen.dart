import 'package:flutter/material.dart';
import '../widgets/design_system.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/addresses.dart';
import '../data/api.dart';
import '../data/session.dart';
import '../widgets/app_shell.dart';
import '../widgets/screen_header.dart';
import '../widgets/seller_form.dart';

const _muted = LamazonTheme.muted;
const _ink = LamazonTheme.text;

/// Asked once, right after the first sign-in: who you are, how to reach you,
/// and where to bring things. Everything an order needs and nothing else — a
/// form asked at this moment is a form people abandon.
///
/// The password is optional and set here rather than at sign-in, because the
/// code already proved the address. Setting one is what lets them skip the
/// inbox next time.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final _name = TextEditingController(text: Session.instance.name);
  late final _phone = TextEditingController(text: Session.instance.phone);
  final _password = TextEditingController();
  final _line = TextEditingController();
  AddressLabel _label = AddressLabel.home;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    _line.dispose();
    super.dispose();
  }

  /// The city is not asked for. We deliver to one campus, so a field whose
  /// only right answer is already known is a field that can only be got
  /// wrong. Same for the pincode.
  String get _city => serviceableCities.first;

  String? get _blocker {
    if (_name.text.trim().isEmpty) return 'Add your name';
    if (_phone.text.trim().length < 7) return 'Add a mobile number';
    if (_password.text.isNotEmpty && _password.text.length < 8) {
      return 'A password needs at least 8 characters';
    }
    if (_line.text.trim().isEmpty) return 'Add where we deliver to you';
    return null;
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.instance.updateMe(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text.isEmpty ? null : _password.text,
      );
      await AddressBook.instance.add(
        Address(
          id: '',
          label: _label,
          line: _line.text.trim(),
          city: _city,
          pincode: '',
          name: _name.text.trim(),
          phone: _phone.text.trim(),
        ),
      );
      // Re-read rather than assume: the server is what decides whether this
      // account is set up, and the app should agree with it.
      await Session.instance.refreshProfile();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      logApiFailure('profile setup', e);
      if (mounted) {
        setState(
          () => _error = e.toString().replaceFirst('ClientException: ', ''),
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LamazonTheme.canvas,
      body: ReadableBody(
        maxWidth: 560,
        child: SafeArea(
          child: Column(
            children: [
              const ScreenHeader(title: 'Your details'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    const Text(
                      'We ask once, so an order knows who it is for and where '
                      'it is going.',
                      style: TextStyle(fontSize: 13.5, color: _muted),
                    ),
                    const SizedBox(height: 22),
                    const SellerSection(title: 'Name'),
                    SellerField(
                      controller: _name,
                      icon: LucideIcons.user,
                      hint: 'Full name',
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 22),
                    const SellerSection(title: 'Mobile number'),
                    SellerField(
                      controller: _phone,
                      icon: LucideIcons.phone,
                      hint: 'So the rider can call you',
                      keyboard: TextInputType.phone,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 22),
                    const SellerSection(
                      title: 'Password',
                      hint: 'Optional — set one to skip the emailed code',
                    ),
                    SellerField(
                      controller: _password,
                      icon: LucideIcons.lock,
                      hint: 'At least 8 characters',
                      obscure: true,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 22),
                    const SellerSection(
                      title: 'Address',
                      hint: 'Hostel and room, or block and shop',
                    ),
                    SellerField(
                      controller: _line,
                      icon: LucideIcons.house,
                      hint: 'e.g. Hostel BH-9, Room 214',
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 22),
                    const SellerSection(title: 'Save as'),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final label in AddressLabel.values)
                          SellerChoice(
                            label: label.title,
                            selected: _label == label,
                            onTap: () => setState(() => _label = label),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const SellerSection(title: 'Where we deliver'),
                    // One campus, already chosen. Shown rather than asked,
                    // so nobody types a city we cannot reach.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.circleCheckBig,
                            size: 16,
                            color: Color(0xFF1B7F3B),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _city,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: LamazonTheme.danger,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SellerSubmitBar(
                label: _busy ? 'Saving…' : 'Save and continue',
                blocker: _blocker,
                onSubmit: _busy ? () {} : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

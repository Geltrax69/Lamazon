import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../widgets/app_shell.dart';
import '../widgets/screen_header.dart';

const _ink = Color(0xFF1A1A1A);
const _muted = Color(0xFF6B6B6B);

/// The written policies, one screen per document.
///
/// The text is a first draft, not legal advice: it says what Lamazon actually
/// does today so the pages are true as far as they go, and it is written to be
/// replaced. Anything a real policy needs and this cannot know — the company
/// name behind the shop, its registered address, a GST number — is marked
/// rather than invented, because a made-up registration on a live policy page
/// is worse than an obvious blank.
enum Policy {
  terms('Terms and Conditions', LucideIcons.fileText, _terms),
  privacy('Privacy Policy', LucideIcons.shieldCheck, _privacy),
  shipping('Shipping Policy', LucideIcons.truck, _shipping),
  refunds('Cancellation and Refunds', LucideIcons.receipt, _refunds),
  contact('Contact Us', LucideIcons.mail, _contact);

  final String title;
  final IconData icon;
  final List<(String, String)> sections;
  const Policy(this.title, this.icon, this.sections);
}

class PolicyScreen extends StatelessWidget {
  final Policy policy;
  const PolicyScreen({super.key, required this.policy});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1EF),
      body: ReadableBody(
        maxWidth: 700,
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: policy.title),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  children: [
                    const Text(
                      'Last updated August 2026. We will post any change here '
                      'before it takes effect.',
                      style: TextStyle(fontSize: 12.5, color: _muted),
                    ),
                    const SizedBox(height: 20),
                    for (final (heading, body) in policy.sections) ...[
                      Text(
                        heading,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.55,
                          color: Color(0xFF3A3A3A),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The list of all five, for a settings or help screen to render.
class PolicyLinks extends StatelessWidget {
  const PolicyLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, policy) in Policy.values.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            ListTile(
              leading: Icon(policy.icon, size: 19, color: _ink),
              title: Text(
                policy.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: const Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: _muted,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PolicyScreen(policy: policy)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const _terms = <(String, String)>[
  (
    'Who we are',
    'Lamazon is a campus marketplace. Shops on campus list what they sell, '
        'students and staff order it, and a delivery partner brings it '
        'across. We run the platform; we do not make or own the goods.\n\n'
        '[Replace with the registered business name and address behind '
        'Lamazon.]',
  ),
  (
    'Your account',
    'You sign in with your email address, and we send a code to it to prove '
        'it is yours. Keep your account to yourself — anything ordered from '
        'it is treated as ordered by you. Tell us straight away if you think '
        'somebody else has got into it.',
  ),
  (
    'Orders',
    'Placing an order is an offer to buy. It becomes a sale when the shop '
        'accepts it, which is also the moment your delivery code is issued. '
        'A shop can turn an order down — usually because they have run out — '
        'and you are told why.',
  ),
  (
    'Prices',
    'Shops set their own prices and their own MRP. Where a discount is shown, '
        'it is the difference between the two as the shop entered them. '
        'Prices include taxes unless a shop says otherwise.',
  ),
  (
    'Selling on Lamazon',
    'Anyone on campus can open a store, and an admin reviews it before it is '
        'visible to shoppers. You are responsible for what you list: that it '
        'is yours to sell, that it is described honestly, and that it is safe '
        'to eat, use or wear. We can take a listing or a store down if it is '
        'not.',
  ),
  (
    'What we are not responsible for',
    'The quality of what a shop sells is the shop’s. We will help you '
        'sort out a problem, but the contract for the goods is between you '
        'and them. Nothing here limits rights you have under consumer law '
        'that cannot be signed away.',
  ),
  (
    'Changes',
    'We may update these terms. If a change matters to how you use Lamazon, '
        'we will say so in the app before it takes effect.',
  ),
];

const _privacy = <(String, String)>[
  (
    'What we collect',
    'Your email address, and the name and mobile number you give us so an '
        'order can reach you. Your delivery addresses. What you have ordered. '
        'If you open a store: its name, location, photo and what you list.',
  ),
  (
    'Why we collect it',
    'To deliver your orders and to let the shop and the rider do their part. '
        'Your name and number go to the shop that is packing your order and '
        'the rider carrying it, because neither can hand it over without '
        'them. Nothing else about you goes with it.',
  ),
  (
    'The four digits at the door',
    'Every delivery has a code. It is shown only to you and checked only by '
        'the rider at hand-over — they are never told what it is, which is '
        'what makes typing it proof that the two of you met.',
  ),
  (
    'Emails and notifications',
    'We email you sign-in codes and order updates. If you turn on '
        'notifications we also send those to your browser or phone; you can '
        'turn them off again in Settings and email carries on either way.',
  ),
  (
    'Photos',
    'Store and product photos you upload are stored with our image host and '
        'served publicly as part of your listing. Do not upload anything you '
        'would not want a shopper to see.',
  ),
  (
    'How long we keep it',
    'Your account and order history stay while your account exists. Sign-in '
        'codes are deleted the moment they are used or expire. Ask us to '
        'delete your account and we will remove your personal details; '
        'records a shop needs for its own accounts may remain with them.',
  ),
  (
    'Who else sees it',
    'The shop you ordered from, the rider delivering it, and the services we '
        'use to send email, store photos and deliver notifications. We do not '
        'sell your data to anybody.\n\n'
        '[Replace with the list of processors once these are settled.]',
  ),
];

const _shipping = <(String, String)>[
  (
    'Where we deliver',
    'Lovely Professional University and the area immediately around it. If '
        'an address outside that is entered, the app says so rather than '
        'taking an order nobody can fulfil.',
  ),
  (
    'How long it takes',
    'Most orders arrive in about 12 minutes once a shop accepts them. Busy '
        'evenings and exam weeks are slower. Food is prepared after the shop '
        'accepts, so a hot order takes as long as it takes to cook.',
  ),
  (
    'Delivery charge',
    '₹15 per order, shown in the basket before you pay, whatever the '
        'size of the order.',
  ),
  (
    'Receiving your order',
    'The rider calls the number on the order. Have your four-digit code '
        'ready — the order is only closed when it is entered, which is how we '
        'know it reached you and not somebody else.',
  ),
  (
    'If nobody is there',
    'The rider will call and wait a few minutes. If they cannot reach you, '
        'the order comes back to the shop and we will contact you about it. '
        'Prepared food cannot be redelivered.',
  ),
];

const _refunds = <(String, String)>[
  (
    'Cancelling',
    'You can cancel free of charge until the shop accepts your order. After '
        'that, food is already being prepared and the order cannot be '
        'cancelled. For anything not prepared to order, message us before the '
        'rider collects it and we will do what we can.',
  ),
  (
    'If a shop cannot fulfil it',
    'A shop can reject an order — usually because something has run out — '
        'and you are told the reason. You are not charged for a rejected '
        'order, and anything already taken is refunded in full.',
  ),
  (
    'Something wrong with your order',
    'Missing items, the wrong item, or food that arrived in no state to eat: '
        'tell us within 24 hours, with a photo if you can. We will refund the '
        'item, arrange a replacement, or credit your account, whichever suits '
        'you.',
  ),
  (
    'How refunds are paid',
    'Back to the way you paid. Bank refunds usually take 3–7 working '
        'days to appear, which is your bank’s timing rather than ours.\n\n'
        '[Replace once online payment is live — orders are cash on delivery '
        'today, and those are settled in cash.]',
  ),
  (
    'Repeated claims',
    'We look at claims one by one. An account claiming refunds constantly may '
        'be asked for more before we settle another one.',
  ),
];

const _contact = <(String, String)>[
  (
    'Support',
    'support@lamazon.in — the fastest way to reach us. Quote the order number '
        'shown on the order (for example ORDER-12) and your customer id from '
        'your account page (for example LMZ-1042); with those two we can find '
        'anything.',
  ),
  (
    'When we answer',
    'Every day, 9am to 11pm. Most emails are answered the same day; anything '
        'that arrives after 11pm is picked up the next morning.',
  ),
  (
    'Selling on Lamazon',
    'sellers@lamazon.in for opening a store, getting one approved, or a '
        'problem with an order you are packing.',
  ),
  (
    'Something urgent with a delivery',
    'The rider calls from the number on your order, and that is the quickest '
        'line while a delivery is in flight. If you cannot reach them, email '
        'support and put the order number in the subject.',
  ),
  (
    'Address',
    '[Replace with the registered address for the business behind Lamazon.]',
  ),
];

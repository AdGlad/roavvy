import 'package:flutter/material.dart';

import 'terms_service.dart';

/// Displays the Roavvy Terms & Conditions.
///
/// Two modes:
/// - [requireAccept] = true  — shows checkbox + "Accept & Continue" button.
///   Used during onboarding. Returns `true` via `Navigator.pop` when accepted.
/// - [requireAccept] = false — read-only view with a single Close button.
///   Used from the Settings screen.
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key, this.requireAccept = false});

  final bool requireAccept;

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _accepted = false;
  bool _saving = false;

  Future<void> _onAccept() async {
    if (!_accepted || _saving) return;
    setState(() => _saving = true);
    await TermsService.acceptCurrent();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: _TermsContent(theme: theme),
            ),
          ),
          const Divider(height: 1),
          if (widget.requireAccept) ...[
            _AcceptanceRow(
              accepted: _accepted,
              onChanged: (v) => setState(() => _accepted = v ?? false),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: FilledButton(
                onPressed: (_accepted && !_saving) ? _onAccept : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Accept & Continue'),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
        ],
      ),
    );
  }
}

class _AcceptanceRow extends StatelessWidget {
  const _AcceptanceRow({required this.accepted, required this.onChanged});

  final bool accepted;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(value: accepted, onChanged: onChanged),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'I have read and agree to the Terms & Conditions',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Terms content ─────────────────────────────────────────────────────────────

class _TermsContent extends StatelessWidget {
  const _TermsContent({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _version(),
        _h1('Roavvy — Terms & Conditions'),
        _p(
          'Please read these Terms & Conditions ("Terms") carefully before using '
          'the Roavvy mobile application or website (together, the "Platform"). '
          'By creating an account or using the Platform you agree to be bound by these Terms.',
        ),
        _p(
          'Roavvy is operated by [Roavvy Pty Ltd] (ABN [XX XXX XXX XXX]), '
          'a company incorporated in New South Wales, Australia '
          '("Roavvy", "we", "us", or "our"). '
          'Questions: [support@roavvy.app].',
        ),

        // 1. Eligibility
        _h2('1. Eligibility'),
        _p(
          'You must be at least 13 years old to use Roavvy. If you are under 18 '
          'you must have the consent of a parent or legal guardian. By using the '
          'Platform you represent that you meet these requirements.',
        ),

        // 2. Accounts
        _h2('2. Accounts'),
        _p(
          'You may register using email/password, Apple Sign-In, Google Sign-In, '
          'or continue anonymously. You are responsible for maintaining the '
          'confidentiality of your credentials and for all activity that occurs '
          'under your account.',
        ),
        _p(
          'You must provide accurate information and keep it up to date. You may '
          'not create accounts on behalf of others without authorisation, or '
          'operate multiple accounts to circumvent restrictions.',
        ),
        _p(
          'We reserve the right to suspend or terminate accounts that violate '
          'these Terms, engage in fraud or abuse, or are otherwise used in a '
          'manner we consider harmful.',
        ),

        // 3. On-device photo scanning
        _h2('3. On-Device Photo Scanning'),
        _p(
          'Roavvy scans your photo library locally on your device to infer '
          'countries you have visited, using GPS coordinates and timestamps '
          'embedded in your photos. Your photos are never uploaded to our '
          'servers.',
        ),
        _p(
          'Only derived metadata — such as country codes, visit timestamps, and '
          'trip summaries — may be stored on our servers. You can delete this '
          'data at any time via Settings → Privacy & Account → Delete account.',
        ),

        // 4. User content
        _h2('4. User Content'),
        _p(
          'You retain ownership of any content you upload to the Platform '
          '("User Content"). By uploading User Content you grant Roavvy a '
          'worldwide, royalty-free, non-exclusive licence to use, store, '
          'display, reproduce, and process that content solely for the purpose '
          'of operating and improving the Platform.',
        ),
        _p(
          'You are solely responsible for your User Content. You must not '
          'upload content that is unlawful, defamatory, harassing, or that '
          'infringes the intellectual property rights of others.',
        ),

        // 5. AI-generated content
        _h2('5. AI-Generated Content'),
        _p(
          'Roavvy uses artificial intelligence to generate travel cards, artwork, '
          'titles, and merchandise designs based on your travel data. AI-generated '
          'content may occasionally be inaccurate, incomplete, or unexpected.',
        ),
        _p(
          'You are responsible for reviewing all AI-generated content before '
          'sharing or purchasing it. Roavvy makes no warranties as to the '
          'accuracy of AI-generated content. The Platform provides tools for '
          'you to review and modify content before finalising any order.',
        ),

        // 6. Merchandise
        _h2('6. Merchandise & Print-on-Demand'),
        _p(
          'Roavvy facilitates the purchase of custom print-on-demand merchandise '
          'fulfilled by third-party partners including Printful. All products are '
          'made to order.',
        ),
        _p(
          'Before completing a purchase you will be shown a final preview of '
          'your artwork, colour, size, and placement. You must confirm this '
          'preview before payment is processed. By confirming, you acknowledge '
          'that the product will be manufactured to those exact specifications.',
        ),
        _p(
          'Colours, textures, and placement on the finished product may vary '
          'slightly from on-screen previews due to manufacturing tolerances and '
          'screen calibration differences. This is not a defect.',
        ),
        _p('Please refer to our Refund & Returns Policy for full details.'),

        // 7. Subscriptions
        _h2('7. Subscriptions & Billing'),
        _p(
          'Roavvy offers a free tier and one or more paid subscription tiers. '
          'Paid subscriptions are billed in advance on a recurring basis. '
          'Subscriptions purchased via the Apple App Store or Google Play are '
          'governed by those platforms\' billing terms.',
        ),
        _p(
          'You may cancel your subscription at any time. Cancellation takes '
          'effect at the end of the current billing period. We do not provide '
          'pro-rata refunds for unused portions of a subscription period except '
          'where required by applicable law.',
        ),

        // 8. Promotions
        _h2('8. Promotional Codes & Rewards'),
        _p(
          'Roavvy may offer promotional codes, discount tokens, free merchandise '
          'tokens, referral rewards, and achievement-based rewards. Unless '
          'expressly stated: codes have no cash value; are non-transferable; '
          'may expire; are limited to one per order; and may be withdrawn at '
          'any time.',
        ),
        _p(
          'Roavvy reserves the right to revoke codes and cancel orders where '
          'misuse, fraud, or abuse is suspected. Rewards are for entertainment, '
          'loyalty, and engagement purposes only and do not constitute financial '
          'products or securities.',
        ),

        // 9. Intellectual property
        _h2('9. Intellectual Property'),
        _p(
          'The Roavvy name, logo, app design, and all Platform content created '
          'by us are the intellectual property of Roavvy and may not be used '
          'without our prior written consent.',
        ),
        _p(
          'Artwork and designs generated by the Platform using your travel data '
          'are licensed to you for personal use. You may not resell or sub-licence '
          'Platform-generated designs without our written permission.',
        ),

        // 10. Social features
        _h2('10. Social Features'),
        _p(
          'Roavvy includes social features such as following other users, '
          'liking content, and comments. You agree to use these features '
          'respectfully and in accordance with our Community Guidelines.',
        ),
        _p(
          'We reserve the right to remove any content, disable social features, '
          'or suspend accounts that violate our Community Guidelines or these Terms.',
        ),

        // 11. Privacy
        _h2('11. Privacy'),
        _p(
          'Your use of the Platform is subject to our Privacy Policy, which is '
          'incorporated into these Terms by reference. Please read it carefully.',
        ),

        // 12. Third-party services
        _h2('12. Third-Party Services'),
        _p(
          'The Platform integrates with third-party services including Firebase '
          '(Google), Printful, and Shopify. Your use of those services is '
          'governed by their respective terms and privacy policies. We are not '
          'responsible for third-party service outages or errors.',
        ),

        // 13. Limitation of liability
        _h2('13. Limitation of Liability'),
        _p(
          'To the maximum extent permitted by law, Roavvy\'s liability to you '
          'for any loss or damage arising from your use of the Platform is '
          'limited to the amount you paid us in the 12 months preceding the '
          'claim, or AUD\$100, whichever is greater.',
        ),
        _p(
          'We are not liable for: AI inference errors; travel data inaccuracies; '
          'Platform downtime; third-party service failures; delays or errors in '
          'merchandise fulfilment; or loss of User Content.',
        ),
        _p(
          'Nothing in these Terms excludes, restricts, or modifies any right or '
          'remedy you may have under the Australian Consumer Law that cannot be '
          'excluded by agreement.',
        ),

        // 14. Changes
        _h2('14. Changes to These Terms'),
        _p(
          'We may update these Terms from time to time. When we do, we will '
          'update the version date below and, where the changes are material, '
          'notify you in-app. Continued use of the Platform after changes take '
          'effect constitutes acceptance of the revised Terms.',
        ),

        // 15. Governing law
        _h2('15. Governing Law'),
        _p(
          'These Terms are governed by the laws of New South Wales, Australia. '
          'Any disputes will be subject to the exclusive jurisdiction of the '
          'courts of New South Wales.',
        ),

        // Contact
        _h2('Contact'),
        _p(
          'For legal enquiries: [legal@roavvy.app]\n'
          'For support: [support@roavvy.app]',
        ),

        _version(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _version() => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Version $kCurrentTermsVersion — Last updated [DATE]',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      );

  Widget _h1(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      );

  Widget _h2(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6),
        child: Text(
          text,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      );

  Widget _p(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      );
}

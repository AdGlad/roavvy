import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../account/account_deletion_service.dart';
import '../sharing/share_token_service.dart';

/// Privacy & account settings screen (ADR-042).
///
/// Entry point for sharing management (create / revoke link) and account
/// deletion. Reachable via the MapScreen overflow "Privacy & account" item.
/// Will migrate to the Profile tab in Phase 5.
class PrivacyAccountScreen extends ConsumerStatefulWidget {
  const PrivacyAccountScreen({
    super.key,
    this.deleteAccountOverride,
  });

  /// Test hook. When provided, replaces [AccountDeletionService.deleteAccount].
  @visibleForTesting
  final Future<void> Function(String uid, {String? shareToken})?
      deleteAccountOverride;

  @override
  ConsumerState<PrivacyAccountScreen> createState() =>
      _PrivacyAccountScreenState();
}

class _PrivacyAccountScreenState extends ConsumerState<PrivacyAccountScreen> {
  String? _shareToken;
  bool _loadingToken = true;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final token = await ref.read(visitRepositoryProvider).getShareToken();
    if (!mounted) return;
    setState(() {
      _shareToken = token;
      _loadingToken = false;
    });
  }

  Future<void> _onCreateLink() async {
    final repo = ref.read(visitRepositoryProvider);
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || user.isAnonymous) return;

    const service = ShareTokenService();
    final token = await service.getOrCreateToken(repo);
    final visits = await ref.read(effectiveVisitsProvider.future);
    unawaited(service.publishVisits(token, user.uid, visits));

    if (!mounted) return;
    setState(() => _shareToken = token);

    await Share.share('https://roavvy.app/share/$token');
  }

  Future<void> _onRemoveLink() async {
    final token = _shareToken;
    if (token == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove your sharing link?'),
        content: const Text(
          'Anyone with your link will no longer be able to view your map. '
          'You can create a new link at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove Link'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final repo = ref.read(visitRepositoryProvider);
    final user = ref.read(authStateProvider).valueOrNull;
    unawaited(
      ShareTokenService().revokeToken(token, user?.uid ?? '', repo),
    );
    setState(() => _shareToken = null);
  }

  Future<void> _onDeleteAccount() async {
    // ── First confirmation ──────────────────────────────────────────────────
    final first = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This will permanently delete:\n'
          '· Your entire travel history\n'
          '· Your achievements\n'
          '· Your public sharing link (if any)\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Continue to delete…'),
          ),
        ],
      ),
    );

    if (first != true || !mounted) return;

    // ── Second confirmation ─────────────────────────────────────────────────
    final second = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text(
          'Your account and all data will be permanently deleted. '
          'There is no way to recover it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (second != true || !mounted) return;

    // ── Loading dialog ──────────────────────────────────────────────────────
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Deleting your account…'),
            ],
          ),
        ),
      ),
    );

    final user = ref.read(authStateProvider).valueOrNull;
    final uid = user?.uid ?? '';

    try {
      final deleteFn = widget.deleteAccountOverride ??
          AccountDeletionService(
            auth: FirebaseAuth.instance,
            firestore: FirebaseFirestore.instance,
            repo: ref.read(visitRepositoryProvider),
            shareTokenService: const ShareTokenService(),
          ).deleteAccount;

      await deleteFn(uid, shareToken: _shareToken);

      // Auth deletion succeeded — authStateProvider will emit null and
      // RoavvyApp will navigate to SignInScreen automatically.
      if (mounted) Navigator.of(context).pop(); // dismiss loading dialog
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading dialog

      if (e.code == 'requires-recent-login') {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Sign in required'),
            content: const Text(
              'For security, Apple requires you to sign in again before '
              'deleting your account. Sign in with Apple, then return to '
              'delete your account.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & account')),
      body: _loadingToken
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _SectionHeader('Sharing'),
                _shareToken != null ? _activeShareTile() : _inactiveShareTile(),
                _SectionHeader('Account'),
                _deleteAccountTile(),
                _SectionHeader('Legal'),
                _privacyPolicyTile(),
              ],
            ),
    );
  }

  Widget _activeShareTile() {
    final preview =
        'roavvy.app/share/${_shareToken!.substring(0, 8)}…';
    return ListTile(
      title: const Text('Your map is shared'),
      subtitle: Text(preview),
      trailing: TextButton(
        onPressed: _onRemoveLink,
        style: TextButton.styleFrom(foregroundColor: Colors.red),
        child: const Text('Remove link'),
      ),
    );
  }

  Widget _inactiveShareTile() {
    return ListTile(
      title: const Text('Share your map'),
      subtitle: const Text(
        'Generate a link anyone can use to view your visited countries. '
        'Your name and photos are never included.',
      ),
      trailing: TextButton(
        onPressed: _onCreateLink,
        child: const Text('Create link'),
      ),
    );
  }

  Widget _privacyPolicyTile() {
    return ListTile(
      leading: const Icon(Icons.policy_outlined),
      title: const Text('Privacy Policy'),
      onTap: () => launchUrl(
        Uri.parse('https://roavvy.app/privacy'),
        mode: LaunchMode.externalApplication,
      ),
    );
  }

  Widget _deleteAccountTile() {
    return ListTile(
      leading: const Icon(Icons.delete_forever, color: Colors.red),
      title: const Text(
        'Delete account',
        style: TextStyle(color: Colors.red),
      ),
      onTap: _onDeleteAccount,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}

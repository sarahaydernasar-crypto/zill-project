import 'package:flutter/material.dart';

import '../services/community_store.dart';

/// زر دخول المشرف في الشريط العلوي
class AdminButton extends StatelessWidget {
  const AdminButton({super.key});

  @override
  Widget build(BuildContext context) {
    final community = CommunityScope.of(context);
    return IconButton(
      tooltip: community.isAdmin ? 'خروج المشرف (${community.adminName})' : 'دخول المشرف',
      icon: Icon(community.isAdmin ? Icons.admin_panel_settings : Icons.admin_panel_settings_outlined),
      onPressed: () {
        if (community.isAdmin) {
          community.logout();
        } else {
          showDialog<void>(context: context, builder: (_) => const _LoginDialog());
        }
      },
    );
  }
}

class _LoginDialog extends StatefulWidget {
  const _LoginDialog();

  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final community = CommunityScope.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await community.login(_username.text.trim(), _password.text);
      navigator.pop();
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('دخول المشرف'),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _username, decoration: const InputDecoration(labelText: 'اسم المستخدم')),
          const SizedBox(height: 8),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور'),
            onSubmitted: (_) => _login(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _busy ? null : _login, child: const Text('دخول')),
      ],
    );
  }
}

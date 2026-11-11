import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/green_points.dart';
import '../services/community_store.dart';
import '../services/green_store.dart';
import '../theme.dart';
import '../widgets/tree_widgets.dart';

/// النقاط الخضراء: شرحها قبل الزراعة، ولوحة المستخدم، ومراجعة المشرف
class GreenPointsScreen extends StatelessWidget {
  const GreenPointsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final green = GreenScope.of(context);
    final community = CommunityScope.of(context);
    final rules = green.rules;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          children: [
            const Row(children: [
              Icon(Icons.eco, color: ZillColors.green, size: 32),
              SizedBox(width: 8),
              Expanded(
                child: Text('النقاط الخضراء',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
              ),
            ]),
            const SizedBox(height: 8),
            const Text('قبل أن تزرع، تعرّف على طريقة جمع النقاط وما يمكنك الحصول عليه مقابلها.',
                style: TextStyle(height: 1.6)),
            const SizedBox(height: 16),
            if (community.isAdmin) ...[
              const _AdminPanel(),
              const SizedBox(height: 8),
            ],
            if (green.isLoggedIn) _Dashboard(green: green, rules: rules) else const _GuestCard(),
            const SizedBox(height: 16),
            const _Section(
              icon: Icons.format_list_numbered,
              title: 'كيف تحصل على النقاط',
              children: [
                _Step(1, 'اختر مكان الزراعة من الخريطة أو التوصيات.'),
                _Step(2, 'ازرع الشجرة وصوّرها بعد الزراعة.'),
                _Step(3, 'أنشئ حساباً وسجّل الشجرة وموقعها.'),
                _Step(4, 'يراجع المشرف التسجيل، وبعد اعتماده تظهر الشجرة على الخريطة وتُحسب نقاطها.'),
              ],
            ),
            if (rules == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('تعذر تحميل قيم النقاط. تأكد من تشغيل الخادم ثم اضغط تحديث البيانات.',
                    style: TextStyle(color: ZillColors.muted)),
              )
            else ...[
              _Section(
                icon: Icons.stars_outlined,
                title: 'قيمة كل مساهمة',
                children: [
                  for (final way in rules.earnWays) _EarnRow(way.title, way.detail, way.points),
                ],
              ),
              _Section(
                icon: Icons.redeem_outlined,
                title: 'ماذا تفعل بـ ${rules.redeemPoints} نقطة؟',
                children: const [
                  _RewardRow(Icons.phone_android, 'تحويلها إلى رصيد آسياسيل'),
                  _RewardRow(Icons.storefront_outlined, 'الحصول على خصم من متجر مشارك'),
                ],
              ),
              Text(
                'مثال: إذا جمعت نقاطك من الزراعة وحدها، تصل إلى ${rules.redeemPoints} نقطة '
                'بعد ${rules.treesToRedeem} شجرة معتمدة. والقيم أولية وقابلة للتغيير.',
                style: const TextStyle(height: 1.6, color: ZillColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ZillColors.greenLight, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('أنشئ حساباً لتسجيل أشجارك وجمع النقاط.',
            style: TextStyle(height: 1.6, color: ZillColors.greenDark)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton(
            onPressed: () => showDialog<void>(context: context, builder: (_) => const AccountDialog(register: true)),
            child: const Text('إنشاء حساب'),
          ),
          OutlinedButton(
            onPressed: () => showDialog<void>(context: context, builder: (_) => const AccountDialog()),
            child: const Text('تسجيل الدخول'),
          ),
        ]),
      ]),
    );
  }
}

/// لوحة النقاط الخضراء للمستخدم
class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.green, required this.rules});
  final GreenStore green;
  final GreenRules? rules;

  @override
  Widget build(BuildContext context) {
    final board = green.dashboard;
    if (board == null) return const Center(child: CircularProgressIndicator());
    final target = rules?.redeemPoints;
    final canRedeem = target != null && board.balance >= target;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Section(
        icon: Icons.account_balance_wallet_outlined,
        title: 'رصيدك: ${pointsLabel(board.balance)}',
        children: [
          Text('مرحباً ${green.username}', style: const TextStyle(color: ZillColors.muted)),
          if (target != null) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: (board.balance / target).clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              color: ZillColors.green,
              backgroundColor: ZillColors.greenLight,
            ),
            const SizedBox(height: 6),
            Text(canRedeem ? 'يمكنك استبدال نقاطك الآن.' : 'باقٍ ${pointsLabel(target - board.balance)} للاستبدال.'),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: () => showDialog<void>(context: context, builder: (_) => const TreeFormDialog()),
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text('تسجيل شجرة'),
            ),
            OutlinedButton.icon(
              onPressed: canRedeem
                  ? () => showDialog<void>(context: context, builder: (_) => RedeemDialog(points: target))
                  : null,
              icon: const Icon(Icons.redeem_outlined, size: 18),
              label: const Text('استبدال النقاط'),
            ),
            TextButton(onPressed: green.logout, child: const Text('تسجيل الخروج')),
          ]),
        ],
      ),
      _Section(
        icon: Icons.park_outlined,
        title: 'أشجاري (${board.trees.length})',
        children: [
          if (board.trees.isEmpty) const Text('لم تسجل أي شجرة بعد.', style: TextStyle(color: ZillColors.muted)),
          for (final t in board.trees) _MyTreeRow(t),
        ],
      ),
      if (board.redemptions.isNotEmpty)
        _Section(
          icon: Icons.receipt_long_outlined,
          title: 'طلبات الاستبدال',
          children: [
            for (final r in board.redemptions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${redeemRewards[r['reward']] ?? r['reward']}: ${redeemStatuses[r['status']] ?? r['status']}'
                  '${r['admin_note'] == null ? '' : ' (${r['admin_note']})'}',
                ),
              ),
          ],
        ),
      _Section(
        icon: Icons.history,
        title: 'سجل النقاط',
        children: [
          if (board.entries.isEmpty) const Text('لا توجد حركات بعد.', style: TextStyle(color: ZillColors.muted)),
          for (final e in board.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(child: Text(e['reason'] as String)),
                const SizedBox(width: 8),
                Text(
                  '${(e['points'] as int) > 0 ? '+' : ''}${e['points']}',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: (e['points'] as int) > 0 ? ZillColors.green : const Color(0xFFB91C1C),
                  ),
                ),
              ]),
            ),
        ],
      ),
    ]);
  }
}

class _MyTreeRow extends StatelessWidget {
  const _MyTreeRow(this.tree);
  final RegisteredTree tree;

  @override
  Widget build(BuildContext context) {
    final approved = tree.reviewStatus == 'approved';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(Icons.circle, size: 12, color: approved ? treeStatusColor(tree.status) : ZillColors.noData),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tree.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              '${reviewStatuses[tree.reviewStatus] ?? ''}'
              '${approved ? '، ${tree.statusLabel}' : ''}'
              '${tree.adminNote == null ? '' : ' (${tree.adminNote})'}',
              style: const TextStyle(fontSize: 13, color: ZillColors.muted),
            ),
          ]),
        ),
        if (approved)
          TextButton(
            onPressed: () => showDialog<void>(context: context, builder: (_) => TreeUpdateDialog(tree: tree)),
            child: const Text('متابعة'),
          ),
      ]),
    );
  }
}

/// مراجعة الأشجار والمتابعات وطلبات الاستبدال
class _AdminPanel extends StatefulWidget {
  const _AdminPanel();

  @override
  State<_AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<_AdminPanel> {
  Map<String, dynamic>? _pending;
  List<Map<String, dynamic>> _redemptions = [];
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    final community = CommunityScope.of(context);
    try {
      final pending = await community.pendingReviews();
      final redemptions = await community.listRedemptions();
      if (!mounted) return;
      setState(() {
        _pending = pending;
        _redemptions = redemptions;
        _error = null;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// ينفذ قرار المراجعة ثم يحدّث كل ما يتأثر به
  Future<void> _act(Future<void> Function() action) async {
    final green = GreenScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      await _load();
      await green.refresh();
    } on ApiError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = CommunityScope.of(context);
    final pending = _pending;
    final trees = (pending?['trees'] as List?) ?? const [];
    final updates = (pending?['updates'] as List?) ?? const [];
    return _Section(
      icon: Icons.admin_panel_settings_outlined,
      title: 'مراجعة المشرف',
      children: [
        if (_error != null) Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
        if (pending != null && trees.isEmpty && updates.isEmpty && _redemptions.isEmpty)
          const Text('لا يوجد شيء بانتظار المراجعة.', style: TextStyle(color: ZillColors.muted)),
        for (final raw in trees)
          _reviewCard(
            RegisteredTree.fromJson(Map<String, dynamic>.from(raw as Map)),
            (decision, note) => _act(() => community.reviewTree(raw['id'] as int, decision, note)),
          ),
        for (final raw in updates)
          _ReviewCard(
            key: ValueKey('update-${(raw as Map)['id']}'),
            title: 'متابعة: ${raw['tree_name']}',
            lines: [
              'الحالة: ${treeStatuses[raw['status']] ?? raw['status']}',
              if (raw['note'] != null && (raw['note'] as String).isNotEmpty) raw['note'] as String,
            ],
            photo: raw['photo'] as String?,
            onDecide: (decision, note) => _act(() => community.reviewUpdate(raw['id'] as int, decision, note)),
          ),
        for (final r in _redemptions)
          _ReviewCard(
            key: ValueKey('redemption-${r['id']}'),
            title: 'استبدال: ${redeemRewards[r['reward']] ?? r['reward']}',
            lines: ['المستخدم: ${r['username']}', 'الهاتف: ${r['phone']}', 'النقاط: ${r['points']}'],
            approveLabel: 'تم التنفيذ',
            onDecide: (decision, note) => _act(() => community.updateRedemption(
                  r['id'] as int,
                  decision == 'approved' ? 'completed' : 'rejected',
                  note,
                )),
          ),
      ],
    );
  }

  Widget _reviewCard(RegisteredTree t, void Function(String decision, String? note) onDecide) {
    return _ReviewCard(
      key: ValueKey('tree-${t.id}'),
      title: 'شجرة: ${t.name}',
      lines: ['المساهم: ${t.contributor}', 'تاريخ الزراعة: ${t.plantedOn}'],
      photo: t.photo,
      onShowLocation: () => launchUrl(
        Uri.parse(
          'https://www.openstreetmap.org/?mlat=${t.point.latitude}&mlon=${t.point.longitude}'
          '#map=18/${t.point.latitude}/${t.point.longitude}',
        ),
        mode: LaunchMode.externalApplication,
      ),
      onDecide: onDecide,
    );
  }
}

class _ReviewCard extends StatefulWidget {
  const _ReviewCard({
    super.key,
    required this.title,
    required this.lines,
    required this.onDecide,
    this.photo,
    this.onShowLocation,
    this.approveLabel = 'اعتماد',
  });

  final String title;
  final List<String> lines;
  final String? photo;
  final VoidCallback? onShowLocation;
  final String approveLabel;
  final void Function(String decision, String? note) onDecide;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _decide(String decision) {
    final note = _note.text.trim();
    widget.onDecide(decision, note.isEmpty ? null : note);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        for (final line in widget.lines) Text(line),
        if (widget.photo != null) ...[const SizedBox(height: 8), UploadedPhoto(widget.photo!)],
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          maxLength: 1000,
          decoration: const InputDecoration(labelText: 'ملاحظة تظهر للمستخدم (اختياري)'),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton(onPressed: () => _decide('approved'), child: Text(widget.approveLabel)),
          OutlinedButton(onPressed: () => _decide('rejected'), child: const Text('رفض')),
          if (widget.onShowLocation != null)
            TextButton.icon(
              onPressed: widget.onShowLocation,
              icon: const Icon(Icons.place_outlined, size: 18),
              label: const Text('عرض الموقع'),
            ),
        ]),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.children});
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: ZillColors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
              ),
            ]),
            const SizedBox(height: 12),
            ...children,
          ]),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.text);
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: ZillColors.green,
          foregroundColor: Colors.white,
          child: Text('$number', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(height: 1.6))),
      ]),
    );
  }
}

class _EarnRow extends StatelessWidget {
  const _EarnRow(this.title, this.detail, this.points);
  final String title;
  final String detail;
  final int points;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(detail, style: const TextStyle(fontSize: 13, color: ZillColors.muted)),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: ZillColors.greenLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(pointsLabel(points),
              style: const TextStyle(fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
        ),
      ]),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, color: ZillColors.green, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../config.dart';
import '../models/green_points.dart';
import '../screens/reports_screen.dart' show pickPhoto;
import '../services/community_store.dart';
import '../services/green_store.dart';
import '../theme.dart';

const _errorColor = Color(0xFFB91C1C);

Color treeStatusColor(String status) => switch (status) {
      'healthy' => ZillColors.green,
      'needs_care' => ZillColors.heatHot,
      _ => ZillColors.noData,
    };

/// صورة من مرفوعات الخادم
class UploadedPhoto extends StatelessWidget {
  const UploadedPhoto(this.path, {super.key, this.height = 160});
  final String path;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        CommunityStore.photoUrl(path),
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Padding(
          padding: EdgeInsets.all(12),
          child: Text('تعذر تحميل الصورة', style: TextStyle(color: ZillColors.muted)),
        ),
      ),
    );
  }
}

/// بطاقة الشجرة على الخريطة: اسمها وتاريخها وحالتها والمساهم وسجل نموها
void showTreeDetails(BuildContext context, RegisteredTree tree) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Row(children: [
            const Icon(Icons.park, color: ZillColors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(tree.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
            ),
          ]),
          const SizedBox(height: 10),
          Text('تاريخ الزراعة: ${tree.plantedOn}'),
          Text('الحالة: ${tree.statusLabel}'),
          Text('المساهم: ${tree.contributor}'),
          if (tree.photo != null) ...[const SizedBox(height: 12), UploadedPhoto(tree.photo!, height: 200)],
          const SizedBox(height: 16),
          const Text('سجل متابعة النمو',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
          const SizedBox(height: 8),
          if (tree.updates.isEmpty)
            const Text('لا توجد متابعات بعد.', style: TextStyle(color: ZillColors.muted)),
          for (final u in tree.updates.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${u.date}: ${treeStatuses[u.status] ?? u.status}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if (u.note != null && u.note!.isNotEmpty) Text(u.note!),
                if (u.photo != null) ...[const SizedBox(height: 6), UploadedPhoto(u.photo!)],
              ]),
            ),
        ],
      ),
    ),
  );
}

/// زر حساب المستخدم في الشريط العلوي
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    final green = GreenScope.of(context);
    if (!green.isLoggedIn) {
      return IconButton(
        tooltip: 'تسجيل الدخول',
        icon: const Icon(Icons.login),
        onPressed: () => showDialog<void>(context: context, builder: (_) => const AccountDialog()),
      );
    }
    return PopupMenuButton<void>(
      tooltip: 'حسابي (${green.username})',
      icon: const Icon(Icons.account_circle),
      itemBuilder: (_) => [
        PopupMenuItem<void>(enabled: false, child: Text(green.username!)),
        PopupMenuItem<void>(onTap: green.logout, child: const Text('تسجيل الخروج')),
      ],
    );
  }
}

/// نافذة إنشاء حساب أو تسجيل الدخول
class AccountDialog extends StatefulWidget {
  const AccountDialog({super.key, this.register = false});
  final bool register;

  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  late bool _register = widget.register;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final green = GreenScope.of(context);
    final navigator = Navigator.of(context);
    final name = _username.text.trim();
    if (_register && !RegExp(r'^[\p{L}\p{N}_.-]{3,30}$', unicode: true).hasMatch(name)) {
      setState(() => _error = 'اسم المستخدم من 3 إلى 30 حرفاً، بلا مسافات.');
      return;
    }
    if (_register && _password.text.length < 8) {
      setState(() => _error = 'كلمة المرور 8 أحرف على الأقل.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await (_register ? green.register(name, _password.text) : green.login(name, _password.text));
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
      title: Text(_register ? 'إنشاء حساب' : 'تسجيل الدخول'),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _username, decoration: const InputDecoration(labelText: 'اسم المستخدم')),
          const SizedBox(height: 8),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور'),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: _errorColor)),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() {
                _register = !_register;
                _error = null;
              }),
              child: Text(_register ? 'لديك حساب؟ سجّل الدخول' : 'ليس لديك حساب؟ أنشئ حساباً'),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(_register ? 'إنشاء' : 'دخول')),
      ],
    );
  }
}

/// نموذج تسجيل شجرة، ويُحدَّد موقعها بالضغط على الخريطة
class TreeFormDialog extends StatefulWidget {
  const TreeFormDialog({super.key});

  @override
  State<TreeFormDialog> createState() => _TreeFormDialogState();
}

class _TreeFormDialogState extends State<TreeFormDialog> {
  final _name = TextEditingController();
  final _contributor = TextEditingController();
  LatLng? _point;
  DateTime _plantedOn = DateTime.now();
  PickedPhoto? _photo;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _contributor.dispose();
    super.dispose();
  }

  String get _dateText => _plantedOn.toIso8601String().substring(0, 10);

  Future<void> _submit() async {
    final green = GreenScope.of(context);
    final navigator = Navigator.of(context);
    final name = _name.text.trim();
    final problem = name.length < 2
        ? 'اكتب اسم الشجرة.'
        : _point == null
            ? 'اضغط على الخريطة لتحديد موقع الشجرة.'
            : _photo == null
                ? 'أضف صورة للشجرة حتى يراجعها المشرف.'
                : null;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await green.registerTree(
        name: name,
        lat: _point!.latitude,
        lng: _point!.longitude,
        plantedOn: _dateText,
        contributor: _contributor.text.trim(),
        photo: _photo!,
      );
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
      title: const Text('تسجيل شجرة'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم الشجرة')),
            const SizedBox(height: 8),
            TextField(
              controller: _contributor,
              decoration: const InputDecoration(
                labelText: 'الشخص أو الفريق المساهم',
                helperText: 'يظهر للجميع على الخريطة. إذا تركته فارغاً يظهر اسم المستخدم.',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _plantedOn,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _plantedOn = picked);
              },
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text('تاريخ الزراعة: $_dateText'),
            ),
            const SizedBox(height: 12),
            Text(_point == null ? 'اضغط على موقع الشجرة في الخريطة:' : 'تم تحديد الموقع. اضغط مرة أخرى لتغييره.'),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 240,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: AppConfig.cityCenter,
                    initialZoom: AppConfig.cityZoom,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onTap: (_, point) => setState(() => _point = point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.zill.zill_app',
                    ),
                    if (_point != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: _point!,
                          width: 36,
                          height: 36,
                          child: const Icon(Icons.location_on, color: ZillColors.greenDark, size: 36),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final photo = await pickPhoto();
                if (photo != null) setState(() => _photo = photo);
              },
              icon: Icon(_photo == null ? Icons.add_a_photo_outlined : Icons.check_circle_outline, size: 18),
              label: Text(_photo == null ? 'إضافة صورة الشجرة' : 'تم اختيار الصورة'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: _errorColor)),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _busy ? null : _submit, child: const Text('إرسال للمراجعة')),
      ],
    );
  }
}

/// نموذج متابعة نمو شجرة معتمدة
class TreeUpdateDialog extends StatefulWidget {
  const TreeUpdateDialog({super.key, required this.tree});
  final RegisteredTree tree;

  @override
  State<TreeUpdateDialog> createState() => _TreeUpdateDialogState();
}

class _TreeUpdateDialogState extends State<TreeUpdateDialog> {
  final _note = TextEditingController();
  late String _status = widget.tree.status;
  PickedPhoto? _photo;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final green = GreenScope.of(context);
    final navigator = Navigator.of(context);
    if (_photo == null) {
      setState(() => _error = 'أضف صورة حديثة للشجرة.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await green.addTreeUpdate(widget.tree.id, _status, _note.text.trim(), _photo!);
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
      title: Text('متابعة ${widget.tree.name}'),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'حالة الشجرة'),
            items: [
              for (final e in treeStatuses.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLines: 2,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final photo = await pickPhoto();
              if (photo != null) setState(() => _photo = photo);
            },
            icon: Icon(_photo == null ? Icons.add_a_photo_outlined : Icons.check_circle_outline, size: 18),
            label: Text(_photo == null ? 'إضافة صورة حديثة' : 'تم اختيار الصورة'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: _errorColor)),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _busy ? null : _submit, child: const Text('إرسال للمراجعة')),
      ],
    );
  }
}

/// نموذج طلب استبدال النقاط
class RedeemDialog extends StatefulWidget {
  const RedeemDialog({super.key, required this.points});
  final int points;

  @override
  State<RedeemDialog> createState() => _RedeemDialogState();
}

class _RedeemDialogState extends State<RedeemDialog> {
  final _phone = TextEditingController();
  String _reward = redeemRewards.keys.first;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final green = GreenScope.of(context);
    final navigator = Navigator.of(context);
    final phone = _phone.text.trim();
    if (!RegExp(r'^07\d{9}$').hasMatch(phone)) {
      setState(() => _error = 'اكتب رقم هاتف عراقي صحيح، مثل 07701234567.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await green.redeem(_reward, phone);
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
      title: const Text('استبدال النقاط'),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('سيُخصم ${pointsLabel(widget.points)} من رصيدك. وإذا رفض المشرف الطلب تعود النقاط إليك.',
              style: const TextStyle(height: 1.6)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _reward,
            decoration: const InputDecoration(labelText: 'المكافأة'),
            items: [
              for (final e in redeemRewards.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _reward = v ?? _reward),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف',
              helperText: 'يراه المشرف فقط، لتنفيذ طلبك.',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: _errorColor)),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _busy ? null : _submit, child: const Text('إرسال الطلب')),
      ],
    );
  }
}

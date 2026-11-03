import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/areas_store.dart';
import '../services/community_store.dart';
import '../theme.dart';

const reportTypes = {
  'hot_area': 'منطقة تعاني من ارتفاع الحرارة',
  'planting_site': 'اقتراح موقع يحتاج إلى التشجير',
  'damaged_tree': 'شجرة متضررة',
};

const reportStatuses = {
  'new': 'جديد',
  'in_review': 'قيد المراجعة',
  'resolved': 'تمت المعالجة',
  'rejected': 'مرفوض',
};

Future<PickedPhoto?> pickPhoto() async {
  final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
  return file == null ? null : PickedPhoto(file.name, await file.readAsBytes());
}

/// بلاغات المجتمع: إرسال بلاغ ومتابعته، وإدارته للمشرف
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final community = CommunityScope.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
          children: [
            const Text('شارك في تحسين بيئة مدينتك',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
            const Text('أرسل بلاغاً دون إنشاء حساب، وتابع حالته برمز خاص.',
                style: TextStyle(color: ZillColors.muted)),
            const SizedBox(height: 20),
            const _ReportForm(),
            const SizedBox(height: 16),
            const _TrackCard(),
            if (community.isAdmin) ...[
              const SizedBox(height: 24),
              const _AdminReports(),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportForm extends StatefulWidget {
  const _ReportForm();

  @override
  State<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<_ReportForm> {
  final _formKey = GlobalKey<FormState>();
  final _place = TextEditingController();
  final _description = TextEditingController();
  String _type = 'hot_area';
  String? _district;
  PickedPhoto? _photo;
  bool _sending = false;
  String? _error;
  String? _code;

  @override
  void dispose() {
    _place.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final place = _place.text.trim();
    try {
      final code = await CommunityScope.of(context).submitReport(
        type: _type,
        area: place.isEmpty ? _district! : '$_district - $place',
        description: _description.text.trim(),
        photo: _photo,
      );
      setState(() {
        _code = code;
        _photo = null;
        _place.clear();
        _description.clear();
      });
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final districts = AreasScope.of(context).areas.map((a) => a.name).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('بلاغ جديد',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              decoration: _decoration('نوع البلاغ'),
              items: [
                for (final e in reportTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _district,
              isExpanded: true,
              decoration: _decoration('القضاء'),
              items: [for (final d in districts) DropdownMenuItem(value: d, child: Text(d))],
              onChanged: (v) => setState(() => _district = v),
              validator: (v) => v == null ? 'اختر القضاء' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _place,
              maxLength: 100,
              decoration: _decoration('الحي أو أقرب مكان معروف (اختياري)'),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _description,
              maxLines: 3,
              maxLength: 1000,
              decoration: _decoration('وصف المشكلة أو الاقتراح'),
              validator: (v) => (v?.trim().length ?? 0) < 3 ? 'اكتب وصفاً قصيراً' : null,
            ),
            const SizedBox(height: 4),
            Row(children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final photo = await pickPhoto();
                  if (photo != null) setState(() => _photo = photo);
                },
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('إرفاق صورة'),
              ),
              const SizedBox(width: 10),
              if (_photo != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(_photo!.bytes, width: 44, height: 44, fit: BoxFit.cover),
                ),
                IconButton(
                  onPressed: () => setState(() => _photo = null),
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'إزالة الصورة',
                ),
              ],
            ]),
            const SizedBox(height: 4),
            const Text('لا تُرفق صوراً تُظهر وجوه أشخاص أو لوحات سيارات.',
                style: TextStyle(fontSize: 12, color: ZillColors.muted)),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: _sending ? null : _submit,
              child: Text(_sending ? 'جارٍ الإرسال…' : 'إرسال البلاغ'),
            ),
            if (_code != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: ZillColors.greenLight, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('تم إرسال بلاغك. احتفظ برمز المتابعة:'),
                      SelectableText(_code!,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800, color: ZillColors.greenDark)),
                    ]),
                  ),
                  IconButton(
                    onPressed: () => Clipboard.setData(ClipboardData(text: _code!)),
                    icon: const Icon(Icons.copy),
                    tooltip: 'نسخ الرمز',
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

InputDecoration _decoration(String label) => InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );

class _TrackCard extends StatefulWidget {
  const _TrackCard();

  @override
  State<_TrackCard> createState() => _TrackCardState();
}

class _TrackCardState extends State<_TrackCard> {
  final _code = TextEditingController();
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _track() async {
    if (_code.text.trim().isEmpty) return;
    try {
      final r = await CommunityScope.of(context).trackReport(_code.text);
      setState(() {
        _result = r;
        _error = null;
      });
    } on ApiError catch (e) {
      setState(() {
        _result = null;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('متابعة بلاغ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _code,
                decoration: _decoration('رمز المتابعة'),
                onSubmitted: (_) => _track(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _track, child: const Text('بحث')),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
          ],
          if (r != null) ...[
            const SizedBox(height: 12),
            Text('الحالة: ${reportStatuses[r['status']] ?? r['status']}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${reportTypes[r['report_type']] ?? ''} · ${r['area_name']}'),
            if (r['admin_note'] != null) Text('ملاحظة المشرف: ${r['admin_note']}'),
          ],
        ]),
      ),
    );
  }
}

/// إدارة البلاغات للمشرف
class _AdminReports extends StatefulWidget {
  const _AdminReports();

  @override
  State<_AdminReports> createState() => _AdminReportsState();
}

class _AdminReportsState extends State<_AdminReports> {
  List<Map<String, dynamic>>? _reports;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reports == null && _error == null) _load();
  }

  Future<void> _load() async {
    try {
      final list = await CommunityScope.of(context).listReports();
      if (mounted) setState(() => _reports = list);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reports = _reports;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(
          child: Text('إدارة البلاغات',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
        ),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'تحديث'),
      ]),
      if (_error != null) Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
      if (reports != null && reports.isEmpty)
        const Text('لا توجد بلاغات بعد.', style: TextStyle(color: ZillColors.muted)),
      for (final r in reports ?? const <Map<String, dynamic>>[])
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: _AdminReportCard(key: ValueKey(r['id']), report: r),
        ),
    ]);
  }
}

class _AdminReportCard extends StatefulWidget {
  const _AdminReportCard({super.key, required this.report});
  final Map<String, dynamic> report;

  @override
  State<_AdminReportCard> createState() => _AdminReportCardState();
}

class _AdminReportCardState extends State<_AdminReportCard> {
  late String _status = widget.report['status'] as String? ?? 'new';
  late final _note = TextEditingController(text: widget.report['admin_note'] as String?);
  String? _message;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      final note = _note.text.trim();
      await CommunityScope.of(context).updateReport(widget.report['id'] as int, _status, note.isEmpty ? null : note);
      setState(() => _message = 'تم الحفظ');
    } on ApiError catch (e) {
      setState(() => _message = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final photo = r['photo'] as String?;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(reportTypes[r['report_type']] ?? '${r['report_type']}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('${r['area_name']} · ${r['tracking_code']}',
              style: const TextStyle(fontSize: 13, color: ZillColors.muted)),
          const SizedBox(height: 6),
          // نص المستخدم يُعرض نصاً عادياً فقط
          Text('${r['description']}'),
          if (photo != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(CommunityStore.photoUrl(photo), height: 160, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: _decoration('الحالة'),
            items: [for (final e in reportStatuses.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() => _status = v!),
          ),
          const SizedBox(height: 8),
          TextField(controller: _note, decoration: _decoration('ملاحظة تظهر لصاحب البلاغ')),
          const SizedBox(height: 8),
          Row(children: [
            FilledButton(onPressed: _save, child: const Text('حفظ')),
            const SizedBox(width: 10),
            if (_message != null) Text(_message!),
          ]),
        ]),
      ),
    );
  }
}

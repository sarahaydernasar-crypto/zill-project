import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/area.dart';
import '../models/campaign.dart';
import '../services/areas_store.dart';
import '../services/community_store.dart';
import '../theme.dart';
import 'reports_screen.dart' show pickPhoto;

/// حملات التشجير المنفذة ونتائجها
class CampaignsScreen extends StatelessWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final community = CommunityScope.of(context);
    final campaigns = community.campaigns;
    final withCount = campaigns.where((c) => c.treesAlive != null);
    final planted = withCount.fold<int>(0, (s, c) => s + c.treesPlanted);
    final alive = withCount.fold<int>(0, (s, c) => s + c.treesAlive!);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
          children: [
            Row(children: [
              const Expanded(
                child: Text('حملات التشجير',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
              ),
              if (community.isAdmin)
                FilledButton.icon(
                  onPressed: () => showCampaignForm(context),
                  icon: const Icon(Icons.add),
                  label: const Text('حملة جديدة'),
                ),
            ]),
            const Text('ما نُفذ فعلياً على الأرض، وأثره المقاس من صور الأقمار الصناعية.',
                style: TextStyle(color: ZillColors.muted)),
            const SizedBox(height: 20),
            if (campaigns.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('لا توجد حملات مسجلة بعد. يضيفها المشرف بعد تنفيذها على الأرض.',
                        textAlign: TextAlign.center, style: TextStyle(color: ZillColors.muted)),
                  ),
                ),
              )
            else ...[
              Wrap(spacing: 32, runSpacing: 12, children: [
                _Figure('${campaigns.length}', 'حملة'),
                _Figure('${campaigns.fold<int>(0, (s, c) => s + c.treesPlanted)}', 'شجرة مزروعة'),
                if (planted > 0) _Figure('${(alive / planted * 100).round()}%', 'نسبة بقاء الأشجار'),
              ]),
              const SizedBox(height: 20),
              for (final c in campaigns)
                Padding(padding: const EdgeInsets.only(bottom: 14), child: _CampaignCard(c)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: ZillColors.greenDark)),
        Text(label, style: const TextStyle(color: ZillColors.muted)),
      ]);
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard(this.c);
  final Campaign c;

  @override
  Widget build(BuildContext context) {
    final community = CommunityScope.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
          Text('${c.areaName} · ${c.plantedOnText}', style: const TextStyle(color: ZillColors.muted)),
          const SizedBox(height: 8),
          Text('${c.treesPlanted} شجرة مزروعة'
              '${c.treesAlive == null ? '' : '، بقي منها ${c.treesAlive} (${(c.successRate! * 100).round()}%)'}'),
          Text('حالة الأشجار: ${c.condition.label}'),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: () => showCampaignReport(context, c),
              icon: const Icon(Icons.assessment_outlined, size: 18),
              label: const Text('تقرير النتائج'),
            ),
            if (community.isAdmin) ...[
              OutlinedButton(onPressed: () => showCampaignForm(context, campaign: c), child: const Text('تعديل')),
              OutlinedButton.icon(
                onPressed: () => _addParticipant(context),
                icon: const Icon(Icons.person_add_alt_outlined, size: 18),
                label: const Text('إضافة مشارك'),
              ),
              for (final (kind, label) in const [('before', 'صورة قبل'), ('after', 'صورة بعد')])
                OutlinedButton.icon(
                  onPressed: () => _uploadPhoto(context, kind),
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: Text(label),
                ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFB91C1C)),
                onPressed: () => _confirmDelete(context),
                child: const Text('حذف'),
              ),
            ],
          ]),
        ]),
      ),
    );
  }

  /// يمنح مستخدماً حضر الحملة نقاط المشاركة
  Future<void> _addParticipant(BuildContext context) async {
    final community = CommunityScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final input = TextEditingController();
    final username = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مشارك في الحملة'),
        content: TextField(
          controller: input,
          decoration: const InputDecoration(labelText: 'اسم المستخدم كما في حسابه'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, input.text.trim()), child: const Text('إضافة')),
        ],
      ),
    );
    input.dispose();
    if (username == null || username.isEmpty) return;
    try {
      await community.addCampaignParticipant(c.id, username);
      messenger.showSnackBar(SnackBar(content: Text('تم تسجيل مشاركة $username.')));
    } on ApiError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _uploadPhoto(BuildContext context, String kind) async {
    final community = CommunityScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final photo = await pickPhoto();
    if (photo == null) return;
    try {
      await community.uploadCampaignPhoto(c.id, kind, photo);
      messenger.showSnackBar(const SnackBar(content: Text('تم رفع الصورة')));
    } on ApiError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final community = CommunityScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحملة؟'),
        content: Text('ستُحذف «${c.name}» ولا يمكن التراجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await community.deleteCampaign(c.id);
    } on ApiError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

// ---------- تقرير الحملة ----------
String _signed(double? v, int digits) =>
    v == null ? '—' : '${v > 0 ? '+' : ''}${v.toStringAsFixed(digits)}';

/// نص التقرير القابل للنسخ
String campaignReportText(Campaign c) {
  final m = c.measurement;
  return [
    'تقرير حملة التشجير: ${c.name}',
    'المنطقة: ${c.areaName}',
    'تاريخ التنفيذ: ${c.plantedOnText}',
    'الأشجار المزروعة: ${c.treesPlanted}',
    if (c.treesAlive != null) 'الأشجار الباقية: ${c.treesAlive} (${(c.successRate! * 100).round()}%)',
    'حالة الأشجار: ${c.condition.label}',
    if (c.species != null) 'الأنواع: ${c.species}',
    if (m != null) ...[
      'القياس من الأقمار الصناعية: ${m.periodBefore} مقابل ${m.periodAfter}',
      'NDVI في الموقع: ${fmt(m.ndviBefore, 2)} ثم ${fmt(m.ndviAfter, 2)} (التغير الصافي عن المحيط ${_signed(m.netNdvi, 2)})',
      'حرارة السطح: ${fmt(m.tempBefore)} ثم ${fmt(m.tempAfter)} درجة مئوية (التغير الصافي عن المحيط ${_signed(m.netTemp, 1)})',
      'مساحة الغطاء النباتي: ${fmt(m.greenHaBefore, 2)} ثم ${fmt(m.greenHaAfter, 2)} هكتار',
      'ملاحظة: يدل القياس على ارتباط زمني ولا يثبت وحده أن التشجير هو السبب.',
    ] else
      'لم يُقَس أثر هذه الحملة من الأقمار الصناعية بعد.',
  ].join('\n');
}

Future<void> showCampaignReport(BuildContext context, Campaign c) => showDialog(
      context: context,
      builder: (ctx) {
        final m = c.measurement;
        return AlertDialog(
          title: Text(c.name),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('${c.areaName} · ${c.plantedOnText}', style: const TextStyle(color: ZillColors.muted)),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _Photo('قبل التشجير', c.photoBefore)),
                  const SizedBox(width: 10),
                  Expanded(child: _Photo('بعد التشجير', c.photoAfter)),
                ]),
                const SizedBox(height: 16),
                Text('${c.treesPlanted} شجرة مزروعة'
                    '${c.treesAlive == null ? '' : '، بقي منها ${c.treesAlive} (${(c.successRate! * 100).round()}%)'}'),
                Text('حالة الأشجار: ${c.condition.label}'),
                if (c.species != null) Text('الأنواع: ${c.species}'),
                if (c.notes != null) Text(c.notes!),
                const SizedBox(height: 16),
                const Text('الأثر المقاس من الأقمار الصناعية',
                    style: TextStyle(fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
                const SizedBox(height: 6),
                if (m == null)
                  const Text('لم يُقَس بعد. يظهر عادةً بعد سنة من الزراعة على الأقل، لأن الأشجار الصغيرة لا تظهر في الصور قبل ذلك.',
                      style: TextStyle(color: ZillColors.muted, height: 1.6))
                else ...[
                  Table(
                    columnWidths: const {0: FlexColumnWidth(2)},
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      _tableRow(['', '${m.periodBefore}', '${m.periodAfter}', 'الصافي عن المحيط'], header: true),
                      _tableRow(['NDVI', fmt(m.ndviBefore, 2), fmt(m.ndviAfter, 2), _signed(m.netNdvi, 2)]),
                      _tableRow(['حرارة السطح', deg(m.tempBefore), deg(m.tempAfter), _signed(m.netTemp, 1)]),
                      _tableRow(['الغطاء النباتي (هكتار)', fmt(m.greenHaBefore, 2), fmt(m.greenHaAfter, 2), '—']),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '«الصافي عن المحيط» يطرح تغير حلقة بعرض 500 متر حول الموقع، للحد من أثر اختلاف الطقس بين السنتين. '
                    'يدل القياس على ارتباط زمني، ولا يثبت وحده أن التشجير هو السبب. ودقة الصور 30 متراً، فلا تظهر فيها الأشجار الصغيرة جيداً.',
                    style: TextStyle(fontSize: 12, height: 1.6, color: ZillColors.muted),
                  ),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Clipboard.setData(ClipboardData(text: campaignReportText(c))),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('نسخ التقرير'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          ],
        );
      },
    );

TableRow _tableRow(List<String> cells, {bool header = false}) => TableRow(children: [
      for (final (i, c) in cells.indexed)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Text(c,
              // الأرقام والإشارات باتجاه LTR حتى لا تنتقل علامة + و- إلى يمين الرقم
              textDirection: i > 0 && !header ? TextDirection.ltr : null,
              textAlign: i > 0 && !header ? TextAlign.right : null,
              style: TextStyle(fontSize: 13, fontWeight: header ? FontWeight.bold : FontWeight.normal)),
        ),
    ]);

class _Photo extends StatelessWidget {
  const _Photo(this.label, this.path);
  final String label;
  final String? path;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: path == null
                ? const ColoredBox(
                    color: ZillColors.grayLight,
                    child: Center(child: Text('لا توجد صورة', style: TextStyle(color: ZillColors.muted))),
                  )
                : Image.network(CommunityStore.photoUrl(path!), fit: BoxFit.cover),
          ),
        ),
      ]);
}

// ---------- نموذج المشرف ----------
Future<void> showCampaignForm(BuildContext context, {Campaign? campaign}) =>
    showDialog(context: context, builder: (_) => _CampaignForm(campaign: campaign));

class _CampaignForm extends StatefulWidget {
  const _CampaignForm({this.campaign});
  final Campaign? campaign;

  @override
  State<_CampaignForm> createState() => _CampaignFormState();
}

class _CampaignFormState extends State<_CampaignForm> {
  final _formKey = GlobalKey<FormState>();
  late final c = widget.campaign;
  late final _name = TextEditingController(text: c?.name);
  late final _area = TextEditingController(text: c?.areaName);
  late final _lat = TextEditingController(text: c?.point.latitude.toString());
  late final _lng = TextEditingController(text: c?.point.longitude.toString());
  late final _radius = TextEditingController(text: (c?.radiusM ?? 100).toStringAsFixed(0));
  late final _planted = TextEditingController(text: c?.treesPlanted.toString());
  late final _alive = TextEditingController(text: c?.treesAlive?.toString());
  late final _species = TextEditingController(text: c?.species);
  late final _notes = TextEditingController(text: c?.notes);
  late DateTime? _date = c?.plantedOn;
  late TreeCondition _condition = c?.condition ?? TreeCondition.unknown;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final t in [_name, _area, _lat, _lng, _radius, _planted, _alive, _species, _notes]) {
      t.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) => (v?.trim().isEmpty ?? true) ? 'مطلوب' : null;
  String? _number(String? v) => double.tryParse(v?.trim() ?? '') == null ? 'رقم غير صحيح' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null) {
      setState(() => _error = 'اختر تاريخ التنفيذ.');
      return;
    }
    final community = CommunityScope.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    final d = _date!;
    String? text(TextEditingController t) => t.text.trim().isEmpty ? null : t.text.trim();
    try {
      await community.saveCampaign({
        'name': _name.text.trim(),
        'area_name': _area.text.trim(),
        'lat': double.parse(_lat.text.trim()),
        'lng': double.parse(_lng.text.trim()),
        'radius_m': double.parse(_radius.text.trim()),
        'planted_on':
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        'trees_planted': int.parse(_planted.text.trim()),
        'trees_alive': int.tryParse(_alive.text.trim()),
        'tree_species': text(_species),
        'condition': _condition.api,
        'notes': text(_notes),
      }, id: c?.id);
      navigator.pop();
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _d(String label) => InputDecoration(labelText: label, isDense: true);

  @override
  Widget build(BuildContext context) {
    final sites = AreasScope.of(context).sites;
    return AlertDialog(
      title: Text(c == null ? 'حملة جديدة' : 'تعديل الحملة'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: _name, decoration: _d('اسم الحملة'), validator: _required),
              const SizedBox(height: 8),
              if (sites.isNotEmpty)
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  decoration: _d('تعبئة الموقع من مواقع المنصة (اختياري)'),
                  items: [
                    for (final s in sites)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text('${s.district} · ${s.title} · ${fmt(s.areaHa, 1)} هكتار',
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (id) {
                    final s = sites.firstWhere((x) => x.id == id);
                    setState(() {
                      _area.text = s.place == null ? s.district : '${s.district} - ${s.place}';
                      _lat.text = '${s.point.latitude}';
                      _lng.text = '${s.point.longitude}';
                    });
                  },
                ),
              const SizedBox(height: 8),
              TextFormField(controller: _area, decoration: _d('المنطقة'), validator: _required),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextFormField(controller: _lat, decoration: _d('خط العرض'), validator: _number)),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _lng, decoration: _d('خط الطول'), validator: _number)),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _radius, decoration: _d('نصف القطر (متر)'), validator: _number)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextFormField(controller: _planted, decoration: _d('الأشجار المزروعة'), validator: _number)),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _alive, decoration: _d('الأشجار الحية الآن (اختياري)'))),
              ]),
              const SizedBox(height: 8),
              TextFormField(controller: _species, decoration: _d('الأنواع (اختياري)')),
              const SizedBox(height: 8),
              DropdownButtonFormField<TreeCondition>(
                initialValue: _condition,
                decoration: _d('حالة الأشجار'),
                items: [for (final v in TreeCondition.values) DropdownMenuItem(value: v, child: Text(v.label))],
                onChanged: (v) => setState(() => _condition = v!),
              ),
              const SizedBox(height: 8),
              TextFormField(controller: _notes, maxLines: 2, decoration: _d('ملاحظات (اختياري)')),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(_date == null
                      ? 'تاريخ التنفيذ'
                      : '${_date!.year}-${_date!.month}-${_date!.day}'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ')),
      ],
    );
  }
}

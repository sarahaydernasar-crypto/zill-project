import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models/area.dart';
import '../models/planting_site.dart';
import '../services/areas_store.dart';
import '../services/community_store.dart';
import 'campaigns_screen.dart' show showCampaignReport;
import '../theme.dart';
import '../widgets/area_details.dart';
import '../widgets/common.dart';
import '../widgets/site_widgets.dart';

/// لوحة المعلومات والخريطة التفاعلية
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _wideBreakpoint = 900.0;

  final _mapController = MapController();
  final LayerHitNotifier<int> _polygonHits = ValueNotifier(null);

  AreasStore? _store;
  bool _mapReady = false;
  bool _sheetOpen = false;
  int? _lastSelected;
  int _lastAreasHash = 0;
  int? _hoveredId; // المنطقة تحت المؤشر (في الخريطة أو في القائمة)
  int? _lastSelectedSite;
  bool _showSites = true;

  @override
  void initState() {
    super.initState();
    _polygonHits.addListener(_onPolygonHover);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AreasScope.of(context);
    if (store != _store) {
      _store?.removeListener(_onStoreChanged);
      _store = store..addListener(_onStoreChanged);
    }
  }

  @override
  void dispose() {
    _store?.removeListener(_onStoreChanged);
    _polygonHits.dispose();
    super.dispose();
  }

  bool get _isWide => MediaQuery.sizeOf(context).width >= _wideBreakpoint;

  void _onPolygonHover() {
    final hit = _polygonHits.value;
    _setHovered(hit == null || hit.hitValues.isEmpty ? null : hit.hitValues.first);
  }

  void _setHovered(int? id) {
    if (id != _hoveredId && mounted) setState(() => _hoveredId = id);
  }

  void _onStoreChanged() {
    final store = _store!;
    // عند وصول بيانات جديدة نضبط الخريطة على كل المناطق
    final hash = Object.hashAll(store.areas.map((a) => a.id));
    if (hash != _lastAreasHash) {
      _lastAreasHash = hash;
      _fitAll();
    }
    // عند اختيار منطقة (من الخريطة أو القائمة أو صفحة التوصيات)
    if (store.selectedId != _lastSelected) {
      _lastSelected = store.selectedId;
      final area = store.selected;
      if (area != null) {
        _focus(area);
        if (!_isWide && !_sheetOpen) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _openSheet(area));
        }
      }
    }
    if (store.selectedSiteId != _lastSelectedSite) {
      _lastSelectedSite = store.selectedSiteId;
      final site = store.selectedSite;
      if (site != null) {
        if (!_showSites) setState(() => _showSites = true);
        _focusSite(site);
        if (!_isWide) {
          // ننتظر إغلاق نافذة التفاصيل إن كانت مفتوحة
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && !_sheetOpen) _openSiteSheet(site);
          });
        }
      }
    }
  }

  // ---------- الكاميرا ----------
  void _fitAll() {
    if (!_mapReady) return;
    final pts = _store!.areas.expand((a) => a.polygons).expand((p) => p).toList();
    if (pts.length < 2) {
      _mapController.move(AppConfig.cityCenter, AppConfig.cityZoom);
      return;
    }
    _mapController.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(pts),
      padding: const EdgeInsets.all(30),
      maxZoom: 13,
    ));
  }

  /// هامش الكاميرا؛ على الشاشات الكبيرة تغطي بطاقة التفاصيل الجهة اليسرى من الخريطة
  EdgeInsets _focusPadding(double margin) =>
      EdgeInsets.fromLTRB(_isWide ? 344 + margin : margin, margin, margin, margin);

  void _focus(Area a) {
    if (!_mapReady) return;
    final pts = a.polygons.expand((p) => p).toList();
    if (pts.length < 2) return;
    _mapController.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(pts),
      padding: _focusPadding(60),
      maxZoom: 14,
    ));
  }

  /// موضع اسم المنطقة: متوسط رؤوس أكبر مضلع فيها
  LatLng _labelPoint(Area a) {
    final ring = a.polygons.reduce((x, y) => x.length >= y.length ? x : y);
    final lat = ring.map((p) => p.latitude).reduce((x, y) => x + y) / ring.length;
    final lng = ring.map((p) => p.longitude).reduce((x, y) => x + y) / ring.length;
    return LatLng(lat, lng);
  }

  void _focusSite(PlantingSite s) {
    if (!_mapReady) return;
    final pts = s.polygons.expand((p) => p).toList();
    if (pts.length < 2) {
      _mapController.move(s.point, 16);
      return;
    }
    _mapController.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(pts),
      padding: _focusPadding(120),
      maxZoom: 17,
    ));
  }

  Future<void> _openSiteSheet(PlantingSite site) async {
    _sheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: ZillColors.grayLight,
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: SiteCard(site: site),
      ),
    );
    _sheetOpen = false;
    _store?.selectSite(null);
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + delta);
  }

  Future<void> _openSheet(Area area) async {
    if (!mounted) return;
    _sheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: ZillColors.grayLight,
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: AreaDetails(area: area),
      ),
    );
    _sheetOpen = false;
    _store?.select(null);
  }

  void _selectAgain(int id) {
    // إعادة الضغط على نفس المنطقة تفتح التفاصيل مرة أخرى
    if (_store!.selectedId == id) _store!.select(null);
    _store!.select(id);
  }

  void _handleTap() {
    final hit = _polygonHits.value;
    if (hit == null || hit.hitValues.isEmpty) return;
    _selectAgain(hit.hitValues.first);
  }

  // ---------- الواجهة ----------
  Widget _buildSubAreaList(AreasStore store, Area open) {
    final subs = store.subAreasOf(open);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () {
            store.closeDistrict();
            _fitAll();
          },
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('كل الأقضية'),
          style: TextButton.styleFrom(foregroundColor: ZillColors.green),
        ),
        Text('مناطق ${open.name}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
        const Text('مرتبة من الأقل غطاءً نباتياً إلى الأكثر، والأولوية نسبية بين مناطق هذا القضاء.',
            style: TextStyle(fontSize: 13, color: ZillColors.muted)),
        const SizedBox(height: 10),
        if (subs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('لا تتوفر مناطق داخلية لهذا القضاء بعد.',
                  style: TextStyle(color: ZillColors.muted)),
            ),
          ),
        for (final (i, a) in subs.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MouseRegion(
              onEnter: (_) => _setHovered(a.id),
              onExit: (_) => _setHovered(null),
              child: _AreaRow(
                rank: i + 1,
                area: a,
                showPriority: true,
                highlighted: a.id == store.selectedId || a.id == _hoveredId,
                onTap: () => _selectAgain(a.id),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AreasScope.of(context);

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= _wideBreakpoint;
      final map = _buildMapCard(store, wide);

      if (wide) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            if (store.status == LoadStatus.error)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ErrorBanner(message: store.error!, onRetry: store.load),
              ),
            StatsGrid(store: store),
            const SizedBox(height: 16),
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  width: 380,
                  child: Card(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildAreaList(store),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: map),
              ]),
            ),
          ]),
        );
      }

      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (store.status == LoadStatus.error)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ErrorBanner(message: store.error!, onRetry: store.load),
            ),
          StatsGrid(store: store),
          const SizedBox(height: 12),
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.55, child: map),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: _buildAreaList(store))),
        ],
      );
    });
  }

  Widget _buildMapCard(AreasStore store, bool wide) {
    final selected = store.selected;
    final selectedSite = store.selectedSite;
    final hovered = store.areaById(_hoveredId);
    final visible = store.visibleAreas;
    final hasShapes = visible.any((a) => a.polygons.isNotEmpty);
    final open = store.drilled;

    // المنطقة المختارة أو تحت المؤشر تُرسم أخيراً حتى تظهر حدودها كاملة
    int rank(Area a) => a.id == store.selectedId ? 2 : (a.id == _hoveredId ? 1 : 0);
    final ordered = [...visible]..sort((a, b) => rank(a).compareTo(rank(b)));

    final polygons = <Polygon<int>>[
      for (final a in ordered)
        for (var i = 0; i < a.polygons.length; i++)
          Polygon<int>(
            points: a.polygons[i],
            // عند فتح قضاء تخفت بقية الأقضية
            color: a.coverageColor.withValues(alpha: switch (rank(a)) {
              2 => 0.85,
              1 => 0.75,
              _ => open != null && a.district == null ? 0.2 : 0.6,
            }),
            borderColor: rank(a) > 0 ? ZillColors.text : Colors.white,
            borderStrokeWidth: rank(a) > 0 ? 3 : 1.5,
            hitValue: a.id,
          ),
    ];

    final campaignMarkers = <Marker>[
      for (final c in CommunityScope.of(context).campaigns)
        Marker(
          point: c.point,
          width: 34,
          height: 34,
          child: Tooltip(
            message: c.name,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => showCampaignReport(context, c),
                child: const CircleAvatar(
                  backgroundColor: Color(0xFF1D4ED8),
                  child: Icon(Icons.forest, size: 20, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
    ];

    final shownSites = open == null ? store.sites : store.sitesIn(open);

    final sitePolygons = <Polygon>[
      // حدود القضاء المفتوح
      if (open != null)
        for (final ring in open.polygons)
          Polygon(
            points: ring,
            color: Colors.transparent,
            borderColor: ZillColors.greenDark,
            borderStrokeWidth: 3,
          ),
      if (_showSites)
        for (final s in shownSites)
          for (final ring in s.polygons)
            Polygon(
              points: ring,
              color: ZillColors.green.withValues(alpha: s.id == store.selectedSiteId ? 0.85 : 0.7),
              borderColor: s.id == store.selectedSiteId ? ZillColors.text : ZillColors.greenDark,
              borderStrokeWidth: s.id == store.selectedSiteId ? 3 : 1.5,
            ),
    ];

    final siteMarkers = <Marker>[
      if (_showSites)
        for (final s in shownSites)
          Marker(
            point: s.point,
            width: 30,
            height: 30,
            alignment: Alignment.topCenter,
            child: Tooltip(
              message: s.title,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    if (store.selectedSiteId == s.id) store.selectSite(null);
                    store.selectSite(s.id);
                  },
                  child: Icon(
                    Icons.place,
                    size: 30,
                    color: s.id == store.selectedSiteId ? ZillColors.text : ZillColors.greenDark,
                    shadows: const [Shadow(color: Colors.white, blurRadius: 4)],
                  ),
                ),
              ),
            ),
          ),
    ];

    // الأسماء عناصر واجهة عادية حتى تأخذ الخط العربي من الثيم
    final labels = <Marker>[
      for (final a in visible)
        // عند فتح قضاء نكتفي بأسماء مناطقه
        if (a.polygons.isNotEmpty && (open == null || a.district != null))
          Marker(
            point: _labelPoint(a),
            width: 130,
            height: 26,
            child: IgnorePointer(
              child: Center(
                child: Text(
                  a.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
              ),
            ),
          ),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: AppConfig.cityCenter,
            initialZoom: AppConfig.cityZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (_, _) {
              store.select(null);
              store.selectSite(null);
            },
            onMapReady: () {
              _mapReady = true;
              _fitAll();
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.zill.zill_app',
            ),
            MouseRegion(
              hitTestBehavior: HitTestBehavior.deferToChild,
              cursor: SystemMouseCursors.click,
              onExit: (_) => _setHovered(null),
              child: GestureDetector(
                onTap: _handleTap,
                child: PolygonLayer<int>(polygons: polygons, hitNotifier: _polygonHits),
              ),
            ),
            PolygonLayer(polygons: sitePolygons),
            MarkerLayer(markers: labels),
            MarkerLayer(markers: siteMarkers),
            MarkerLayer(markers: campaignMarkers),
            const SimpleAttributionWidget(source: Text('OpenStreetMap')),
          ],
        ),

        // أزرار التكبير والتصغير وإعادة الضبط
        PositionedDirectional(
          start: 12,
          top: 12,
          child: _MapControls(
            onZoomIn: () => _zoomBy(1),
            onZoomOut: () => _zoomBy(-1),
            showSites: _showSites,
            onToggleSites: () => setState(() => _showSites = !_showSites),
            onReset: () {
              store.closeDistrict();
              _fitAll();
            },
          ),
        ),

        // بطاقة سريعة للمنطقة تحت المؤشر
        if (hovered != null && hovered.id != store.selectedId)
          PositionedDirectional(
            start: 64,
            top: 12,
            child: IgnorePointer(child: _HoverCard(area: hovered)),
          ),

        const PositionedDirectional(start: 12, bottom: 34, child: CoverageLegend()),

        // تفاصيل المنطقة المختارة فوق الخريطة، والقائمة تبقى ظاهرة بجانبها
        if (wide && selected != null)
          PositionedDirectional(
            end: 12,
            top: 12,
            bottom: 34,
            width: 320,
            child: Material(
              color: ZillColors.grayLight,
              elevation: 4,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                child: AreaDetails(area: selected, onClose: () => store.select(null)),
              ),
            ),
          ),

        if (wide && selectedSite != null)
          PositionedDirectional(
            end: 12,
            top: 12,
            bottom: 34,
            width: 320,
            child: Material(
              color: ZillColors.grayLight,
              elevation: 4,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                child: SiteCard(site: selectedSite, onClose: () => store.selectSite(null)),
              ),
            ),
          ),

        if (store.status == LoadStatus.loaded && !hasShapes)
          const Center(child: _NoShapesNotice()),

        if (store.status == LoadStatus.loading)
          const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator()),
      ]),
    );
  }

  Widget _buildAreaList(AreasStore store) {
    final open = store.drilled;
    if (open != null) return _buildSubAreaList(store, open);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('المناطق الأقل تشجيراً',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
        const Text('مرتبة من الأقل غطاءً نباتياً إلى الأكثر. اضغط على منطقة لعرض تفاصيلها.',
            style: TextStyle(fontSize: 13, color: ZillColors.muted)),
        const SizedBox(height: 10),
        if (store.areas.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                switch (store.status) {
                  LoadStatus.loading || LoadStatus.idle => 'جارٍ تحميل البيانات…',
                  LoadStatus.error => 'لا توجد بيانات.',
                  LoadStatus.loaded => 'لا توجد مناطق في قاعدة البيانات بعد.',
                },
                style: const TextStyle(color: ZillColors.muted),
              ),
            ),
          ),
        for (final (i, a) in store.byVegetation.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MouseRegion(
              onEnter: (_) => _setHovered(a.id),
              onExit: (_) => _setHovered(null),
              child: _AreaRow(
                rank: i + 1,
                area: a,
                highlighted: a.id == store.selectedId || a.id == _hoveredId,
                onTap: () => _selectAgain(a.id),
              ),
            ),
          ),
      ],
    );
  }
}

/// صف منطقة في القائمة: الترتيب والاسم ودرجة الحرارة وNDVI، ومستوى الأولوية عند الحاجة
class _AreaRow extends StatelessWidget {
  const _AreaRow({
    required this.rank,
    required this.area,
    required this.highlighted,
    required this.onTap,
    this.showPriority = false,
  });

  final bool showPriority;
  final int rank;
  final Area area;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = area.coverageColor;
    final onColor = color.computeLuminance() > 0.4 ? ZillColors.text : Colors.white;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: highlighted ? ZillColors.green : Colors.transparent, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: color,
              child: Text('$rank',
                  style: TextStyle(color: onColor, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(area.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if (showPriority) ...[
                  const SizedBox(height: 4),
                  PriorityBadge(area.priorityLevel),
                ],
              ]),
            ),
            const SizedBox(width: 8),
            _Metric(label: 'الحرارة', value: deg(area.temperature)),
            const SizedBox(width: 12),
            _Metric(label: 'NDVI', value: fmt(area.ndvi, 2)),
          ]),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value,
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      Text(label, style: const TextStyle(fontSize: 11, color: ZillColors.muted)),
    ]);
  }
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
    required this.showSites,
    required this.onToggleSites,
  });
  final bool showSites;
  final VoidCallback onToggleSites;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        IconButton(onPressed: onZoomIn, icon: const Icon(Icons.add), tooltip: 'تكبير'),
        IconButton(onPressed: onZoomOut, icon: const Icon(Icons.remove), tooltip: 'تصغير'),
        IconButton(onPressed: onReset, icon: const Icon(Icons.fit_screen), tooltip: 'عرض كل المناطق'),
        IconButton(
          onPressed: onToggleSites,
          icon: Icon(showSites ? Icons.place : Icons.place_outlined,
              color: showSites ? ZillColors.green : null),
          tooltip: showSites ? 'إخفاء مواقع التشجير' : 'إظهار مواقع التشجير',
        ),
      ]),
    );
  }
}

class _HoverCard extends StatelessWidget {
  const _HoverCard({required this.area});
  final Area area;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(area.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _Metric(label: 'الحرارة', value: deg(area.temperature)),
              const SizedBox(width: 16),
              _Metric(label: 'NDVI', value: fmt(area.ndvi, 2)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _NoShapesNotice extends StatelessWidget {
  const _NoShapesNotice();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'حدود المناطق غير متوفرة بعد.\nستظهر ملوّنة على الخريطة بعد إدخال نتائج التحليل.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

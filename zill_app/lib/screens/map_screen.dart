import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models/area.dart';
import '../services/areas_store.dart';
import '../theme.dart';
import '../widgets/area_details.dart';
import '../widgets/common.dart';

/// لوحة المعلومات والخريطة
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _wideBreakpoint = 900.0;

  final _mapController = MapController();
  final LayerHitNotifier<int> _polygonHits = ValueNotifier(null);
  final LayerHitNotifier<int> _circleHits = ValueNotifier(null);

  AreasStore? _store;
  bool _mapReady = false;
  bool _sheetOpen = false;
  int? _lastSelected;
  int _lastAreasHash = 0;

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
    super.dispose();
  }

  bool get _isWide => MediaQuery.sizeOf(context).width >= _wideBreakpoint;

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
  }

  // ---------- الكاميرا ----------
  List<LatLng> _pointsOf(Area a) {
    if (a.polygons.isNotEmpty) return a.polygons.expand((p) => p).toList();
    if (a.point != null) return [a.point!];
    if (_store!.areas.length == 1) return [AppConfig.cityCenter];
    return [];
  }

  void _fitAll() {
    if (!_mapReady) return;
    final pts = _store!.areas.expand(_pointsOf).toList();
    if (pts.length < 2) {
      _mapController.move(pts.isEmpty ? AppConfig.cityCenter : pts.first, AppConfig.cityZoom);
      return;
    }
    _mapController.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(pts),
      padding: const EdgeInsets.all(30),
      maxZoom: 13,
    ));
  }

  void _focus(Area a) {
    if (!_mapReady) return;
    final pts = _pointsOf(a);
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      _mapController.move(pts.first, a.polygons.isEmpty && a.point == null ? AppConfig.cityZoom : 13);
    } else {
      _mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(pts),
        padding: const EdgeInsets.all(40),
        maxZoom: 14,
      ));
    }
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

  void _handleHit(LayerHitNotifier<int> notifier) {
    final hit = notifier.value;
    if (hit == null || hit.hitValues.isEmpty) return;
    final id = hit.hitValues.first;
    // إعادة الضغط على نفس المنطقة تفتح التفاصيل مرة أخرى
    if (_store!.selectedId == id) _store!.select(null);
    _store!.select(id);
  }

  // ---------- الواجهة ----------
  @override
  Widget build(BuildContext context) {
    final store = AreasScope.of(context);

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= _wideBreakpoint;
      final map = _buildMapCard(store);

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
                Expanded(child: map),
                const SizedBox(width: 16),
                SizedBox(width: 360, child: Card(child: _buildSidePanel(store))),
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

  Widget _buildMapCard(AreasStore store) {
    final polygons = <Polygon<int>>[];
    final circles = <CircleMarker<int>>[];
    final single = store.areas.length == 1;

    for (final a in store.areas) {
      final selected = a.id == store.selectedId;
      final fill = a.color.withValues(alpha: selected ? 0.6 : 0.45);
      final border = selected ? ZillColors.greenDark : a.color;
      final width = selected ? 4.0 : 2.0;

      if (a.polygons.isNotEmpty) {
        for (final ring in a.polygons) {
          polygons.add(Polygon<int>(
            points: ring,
            color: fill,
            borderColor: border,
            borderStrokeWidth: width,
            hitValue: a.id,
          ));
        }
      } else if (a.point != null) {
        circles.add(CircleMarker<int>(
          point: a.point!,
          radius: 14,
          color: fill,
          borderColor: border,
          borderStrokeWidth: width,
          hitValue: a.id,
        ));
      } else if (single) {
        // منطقة واحدة بدون إحداثيات (مثل «محافظة بغداد») تُعرض على مركز المدينة
        circles.add(CircleMarker<int>(
          point: AppConfig.cityCenter,
          radius: 18000,
          useRadiusInMeter: true,
          color: fill,
          borderColor: border,
          borderStrokeWidth: width,
          hitValue: a.id,
        ));
      }
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: AppConfig.cityCenter,
            initialZoom: AppConfig.cityZoom,
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
            GestureDetector(
              onTap: () => _handleHit(_polygonHits),
              child: PolygonLayer<int>(polygons: polygons, hitNotifier: _polygonHits),
            ),
            GestureDetector(
              onTap: () => _handleHit(_circleHits),
              child: CircleLayer<int>(circles: circles, hitNotifier: _circleHits),
            ),
            const SimpleAttributionWidget(source: Text('OpenStreetMap')),
          ],
        ),
        const PositionedDirectional(start: 12, bottom: 12, child: HeatLegend()),
        if (store.status == LoadStatus.loading)
          const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator()),
      ]),
    );
  }

  Widget _buildSidePanel(AreasStore store) {
    final area = store.selected;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: area != null
          ? AreaDetails(area: area, onClose: () => store.select(null))
          : _buildAreaList(store),
    );
  }

  Widget _buildAreaList(AreasStore store) {
    final noGeo = store.areas.length > 1 ? store.areas.where((a) => !a.hasLocation).length : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('المناطق',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
        const Text('اضغط على منطقة في الخريطة أو في القائمة لعرض تفاصيلها.',
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
        for (final a in store.byTemperature)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: a.id == store.selectedId ? ZillColors.green : Colors.transparent,
                    width: 2),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: CircleAvatar(radius: 7, backgroundColor: a.color),
                minLeadingWidth: 14,
                title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text(deg(a.temperature),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                onTap: () {
                  if (store.selectedId == a.id) store.select(null);
                  store.select(a.id);
                },
              ),
            ),
          ),
        if (noGeo > 0)
          Text('$noGeo منطقة لا تملك إحداثيات بعد، لذلك تظهر في القائمة فقط.',
              style: const TextStyle(fontSize: 13, color: ZillColors.muted)),
      ],
    );
  }
}

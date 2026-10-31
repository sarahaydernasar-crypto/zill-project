import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/about_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/recommendations_screen.dart';
import 'services/areas_store.dart';
import 'theme.dart';
import 'widgets/common.dart';

void main() {
  final store = AreasStore()..load();
  runApp(ZillApp(store: store));
}

class ZillApp extends StatelessWidget {
  const ZillApp({super.key, required this.store});
  final AreasStore store;

  @override
  Widget build(BuildContext context) {
    final theme = buildZillTheme();
    return AreasScope(
      store: store,
      child: MaterialApp(
        title: 'ظِلّ',
        debugShowCheckedModeBanner: false,
        theme: theme.copyWith(textTheme: GoogleFonts.tajawalTextTheme(theme.textTheme)),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const ZillShell(),
      ),
    );
  }
}

/// الهيكل الرئيسي: شريط تنقل سفلي على الموبايل وجانبي على الشاشات الكبيرة
class ZillShell extends StatefulWidget {
  const ZillShell({super.key});

  @override
  State<ZillShell> createState() => _ZillShellState();
}

class _ZillShellState extends State<ZillShell> {
  // على الويب يمكن فتح صفحة مباشرة: ?tab=map | recommendations | about
  int _index = const ['home', 'map', 'recommendations', 'about']
      .indexOf(Uri.base.queryParameters['tab'] ?? 'home')
      .clamp(0, 3);

  static const _destinations = [
    (icon: Icons.home_outlined, selected: Icons.home, label: 'الرئيسية'),
    (icon: Icons.map_outlined, selected: Icons.map, label: 'الخريطة'),
    (icon: Icons.park_outlined, selected: Icons.park, label: 'التوصيات'),
    (icon: Icons.info_outline, selected: Icons.info, label: 'عن ظِلّ'),
  ];

  void _go(int i) => setState(() => _index = i);

  void _showOnMap(int areaId) {
    _go(1);
    final store = AreasScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (store.selectedId == areaId) store.select(null);
      store.select(areaId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final pages = [
      HomeScreen(onExploreMap: () => _go(1)),
      const MapScreen(),
      RecommendationsScreen(onShowOnMap: _showOnMap),
      const AboutScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: wide ? 64 : 56,
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          ZillLogo(size: 34),
          SizedBox(width: 10),
          Text('ظِلّ', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        ]),
        actions: [
          IconButton(
            tooltip: 'تحديث البيانات',
            onPressed: AreasScope.of(context).load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Row(children: [
        if (wide)
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: _go,
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selected, color: ZillColors.green),
                  label: Text(d.label),
                ),
            ],
          ),
        if (wide) const VerticalDivider(width: 1),
        Expanded(child: IndexedStack(index: _index, children: pages)),
      ]),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _go,
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected, color: ZillColors.green),
                    label: d.label,
                  ),
              ],
            ),
    );
  }
}

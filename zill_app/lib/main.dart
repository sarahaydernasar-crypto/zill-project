import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/about_screen.dart';
import 'screens/campaigns_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/recommendations_screen.dart';
import 'screens/reports_screen.dart';
import 'services/areas_store.dart';
import 'services/community_store.dart';
import 'theme.dart';
import 'widgets/admin_login.dart';
import 'widgets/assistant_sheet.dart';
import 'widgets/ghars_logo.dart';

void main() {
  final store = AreasStore()..load();
  final community = CommunityStore()..loadCampaigns();
  runApp(ZillApp(store: store, community: community));
}

class ZillApp extends StatelessWidget {
  const ZillApp({super.key, required this.store, required this.community});
  final AreasStore store;
  final CommunityStore community;

  @override
  Widget build(BuildContext context) {
    final theme = buildZillTheme();
    return AreasScope(
      store: store,
      child: CommunityScope(
        store: community,
        child: MaterialApp(
          title: 'ظِلّ',
          debugShowCheckedModeBanner: false,
          theme: theme.copyWith(
            textTheme: GoogleFonts.tajawalTextTheme(theme.textTheme),
          ),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const ZillShell(),
        ),
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
  // على الويب يمكن فتح صفحة مباشرة: ?tab=map | recommendations | reports | campaigns
  int _index = const [
    'home',
    'map',
    'recommendations',
    'reports',
    'campaigns',
  ].indexOf(Uri.base.queryParameters['tab'] ?? 'home').clamp(0, 4);

  static const _destinations = [
    (icon: Icons.home_outlined, selected: Icons.home, label: 'الرئيسية'),
    (icon: Icons.map_outlined, selected: Icons.map, label: 'الخريطة'),
    (icon: Icons.park_outlined, selected: Icons.park, label: 'التوصيات'),
    (
      icon: Icons.campaign_outlined,
      selected: Icons.campaign,
      label: 'البلاغات',
    ),
    (icon: Icons.forest_outlined, selected: Icons.forest, label: 'الحملات'),
  ];

  final _chat = <ChatMessage>[];

  void _go(int i) => setState(() => _index = i);

  void _openAssistant() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => AssistantSheet(
      messages: _chat,
      onShowArea: _showOnMap,
      onShowSite: _showSiteOnMap,
    ),
  );

  void _showSiteOnMap(int siteId) {
    _go(1);
    final store = AreasScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (store.selectedSiteId == siteId) store.selectSite(null);
      store.selectSite(siteId);
    });
  }

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
      HomeScreen(
        onExploreMap: () => _go(1),
        onRecommendations: () => _go(2),
        onShowOnMap: _showOnMap,
      ),
      const MapScreen(),
      RecommendationsScreen(
        onShowOnMap: _showOnMap,
        onShowSite: _showSiteOnMap,
      ),
      const ReportsScreen(),
      const CampaignsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: const Text(
          'ظِلّ',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث البيانات',
            onPressed: () {
              AreasScope.of(context).load();
              CommunityScope.of(context).loadCampaigns();
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'عن ظِلّ',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('عن ظِلّ')),
                  body: const AboutScreen(),
                ),
              ),
            ),
            icon: const Icon(Icons.info_outline),
          ),
          const AdminButton(),
        ],
      ),
      body: Row(
        children: [
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
          Expanded(
            child: IndexedStack(index: _index, children: pages),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAssistant,
        backgroundColor: ZillColors.greenDark,
        foregroundColor: Colors.white,
        icon: const GharsLogo(size: 32),
        label: const Text('غَرْس', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
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

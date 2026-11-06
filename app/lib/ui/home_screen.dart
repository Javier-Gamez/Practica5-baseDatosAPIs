import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import 'lists_tabs.dart';
import 'notes_tab.dart';
import 'profile_tab.dart';
import 'search_tab.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  final _searchKey = GlobalKey<SearchTabState>();

  @override
  void initState() {
    super.initState();
    context.read<AppState>().loadLastSync();
  }

  @override
  Widget build(BuildContext context) {
    // Se observa AppState para refrescar listas cuando termina una sincronización.
    final sync = context.select<AppState, Object?>((s) => (s.lastSync, s.pendingCount));
    final tabs = <Widget>[
      SearchTab(key: _searchKey),
      FavoritesTab(key: ValueKey('fav$sync')),
      HistoryTab(
        key: ValueKey('his$sync'),
        onSelect: (q) {
          setState(() => _index = 0);
          WidgetsBinding.instance.addPostFrameCallback((_) => _searchKey.currentState?.run(q));
        },
      ),
      RecommendationsTab(key: ValueKey('rec$_index')),
      const NotesTab(),
      const ProfileTab(),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Series'), toolbarHeight: 48),
      body: Column(children: [
        const StatusBanner(),
        Expanded(child: IndexedStack(index: _index, children: tabs)),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
          NavigationDestination(icon: Icon(Icons.favorite), label: 'Favoritos'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
          NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'Para ti'),
          NavigationDestination(icon: Icon(Icons.note), label: 'Notas'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

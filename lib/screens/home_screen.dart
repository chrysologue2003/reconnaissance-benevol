import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/action_model.dart';
import '../providers/action_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/action_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const categories = ['Tous', 'Nettoyage', 'Aide', 'Soutien scolaire', 'Dons', 'Événements', 'Autres'];
  String _searchQuery = '';
  String _dateFilter = 'Tout'; // 'Tout', 'Semaine', 'Mois'
  final TextEditingController _searchController = TextEditingController();

  bool _isWithinWeek(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    return difference <= 7; // Permet les skew temporels (date légèrement dans le futur)
  }

  bool _isWithinMonth(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    return difference <= 30; // Permet les skew temporels (date légèrement dans le futur)
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final actionProvider = context.watch<ActionProvider>();
    final userId = authProvider.user?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fil d\'actualité',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => context.go('/notifications'),
            icon: const Icon(Icons.notifications_active_outlined),
          ),
          IconButton(
            onPressed: () => context.go('/profile'),
            icon: CircleAvatar(
              radius: 14,
              backgroundImage: authProvider.user?.photoUrl.isNotEmpty == true
                  ? NetworkImage(authProvider.user!.photoUrl)
                  : null,
              child: authProvider.user?.photoUrl.isEmpty == true
                  ? Text(authProvider.user?.name.isNotEmpty == true ? authProvider.user!.name[0].toUpperCase() : 'B', style: const TextStyle(fontSize: 10))
                  : null,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/post'),
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('Poster une action'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              accountName: Text(
                authProvider.user?.name ?? 'Invité',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              accountEmail: Text(authProvider.user?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.onPrimary,
                backgroundImage: authProvider.user?.photoUrl.isNotEmpty == true
                    ? NetworkImage(authProvider.user!.photoUrl)
                    : null,
                child: authProvider.user?.photoUrl.isEmpty == true
                    ? Text(
                        authProvider.user?.name.isNotEmpty == true ? authProvider.user!.name[0].toUpperCase() : 'B',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                      )
                    : null,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.leaderboard),
              title: const Text('Classement & Podium'),
              onTap: () {
                Navigator.pop(context);
                context.go('/leaderboard');
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Historique complet'),
              onTap: () {
                Navigator.pop(context);
                context.go('/profile'); // L'historique riche est sur le profil
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Paramètres'),
              onTap: () {
                Navigator.pop(context);
                context.go('/profile'); // Nous intégrerons l'option Paramètres dans le profil/header
              },
            ),
            const Divider(),
            if (authProvider.isAdmin) ...[
              StreamBuilder<List<VolunteerAction>>(
                stream: context.read<ActionProvider>().pendingStream,
                builder: (context, snapshot) {
                  final pendingCount = snapshot.data?.length ?? 0;
                  return ListTile(
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.admin_panel_settings,
                            color: Colors.orange),
                        if (pendingCount > 0)
                          Positioned(
                            top: -4,
                            right: -6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                  minWidth: 16, minHeight: 16),
                              child: Text(
                                pendingCount > 99
                                    ? '99+'
                                    : '$pendingCount',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: const Text('Dashboard Admin',
                        style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold)),
                    subtitle: pendingCount > 0
                        ? Text(
                            '$pendingCount action${pendingCount > 1 ? 's' : ''} en attente',
                            style: const TextStyle(
                                color: Colors.red,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/admin');
                    },
                  );
                },
              ),
              const Divider(),
            ],
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await authProvider.logout();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Barre de recherche et de filtres
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher une action ou lieu...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val.trim().toLowerCase());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.filter_list),
                  tooltip: 'Filtrer par date',
                  onSelected: (String value) {
                    setState(() => _dateFilter = value);
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem(
                      value: 'Tout',
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: _dateFilter == 'Tout' ? Theme.of(context).colorScheme.primary : Colors.grey),
                          const SizedBox(width: 8),
                          const Text('Toutes les dates'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'Semaine',
                      child: Row(
                        children: [
                          Icon(Icons.view_week, color: _dateFilter == 'Semaine' ? Theme.of(context).colorScheme.primary : Colors.grey),
                          const SizedBox(width: 8),
                          const Text('Cette semaine'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'Mois',
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month, color: _dateFilter == 'Mois' ? Theme.of(context).colorScheme.primary : Colors.grey),
                          const SizedBox(width: 8),
                          const Text('Ce mois-ci'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Ligne des catégories horizontalement
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: categories.map((category) {
                final isSelected = actionProvider.selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (_) => actionProvider.setCategory(category),
                    selectedColor: Theme.of(context).colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Flux d'actions principal
          Expanded(
            child: StreamBuilder<List<VolunteerAction>>(
              stream: actionProvider.actionsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  // Affiche l'erreur réelle dans la console pour faciliter le débogage
                  debugPrint('🔴 Erreur chargement fil d\'actualité : ${snapshot.error}');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          const Text(
                            'Erreur lors du chargement des actions.',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '⚠️ Si l\'erreur mentionne un index manquant,\'\nouvrez le lien dans les logs Flutter pour le créer.',
                            style: TextStyle(color: Colors.orange, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                var actions = snapshot.data ?? [];
                
                // 1. Filtrer localement par recherche (titre, description, lieu)
                if (_searchQuery.isNotEmpty) {
                  actions = actions.where((action) {
                    return action.title.toLowerCase().contains(_searchQuery) ||
                        action.description.toLowerCase().contains(_searchQuery) ||
                        action.location.toLowerCase().contains(_searchQuery);
                  }).toList();
                }

                // 2. Filtrer par date
                if (_dateFilter == 'Semaine') {
                  actions = actions.where((action) => _isWithinWeek(action.datePublication.toDate())).toList();
                } else if (_dateFilter == 'Mois') {
                  actions = actions.where((action) => _isWithinMonth(action.datePublication.toDate())).toList();
                }

                if (actions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'Aucune action ne correspond à vos critères.',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: actions.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemBuilder: (context, index) {
                    final action = actions[index];
                    return ActionCard(
                      action: action,
                      currentUserId: userId,
                      onLike: () => actionProvider.toggleLike(action, userId),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

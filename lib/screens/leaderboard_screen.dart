import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/action_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/leaderboard_card.dart';

class LeaderboardUser {
  final String uid;
  final String name;
  final String photoUrl;
  final int points;
  final String city;
  final List<String> badges;

  LeaderboardUser({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.points,
    required this.city,
    required this.badges,
  });
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isWithinWeek(DateTime date) {
    final now = DateTime.now();
    return now.difference(date).inDays <= 7;
  }

  bool _isWithinMonth(DateTime date) {
    final now = DateTime.now();
    return now.difference(date).inDays <= 30;
  }

  // --- AGRÉGATION DYNAMIQUE ---
  List<LeaderboardUser> _aggregatePoints(List<VolunteerAction> actions, List<VolunteerUser> allUsers, String period) {
    // Filtrer les actions par période
    var filteredActions = actions.where((a) => a.status == 'validé').toList();
    if (period == 'Semaine') {
      filteredActions = filteredActions.where((a) => _isWithinWeek(a.datePublication.toDate())).toList();
    } else if (period == 'Mois') {
      filteredActions = filteredActions.where((a) => _isWithinMonth(a.datePublication.toDate())).toList();
    }

    // Calculer les points par utilisateur
    final Map<String, int> pointsMap = {};
    for (final a in filteredActions) {
      // 10 pts par action validée, 2 pts par like
      final pts = 10 + (a.likes.length * 2);
      pointsMap[a.userId] = (pointsMap[a.userId] ?? 0) + pts;
    }

    // Mapper avec les infos utilisateur de la DB
    final List<LeaderboardUser> leaderboard = [];
    for (final u in allUsers) {
      final periodPoints = pointsMap[u.uid] ?? 0;
      if (periodPoints > 0) {
        leaderboard.add(LeaderboardUser(
          uid: u.uid,
          name: u.name,
          photoUrl: u.photoUrl,
          points: periodPoints,
          city: u.city,
          badges: u.badges,
        ));
      }
    }

    // Trier décroissant
    leaderboard.sort((a, b) => b.points.compareTo(a.points));
    return leaderboard;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<AuthProvider>().user?.uid;
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classement & Podium', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Semaine'),
            Tab(text: 'Mois'),
            Tab(text: 'Tous les temps'),
          ],
        ),
      ),
      body: StreamBuilder<List<VolunteerUser>>(
        stream: service.streamTopUsers(), // Top users
        builder: (context, usersSnapshot) {
          return StreamBuilder<List<VolunteerAction>>(
            stream: service.streamValidatedActions(), // Toutes les actions validées
            builder: (context, actionsSnapshot) {
              if (usersSnapshot.connectionState == ConnectionState.waiting ||
                  actionsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allUsers = usersSnapshot.data ?? [];
              final allActions = actionsSnapshot.data ?? [];

              // Agrégation par onglet
              final weeklyData = _aggregatePoints(allActions, allUsers, 'Semaine');
              final monthlyData = _aggregatePoints(allActions, allUsers, 'Mois');
              
              // Tous les temps (on prend direct les points totaux de la table users)
              final allTimeData = allUsers
                  .map((u) => LeaderboardUser(
                        uid: u.uid,
                        name: u.name,
                        photoUrl: u.photoUrl,
                        points: u.points,
                        city: u.city,
                        badges: u.badges,
                      ))
                  .toList();
              allTimeData.sort((a, b) => b.points.compareTo(a.points));

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildLeaderboardView(weeklyData, currentUserId),
                  _buildLeaderboardView(monthlyData, currentUserId),
                  _buildLeaderboardView(allTimeData, currentUserId),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLeaderboardView(List<LeaderboardUser> users, String? currentUserId) {
    if (users.isEmpty) {
      return const Center(
        child: Text(
          'Aucune action validée sur cette période.',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    // Séparer le podium (Top 3) et la liste
    final podiumUsers = users.take(3).toList();
    final remainingUsers = users.skip(3).toList();

    return Column(
      children: [
        const SizedBox(height: 16),
        // Section Podium
        _buildPodium(podiumUsers),
        const SizedBox(height: 16),
        const Divider(height: 1),
        // Section Liste restante
        Expanded(
          child: ListView.builder(
            itemCount: remainingUsers.length,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemBuilder: (context, index) {
              final user = remainingUsers[index];
              final rank = index + 4;
              
              // Convertir temporairement LeaderboardUser en VolunteerUser pour le widget
              final vUser = VolunteerUser(
                uid: user.uid,
                name: user.name,
                email: '',
                photoUrl: user.photoUrl,
                city: user.city,
                points: user.points,
                badges: user.badges,
                dateJoined: Timestamp.now(),
              );

              return LeaderboardCard(
                rank: rank,
                user: vUser,
                highlight: user.uid == currentUserId,
              );
            },
          ),
        ),
      ],
    );
  }

  // --- COMPOSANT GRAPHlique PODIUM 3D/DESIGN ---
  Widget _buildPodium(List<LeaderboardUser> top3) {
    if (top3.isEmpty) return const SizedBox();

    final first = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2ème Place (A gauche)
          if (second != null) _buildPodiumCol(second, 2, 90, Colors.grey.shade400) else const SizedBox(width: 80),

          // 1ère Place (Au centre, plus grand)
          if (first != null) _buildPodiumCol(first, 1, 120, Colors.amber.shade600) else const SizedBox(width: 90),

          // 3ème Place (A droite)
          if (third != null) _buildPodiumCol(third, 3, 75, Colors.amber.shade800) else const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildPodiumCol(LeaderboardUser user, int rank, double height, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Avatar avec couronne / badge
        Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: rank == 1 ? 36 : 28,
              backgroundColor: color.withValues(alpha: 0.3),
              child: CircleAvatar(
                radius: rank == 1 ? 32 : 24,
                backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
                child: user.photoUrl.isEmpty ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : 'B') : null,
              ),
            ),
            Positioned(
              top: -8,
              child: Icon(
                Icons.emoji_events,
                size: rank == 1 ? 24 : 18,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          user.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${user.points} pts',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 8),
        // Socle en 3D
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.8), color],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

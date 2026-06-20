import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/action_model.dart';
import '../../providers/action_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/stats_card.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
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

  // --- DIALOGUE D'ÉVALUATION (VALIDATION / REJET AVEC COMMENTAIRE) ---
  void _showEvaluationDialog(BuildContext context, VolunteerAction action, bool isApprove) {
    final actionProvider = context.read<ActionProvider>();
    final commentController = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isApprove ? 'Valider l\'action' : 'Rejeter l\'action'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isApprove
                        ? 'Ajoutez des félicitations ou un retour de validation (optionnel) :'
                        : 'Veuillez saisir le motif du rejet (recommandé) :',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: isApprove ? 'Excellent travail !' : 'La photo ne correspond pas à l\'action...',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isApprove ? Colors.green : Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: loading
                      ? null
                      : () async {
                          setState(() => loading = true);
                          try {
                            final comment = commentController.text.trim();
                            if (isApprove) {
                              await actionProvider.validateAction(action, comment: comment);
                            } else {
                              await actionProvider.rejectAction(action, comment: comment);
                            }
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isApprove ? 'Action validée avec succès !' : 'Action rejetée.'),
                                  backgroundColor: isApprove ? Colors.green : Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erreur : $e')),
                              );
                            }
                          } finally {
                            setState(() => loading = false);
                          }
                        },
                  child: loading
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(isApprove ? 'Confirmer Validation' : 'Confirmer Rejet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- MODAL DÉTAILS DE L'ACTION ---
  void _showActionDetailsModal(BuildContext context, VolunteerAction action) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Détails de l\'action', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const Divider(),
                  const SizedBox(height: 12),
                  // Image
                  if (action.photoUrl.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        action.photoUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 240,
                        errorBuilder: (context, err, stack) => Container(
                          height: 180,
                          color: Colors.grey.shade200,
                          child: const Center(child: Icon(Icons.broken_image, size: 60)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // User info
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundImage: action.userPhoto.isNotEmpty ? NetworkImage(action.userPhoto) : null,
                      child: action.userPhoto.isEmpty ? Text(action.userName.isNotEmpty ? action.userName[0].toUpperCase() : 'B') : null,
                    ),
                    title: Text(action.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Bénévole • ID: ${action.userId}'),
                  ),
                  const SizedBox(height: 12),
                  // Title & Desc
                  Text(action.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(action.description, style: const TextStyle(fontSize: 15, height: 1.4)),
                  const SizedBox(height: 16),
                  
                  // Metadata
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('Catégorie : ${action.category}')),
                      Chip(label: Text('Lieu : ${action.location}')),
                      Chip(label: Text('Statut actuel : ${action.status.toUpperCase()}')),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  if (action.status == 'en attente') ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _showEvaluationDialog(context, action, true);
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Valider l\'action'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _showEvaluationDialog(context, action, false);
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('Rejeter l\'action'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: action.status == 'validé' ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: action.status == 'validé' ? Colors.green.shade200 : Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Action déjà évaluée : ${action.status.toUpperCase()}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: action.status == 'validé' ? Colors.green.shade800 : Colors.red.shade800),
                          ),
                          if (action.commentaireAdmin.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Commentaire : "${action.commentaireAdmin}"', style: const TextStyle(fontStyle: FontStyle.italic)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final actionProvider = context.read<ActionProvider>();

    if (!authProvider.isAdmin) {
      return const Scaffold(body: Center(child: Text('Accès refusé')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord Admin', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Stats & Graphiques'),
            Tab(icon: Icon(Icons.pending_actions), text: 'En attente'),
            Tab(icon: Icon(Icons.history_edu), text: 'Historique'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ONGLE T 1: STATS & GRAPHICS
          _buildStatsTab(context),

          // ONGLET 2: PENDING ACTIONS
          StreamBuilder<List<VolunteerAction>>(
            stream: actionProvider.pendingStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final pending = snapshot.data ?? [];
              if (pending.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
                      const SizedBox(height: 12),
                      const Text('Toutes les actions ont été traitées !', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  // Shortcut button to full validation page
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () => context.go('/admin/validation'),
                        icon: const Icon(Icons.rate_review_outlined),
                        label: Text(
                          'Ouvrir la page de validation (${pending.length} en attente)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: pending.length,
                      itemBuilder: (context, index) {
                        final action = pending[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: action.photoUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(action.photoUrl, width: 50, height: 50, fit: BoxFit.cover),
                                  )
                                : const CircleAvatar(child: Icon(Icons.image)),
                            title: Text(action.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Bénévole : ${action.userName}\nCatégorie : ${action.category}'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            isThreeLine: true,
                            onTap: () => _showActionDetailsModal(context, action),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),

          // ONGLET 3: HISTORIQUE DES ACTIONS (VALIDEES OU REJETEES)
          StreamBuilder<List<VolunteerAction>>(
            stream: FirebaseFirestore.instance
                .collection('actions')
                .orderBy('datePublication', descending: true)
                .snapshots()
                .map((snap) => snap.docs
                    .map((doc) => VolunteerAction.fromMap(doc.data(), doc.id))
                    .where((a) => a.status != 'en attente')
                    .toList()),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final history = snapshot.data ?? [];
              if (history.isEmpty) {
                return const Center(child: Text('Aucune évaluation d\'action enregistrée.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final action = history[index];
                  final isApproved = action.status == 'validé';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(isApproved ? Icons.check_circle : Icons.cancel, color: isApproved ? Colors.green : Colors.red),
                      title: Text(action.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Statut: ${action.status.toUpperCase()}\nBénévole: ${action.userName}'),
                      trailing: const Icon(Icons.info_outline),
                      onTap: () => _showActionDetailsModal(context, action),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // --- CONSTRUCTEUR DE L'ONGLET STATISTIQUES ---
  Widget _buildStatsTab(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, usersSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('actions').snapshots(),
          builder: (context, actionsSnapshot) {
            final totalUsers = usersSnapshot.data?.docs.length ?? 0;
            final actions = actionsSnapshot.data?.docs
                    .map((d) => VolunteerAction.fromMap(d.data() as Map<String, dynamic>, d.id))
                    .toList() ??
                [];
            
            final totalValidated = actions.where((a) => a.status == 'validé').length;
            final totalPending = actions.where((a) => a.status == 'en attente').length;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Métriques Générales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  // Grille des métriques
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.8,
                    children: [
                      StatsCard(
                        icon: Icons.people_outline,
                        value: totalUsers.toString(),
                        label: 'Total Bénévoles',
                        color: Colors.blue,
                      ),
                      StatsCard(
                        icon: Icons.check_circle_outline,
                        value: totalValidated.toString(),
                        label: 'Actions Validées',
                        color: Colors.green,
                      ),
                      StatsCard(
                        icon: Icons.hourglass_top,
                        value: totalPending.toString(),
                        label: 'En Attente',
                        color: Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Graphique d'activité
                  const Text('Graphique d\'Activité (Actions par jour)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 160,
                            width: double.infinity,
                            child: CustomPaint(
                              painter: ActivityChartPainter(actions: actions),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: const [
                              Text('Lun', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              Text('Mar', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              Text('Mer', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              Text('Jeu', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              Text('Ven', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              Text('Sam', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              Text('Dim', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// --- CUSTOMPAINTER POUR GRAPH D'ACTIVITÉ ---
class ActivityChartPainter extends CustomPainter {
  final List<VolunteerAction> actions;

  ActivityChartPainter({required this.actions});

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintPoints = Paint()
      ..color = Colors.green.shade800
      ..strokeWidth = 8
      ..style = PaintingStyle.fill;

    final paintGrid = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;

    // 1. Dessiner grille arrière-plan
    final double stepY = size.height / 4;
    for (int i = 0; i <= 4; i++) {
      final y = i * stepY;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    // Calculer actions par jour de la semaine (1 à 7)
    // Pour simplifier, on distribue de façon déterministe ou réelle les actions
    final Map<int, int> counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    for (final a in actions) {
      final wDay = a.datePublication.toDate().weekday;
      counts[wDay] = (counts[wDay] ?? 0) + 1;
    }

    final double stepX = size.width / 6;
    final List<Offset> points = [];

    // Déterminer le max pour l'échelle
    int maxVal = 5;
    for (final val in counts.values) {
      if (val > maxVal) maxVal = val;
    }

    for (int i = 0; i < 7; i++) {
      final int day = i + 1;
      final int val = counts[day] ?? 0;
      
      final double x = i * stepX;
      // Normaliser Y
      final double y = size.height - (val / maxVal * size.height * 0.8) - 10;
      points.add(Offset(x, y));
    }

    // 2. Dessiner les lignes connectrices
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paintLine);

    // 3. Dessiner les points
    for (final pt in points) {
      canvas.drawCircle(pt, 4, paintPoints);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

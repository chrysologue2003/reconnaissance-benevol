import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

import '../providers/auth_provider.dart';
import '../providers/action_provider.dart';
import '../models/action_model.dart';
import '../services/storage_service.dart';
import '../services/certificate_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Filtres Historique
  String _statusFilter = 'Tous'; // 'Tous', 'en attente', 'validé', 'rejeté'
  String _categoryFilter = 'Tous';
  String _dateFilter = 'Tout'; // 'Tout', 'Semaine', 'Mois'

  // Paramètres States (Simulés localement)
  bool _notifValidated = true;
  bool _notifLikes = true;
  bool _notifRankings = false;
  String _appLanguage = 'Français';

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
    final difference = now.difference(date).inDays;
    return difference <= 7; // Permet les skew temporels (date légèrement dans le futur)
  }

  bool _isWithinMonth(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    return difference <= 30; // Permet les skew temporels (date légèrement dans le futur)
  }

  // --- DIALOGUE DE MODIFICATION DU PROFIL ---
  void _showEditProfileDialog(BuildContext context, String currentName, String currentCity, String? photoUrl) {
    final authProvider = context.read<AuthProvider>();
    final nameController = TextEditingController(text: currentName);
    final cityController = TextEditingController(text: currentCity);
    Uint8List? pickedBytes;
    bool updating = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Modifier le profil'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                        if (img != null) {
                          final bytes = await img.readAsBytes();
                          setState(() => pickedBytes = bytes);
                        }
                      },
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: pickedBytes != null
                            ? MemoryImage(pickedBytes!)
                            : (photoUrl != null && photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl) as ImageProvider
                                : null),
                        child: (pickedBytes == null && (photoUrl == null || photoUrl.isEmpty))
                            ? const Icon(Icons.add_a_photo, size: 30)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nom complet', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cityController,
                      decoration: const InputDecoration(labelText: 'Ville', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: updating ? null : () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: updating
                      ? null
                      : () async {
                          setState(() => updating = true);
                          try {
                            String? newPhotoUrl;
                            if (pickedBytes != null) {
                              newPhotoUrl = await StorageService().uploadActionPhoto(
                                'profile_${authProvider.user!.uid}',
                                pickedBytes!,
                              );
                            }
                            await authProvider.updateProfile(
                              name: nameController.text.trim(),
                              city: cityController.text.trim(),
                              photoUrl: newPhotoUrl,
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Profil mis à jour !')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erreur : $e')),
                              );
                            }
                          } finally {
                            setState(() => updating = false);
                          }
                        },
                  child: updating ? const CircularProgressIndicator() : const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- DIALOGUE CHANGEMENT MOT DE PASSE ---
  void _showChangePasswordDialog(BuildContext context) {
    final passwordController = TextEditingController();
    bool loading = false;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Changer de mot de passe'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Entrez votre nouveau mot de passe (6 caractères min) :'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Nouveau mot de passe', border: OutlineInputBorder()),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final pass = passwordController.text.trim();
                          if (pass.length < 6) return;
                          setState(() => loading = true);
                          try {
                            await FirebaseAuth.instance.currentUser?.updatePassword(pass);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Mot de passe mis à jour !')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erreur : $e (déconnectez-vous et reconnectez-vous)')),
                              );
                            }
                          } finally {
                            setState(() => loading = false);
                          }
                        },
                  child: const Text('Modifier'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- CONFIRMER SUPPRESSION DU COMPTE ---
  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer mon compte ?', style: TextStyle(color: Colors.red)),
          content: const Text(
            'Cette action est irréversible. Toutes vos données d\'actions et votre score de points seront définitivement effacés.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  await FirebaseAuth.instance.currentUser?.delete();
                  if (context.mounted) {
                    context.go('/login');
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur : $e (Veuillez vous reconnecter avant de supprimer)')),
                    );
                  }
                }
              },
              child: const Text('Supprimer définitivement'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final actionProvider = context.watch<ActionProvider>();
    final user = authProvider.user;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Utilisateur non connecté')));
    }

    final level = (user.points / 50).floor() + 1;
    final progressToNextLevel = (user.points % 50) / 50;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil & Réglages', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Profil'),
            Tab(icon: Icon(Icons.history), text: 'Historique'),
            Tab(icon: Icon(Icons.settings), text: 'Paramètres'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: PROFIL & BADGES
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Carte d'identité bénévole
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
                          child: user.photoUrl.isEmpty
                              ? Text(
                                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'B',
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              Text('📍 ${user.city}', style: TextStyle(color: Colors.grey.shade600)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Niveau $level',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('(${user.points} points globaux)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progressToNextLevel,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey.shade200,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Section Certificat de bénévolat
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Certificat Officiel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    StreamBuilder<List<VolunteerAction>>(
                      stream: actionProvider.userActionsStream(user.uid),
                      builder: (context, snapshot) {
                        final actions = snapshot.data ?? [];
                        final validatedCount = actions.where((a) => a.status == 'validé').length;
                        return ElevatedButton.icon(
                          onPressed: validatedCount == 0
                              ? null
                              : () async {
                                  try {
                                    // Afficher un indicateur de chargement
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Génération du certificat PDF en cours...'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                    await CertificateHelper.generateAndPrintCertificate(
                                      userName: user.name,
                                      points: user.points,
                                      actionsCount: validatedCount,
                                      badges: user.badges,
                                    );
                                  } catch (e, stack) {
                                    debugPrint('🔴 Erreur génération PDF : $e\n$stack');
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Erreur lors de la génération du PDF : $e'),
                                          backgroundColor: Colors.red,
                                          duration: const Duration(seconds: 5),
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: const Icon(Icons.download),
                          label: const Text('Télécharger PDF'),
                        );
                      },
                    ),
                  ],
                ),
                const Text(
                  'Générez votre certificat officiel de bénévolat certifiant vos engagements communautaires.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                StreamBuilder<List<VolunteerAction>>(
                  stream: actionProvider.userActionsStream(user.uid),
                  builder: (context, snapshot) {
                    final actions = snapshot.data ?? [];
                    final validatedCount = actions.where((a) => a.status == 'validé').length;
                    if (validatedCount == 0) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          '⚠️ Vous devez avoir au moins une action validée par un administrateur pour générer votre certificat.',
                          style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 20),

                // Section Badges de Récompenses
                const Text('Système d\'engagement & Badges', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildBadgesGrid(user.badges),
                const SizedBox(height: 20),

                // Modifier les infos
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditProfileDialog(context, user.name, user.city, user.photoUrl),
                    icon: const Icon(Icons.edit),
                    label: const Text('Modifier mes informations'),
                  ),
                ),
              ],
            ),
          ),

          // TAB 2: HISTORIQUE DES ACTIONS FILTRÉ ET TOTALISATEUR
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Filtres de l'historique
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _statusFilter,
                        decoration: const InputDecoration(labelText: 'Statut', contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                        items: const [
                          DropdownMenuItem(value: 'Tous', child: Text('Tous')),
                          DropdownMenuItem(value: 'en attente', child: Text('En attente')),
                          DropdownMenuItem(value: 'validé', child: Text('Validé')),
                          DropdownMenuItem(value: 'rejeté', child: Text('Rejeté')),
                        ],
                        onChanged: (val) => setState(() => _statusFilter = val!),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _categoryFilter,
                        decoration: const InputDecoration(labelText: 'Catégorie', contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                        items: const [
                          DropdownMenuItem(value: 'Tous', child: Text('Tous')),
                          DropdownMenuItem(value: 'Nettoyage', child: Text('Nettoyage')),
                          DropdownMenuItem(value: 'Aide', child: Text('Aide')),
                          DropdownMenuItem(value: 'Soutien scolaire', child: Text('Soutien scolaire')),
                          DropdownMenuItem(value: 'Dons', child: Text('Dons')),
                          DropdownMenuItem(value: 'Événements', child: Text('Événements')),
                          DropdownMenuItem(value: 'Autres', child: Text('Autres')),
                        ],
                        onChanged: (val) => setState(() => _categoryFilter = val!),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _dateFilter,
                        decoration: const InputDecoration(labelText: 'Période', contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                        items: const [
                          DropdownMenuItem(value: 'Tout', child: Text('Tout')),
                          DropdownMenuItem(value: 'Semaine', child: Text('Cette semaine')),
                          DropdownMenuItem(value: 'Mois', child: Text('Ce mois')),
                        ],
                        onChanged: (val) => setState(() => _dateFilter = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // StreamBuilder
                Expanded(
                  child: StreamBuilder<List<VolunteerAction>>(
                    stream: actionProvider.userActionsStream(user.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      var actions = snapshot.data ?? [];

                      // Appliquer filtres
                      if (_statusFilter != 'Tous') {
                        actions = actions.where((a) => a.status == _statusFilter).toList();
                      }
                      if (_categoryFilter != 'Tous') {
                        actions = actions.where((a) => a.category == _categoryFilter).toList();
                      }
                      if (_dateFilter == 'Semaine') {
                        actions = actions.where((a) => _isWithinWeek(a.datePublication.toDate())).toList();
                      } else if (_dateFilter == 'Mois') {
                        actions = actions.where((a) => _isWithinMonth(a.datePublication.toDate())).toList();
                      }

                      // Calculer total des points sur la période filtrée
                      // 10 pts par action validée, 2 pts par like reçu
                      int pointsOnPeriod = 0;
                      for (final a in actions) {
                        if (a.status == 'validé') {
                          pointsOnPeriod += 10;
                          pointsOnPeriod += a.likes.length * 2;
                        }
                      }

                      return Column(
                        children: [
                          // Bannière de score périodique
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'Total points accumulés sur la période : $pointsOnPeriod pts',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: actions.isEmpty
                                ? const Center(child: Text('Aucune action dans cette période.'))
                                : ListView.builder(
                                    itemCount: actions.length,
                                    itemBuilder: (context, index) {
                                      final action = actions[index];
                                      Color statusColor = Colors.grey;
                                      IconData statusIcon = Icons.hourglass_empty;
                                      if (action.status == 'validé') {
                                        statusColor = Colors.green;
                                        statusIcon = Icons.check_circle;
                                      } else if (action.status == 'rejeté') {
                                        statusColor = Colors.red;
                                        statusIcon = Icons.cancel;
                                      }

                                      return Card(
                                        child: ListTile(
                                          leading: Icon(statusIcon, color: statusColor),
                                          title: Text(action.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Text('${action.category} • ${action.location}\n${action.likes.length} applaudissements'),
                                          trailing: Text(
                                            action.status == 'validé' ? '+10 pts' : '0 pts',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
                                          ),
                                          isThreeLine: true,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // TAB 3: PARAMÈTRES
          ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              const Text('Sécurité & Profil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Changer de mot de passe'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showChangePasswordDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Changer la photo de profil'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showEditProfileDialog(context, user.name, user.city, user.photoUrl),
              ),
              const Divider(),
              const Text('Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _notifValidated,
                title: const Text('Action validée / rejetée'),
                subtitle: const Text('Recevoir un ping quand un admin évalue mon action'),
                onChanged: (val) => setState(() => _notifValidated = val),
              ),
              SwitchListTile(
                value: _notifLikes,
                title: const Text('Applaudissements (Likes)'),
                subtitle: const Text('Recevoir une alerte quand quelqu\'un aime mon action'),
                onChanged: (val) => setState(() => _notifLikes = val),
              ),
              SwitchListTile(
                value: _notifRankings,
                title: const Text('Classements Communautaires'),
                subtitle: const Text('Alertes de nouveaux podiums hebdomadaires'),
                onChanged: (val) => setState(() => _notifRankings = val),
              ),
              const Divider(),
              const Text('Préférences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Langue de l\'application'),
                trailing: DropdownButton<String>(
                  value: _appLanguage,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'Français', child: Text('Français')),
                    DropdownMenuItem(value: 'English', child: Text('English')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _appLanguage = val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Langue changée en $val (Simulation localisée)')),
                      );
                    }
                  },
                ),
              ),
              const Divider(),
              const Text('Zone de danger', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Supprimer mon compte', style: TextStyle(color: Colors.red)),
                subtitle: const Text('Suppression irréversible de votre compte et données'),
                onTap: () => _confirmDeleteAccount(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- GRID DES BADGES ---
  Widget _buildBadgesGrid(List<String> userBadges) {
    // Liste officielle de tous les badges du système de récompenses
    final List<Map<String, dynamic>> allBadges = [
      {
        'id': 'Débutant',
        'name': 'Débutant',
        'desc': '1 action validée',
        'icon': Icons.stars,
        'color': Colors.amber.shade700,
      },
      {
        'id': 'Solidaire',
        'name': 'Solidaire',
        'desc': '5 actions validées',
        'icon': Icons.favorite,
        'color': Colors.pink.shade400,
      },
      {
        'id': 'Engagé',
        'name': 'Engagé',
        'desc': '10 actions validées',
        'icon': Icons.verified,
        'color': Colors.blue.shade600,
      },
      {
        'id': 'Champion',
        'name': 'Champion',
        'desc': '25 actions validées',
        'icon': Icons.emoji_events,
        'color': Colors.purple.shade600,
      },
      {
        'id': 'Légende',
        'name': 'Légende',
        'desc': '50 actions validées',
        'icon': Icons.local_fire_department,
        'color': Colors.orange.shade800,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: allBadges.length,
      itemBuilder: (context, index) {
        final b = allBadges[index];
        final isUnlocked = userBadges.contains(b['id']);
        return Opacity(
          opacity: isUnlocked ? 1.0 : 0.35,
          child: Card(
            elevation: isUnlocked ? 3 : 1,
            color: isUnlocked ? Colors.white : Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    b['icon'] as IconData,
                    size: 32,
                    color: isUnlocked ? b['color'] as Color : Colors.grey,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    b['name'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isUnlocked ? Colors.black : Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    b['desc'] as String,
                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/action_model.dart';
import '../../providers/action_provider.dart';
import '../../providers/auth_provider.dart';

class AdminValidationPage extends StatefulWidget {
  const AdminValidationPage({super.key});

  @override
  State<AdminValidationPage> createState() => _AdminValidationPageState();
}

class _AdminValidationPageState extends State<AdminValidationPage> {
  // Tracks which action cards are currently loading (to prevent double-tap)
  final Set<String> _loadingIds = {};

  // ---------- HELPERS ----------

  void _setLoading(String id, bool value) {
    setState(() {
      if (value) {
        _loadingIds.add(id);
      } else {
        _loadingIds.remove(id);
      }
    });
  }

  // ---------- VALIDATE ----------
  Future<void> _onValidate(
      BuildContext context, VolunteerAction action) async {
    final actionProvider = context.read<ActionProvider>();
    _setLoading(action.actionId, true);
    try {
      await actionProvider.validateAction(action);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '« ${action.title} » validée avec succès ! (+10 pts au bénévole)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la validation : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) _setLoading(action.actionId, false);
    }
  }

  // ---------- REJECT DIALOG ----------
  void _showRejectDialog(BuildContext context, VolunteerAction action) {
    final actionProvider = context.read<ActionProvider>();
    final reasonController = TextEditingController();
    bool dialogLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.cancel_outlined,
                              color: Colors.red.shade700, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rejeter l\'action',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                action.title,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Motif du rejet',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reasonController,
                      maxLines: 4,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText:
                            'Ex. : La photo ne correspond pas à l\'action décrite...',
                        hintStyle: TextStyle(
                            color: Colors.grey.shade400, fontSize: 13),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.red.shade400, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ce motif sera communiqué au bénévole.',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: dialogLoading
                                ? null
                                : () => Navigator.pop(dialogCtx),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            onPressed: dialogLoading
                                ? null
                                : () async {
                                    final reason =
                                        reasonController.text.trim();
                                    setDialogState(
                                        () => dialogLoading = true);
                                    try {
                                      await actionProvider.rejectAction(
                                          action,
                                          comment: reason);
                                      if (dialogCtx.mounted) {
                                        Navigator.pop(dialogCtx);
                                      }
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                const Icon(Icons.info_outline,
                                                    color: Colors.white,
                                                    size: 20),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    '« ${action.title} » rejetée. Le bénévole a été notifié.',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            backgroundColor: Colors.red.shade700,
                                            behavior:
                                                SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setDialogState(
                                          () => dialogLoading = false);
                                      if (dialogCtx.mounted) {
                                        ScaffoldMessenger.of(dialogCtx)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('Erreur : $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            child: dialogLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Rejeter',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------- ACTION CARD ----------
  Widget _buildActionCard(BuildContext context, VolunteerAction action) {
    final isLoading = _loadingIds.contains(action.actionId);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormatted =
        DateFormat('dd MMM yyyy', 'fr_FR').format(action.date);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- PHOTO ----
          if (action.photoUrl.isNotEmpty)
            Stack(
              children: [
                Container(
                  height: 200,
                  color: Colors.black87,
                  width: double.infinity,
                  child: Image.network(
                    action.photoUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (ctx, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (ctx, err, stack) => Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_outlined,
                                size: 48, color: colorScheme.outline),
                            const SizedBox(height: 4),
                            Text('Image non disponible',
                                style: TextStyle(
                                    color: colorScheme.outline, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Category badge overlay
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.label_outline,
                            color: Colors.white, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          action.category,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              height: 100,
              width: double.infinity,
              color: colorScheme.surfaceContainerHighest,
              child: Center(
                child: Icon(Icons.volunteer_activism,
                    size: 40, color: colorScheme.primary),
              ),
            ),

          // ---- CONTENT ----
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  action.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  action.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Meta chips (location + date)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MetaChip(
                        icon: Icons.location_on_outlined,
                        label: action.location.isNotEmpty
                            ? action.location
                            : 'Lieu non précisé'),
                    _MetaChip(
                        icon: Icons.calendar_today_outlined,
                        label: dateFormatted),
                  ],
                ),
                const SizedBox(height: 12),

                // Volunteer info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: colorScheme.primaryContainer,
                      backgroundImage: action.userPhoto.isNotEmpty
                          ? NetworkImage(action.userPhoto)
                          : null,
                      child: action.userPhoto.isEmpty
                          ? Text(
                              action.userName.isNotEmpty
                                  ? action.userName[0].toUpperCase()
                                  : 'B',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimaryContainer,
                                  fontSize: 12),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            action.userName.isNotEmpty
                                ? action.userName
                                : 'Bénévole inconnu',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            'Bénévole',
                            style: TextStyle(
                                fontSize: 11, color: colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action buttons (Valider / Rejeter)
                isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : Row(
                        children: [
                          // REJETER button
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade300),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () =>
                                  _showRejectDialog(context, action),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text(
                                'Rejeter',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // VALIDER button
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: () => _onValidate(context, action),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text(
                                'Valider',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- BUILD ----------
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final actionProvider = context.read<ActionProvider>();

    // Access guard: must be admin
    if (!authProvider.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Accès refusé')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'Accès réservé aux administrateurs.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Retour à l\'accueil'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: StreamBuilder<List<VolunteerAction>>(
          stream: actionProvider.pendingStream,
          builder: (context, snapshot) {
            final count = snapshot.data?.length ?? 0;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Validation des actions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin');
            }
          },
        ),
        elevation: 0,
      ),
      body: StreamBuilder<List<VolunteerAction>>(
        stream: actionProvider.pendingStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off_outlined,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'Impossible de charger les actions.',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final actions = snapshot.data ?? [];

          if (actions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt,
                      size: 80,
                      color: Colors.green.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'Tout est à jour !',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aucune action en attente de validation.',
                    style: TextStyle(
                        fontSize: 15, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: actions.length,
            itemBuilder: (context, index) =>
                _buildActionCard(context, actions[index]),
          );
        },
      ),
    );
  }
}

// ---------- SMALL META CHIP WIDGET ----------
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colorScheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

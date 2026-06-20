import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../providers/action_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _getIconForType(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'validation':
        return Icons.check_circle;
      case 'rejet':
        return Icons.cancel;
      case 'badge':
        return Icons.emoji_events;
      case 'activite':
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(BuildContext context, String type) {
    switch (type) {
      case 'like':
        return Colors.red;
      case 'validation':
        return Colors.green;
      case 'rejet':
        return Colors.redAccent;
      case 'badge':
        return Colors.amber.shade700;
      case 'activite':
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Future<void> _markAllAsRead(String userId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Erreur lors du marquage des notifications : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final actionProvider = context.watch<ActionProvider>();
    final userId = authProvider.user?.uid ?? '';

    if (userId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Veuillez vous connecter.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read_outlined),
            tooltip: 'Tout marquer comme lu',
            onPressed: () => _markAllAsRead(userId),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: actionProvider.notificationsStream(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint('🔴 [NotificationsScreen] Erreur de chargement : ${snapshot.error}');
            return const Center(
              child: Text(
                'Erreur de chargement des notifications.',
                style: TextStyle(color: Colors.red),
              ),
            );
          }
          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('Aucune notification pour le moment.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final type = notif['type'] as String? ?? 'activite';
              final message = notif['message'] as String? ?? '';
              final isRead = notif['read'] as bool? ?? false;
              final timestamp = notif['timestamp'] as Timestamp?;
              
              String dateStr = '';
              if (timestamp != null) {
                dateStr = DateFormat('dd/MM à HH:mm').format(timestamp.toDate());
              }

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                leading: CircleAvatar(
                  backgroundColor: _getColorForType(context, type).withValues(alpha: 0.1),
                  child: Icon(
                    _getIconForType(type),
                    color: _getColorForType(context, type),
                  ),
                ),
                title: Text(
                  message,
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: dateStr.isNotEmpty
                    ? Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))
                    : null,
                trailing: !isRead
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
                onTap: () async {
                  if (!isRead) {
                    await FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(notif['id'] as String)
                        .update({'read': true});
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

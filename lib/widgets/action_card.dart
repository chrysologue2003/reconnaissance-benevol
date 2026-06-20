import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/action_model.dart';
import '../models/comment_model.dart';
import '../providers/auth_provider.dart';
import '../providers/action_provider.dart';
import '../widgets/comment_widget.dart';

class ActionCard extends StatelessWidget {
  final VolunteerAction action;
  final String currentUserId;
  final VoidCallback onLike;

  const ActionCard({
    super.key,
    required this.action,
    required this.currentUserId,
    required this.onLike,
  });

  Widget _buildImage() {
    final url = action.photoUrl;

    if (url.isEmpty) {
      return Container(
        height: 180,
        color: Colors.grey.shade200,
        child: const Center(child: Icon(Icons.image, size: 60)),
      );
    }

    return Container(
      height: 180,
      color: Colors.black87,
      width: double.infinity,
      child: Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey.shade200,
          child: const Center(child: Icon(Icons.broken_image, size: 60)),
        ),
      ),
    );
  }

  void _showCommentsSheet(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final actionProvider = context.read<ActionProvider>();
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 16,
            right: 16,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Commentaires',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: StreamBuilder<List<Comment>>(
                    stream: actionProvider.commentsStream(action.actionId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final comments = snapshot.data ?? [];
                      if (comments.isEmpty) {
                        return const Center(
                          child: Text('Soyez le premier à laisser un commentaire !', style: TextStyle(color: Colors.grey)),
                        );
                      }
                      return ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          return CommentWidget(comment: comments[index]);
                        },
                      );
                    },
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        child: Text(authProvider.user?.name.isNotEmpty == true ? authProvider.user!.name[0] : 'B'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: commentController,
                          decoration: const InputDecoration(
                            hintText: 'Ajouter un commentaire...',
                            border: InputBorder.none,
                          ),
                          maxLines: null,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
                        onPressed: () async {
                          final text = commentController.text.trim();
                          if (text.isEmpty) return;
                          
                          final newComment = Comment(
                            commentId: '',
                            userId: authProvider.user?.uid ?? '',
                            userName: authProvider.user?.name ?? 'Anonyme',
                            userPhoto: authProvider.user?.photoUrl ?? '',
                            text: text,
                            dateCreated: Timestamp.now(),
                          );

                          await actionProvider.addComment(action.actionId, newComment);
                          commentController.clear();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _shareAction(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Partager l\'action'),
          content: Text('Voulez-vous copier le lien de cette action de bénévolat « ${action.title} » ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                // Simuler la copie du lien
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lien copié dans le presse-papiers !')),
                );
              },
              child: const Text('Copier le lien'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final liked = action.likes.contains(currentUserId);
    final actionProvider = context.read<ActionProvider>();
    final formattedDate = DateFormat('dd MMM yyyy à HH:mm').format(action.datePublication.toDate());

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de la carte avec les infos utilisateur
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  backgroundImage: action.userPhoto.isNotEmpty ? NetworkImage(action.userPhoto) : null,
                  child: action.userPhoto.isEmpty
                      ? Text(
                          action.userName.isNotEmpty ? action.userName[0].toUpperCase() : 'B',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.userName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Publié le $formattedDate',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    action.category.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Image de l'action
          Stack(
            children: [
              _buildImage(),
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.redAccent, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        action.location,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Contenu (Titre & Description)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  action.description,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
                ),
                if (action.commentaireAdmin.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: action.status == 'validé' ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: action.status == 'validé' ? Colors.green.shade200 : Colors.red.shade200,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          action.status == 'validé' ? Icons.check_circle : Icons.error,
                          color: action.status == 'validé' ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Commentaire Admin : ${action.commentaireAdmin}',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: action.status == 'validé' ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const Divider(height: 1),

          // Section Actions (Applaudir, Commenter, Partager)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Bouton Like / Applaudir
                TextButton.icon(
                  onPressed: onLike,
                  icon: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? Colors.red : Colors.grey.shade700,
                  ),
                  label: Text(
                    '${action.likes.length} Applaudir',
                    style: TextStyle(color: liked ? Colors.red : Colors.grey.shade700, fontWeight: FontWeight.w600),
                  ),
                ),
                
                // Bouton Commenter
                StreamBuilder<List<Comment>>(
                  stream: actionProvider.commentsStream(action.actionId),
                  builder: (context, snapshot) {
                    final commentCount = snapshot.data?.length ?? 0;
                    return TextButton.icon(
                      onPressed: () => _showCommentsSheet(context),
                      icon: Icon(Icons.mode_comment_outlined, color: Colors.grey.shade700),
                      label: Text(
                        '$commentCount Commenter',
                        style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                      ),
                    );
                  },
                ),

                // Bouton Partager
                TextButton.icon(
                  onPressed: () => _shareAction(context),
                  icon: Icon(Icons.share_outlined, color: Colors.grey.shade700),
                  label: Text(
                    'Partager',
                    style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

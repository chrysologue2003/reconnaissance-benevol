import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/action_model.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

class PostActionScreen extends StatefulWidget {
  const PostActionScreen({super.key});

  @override
  State<PostActionScreen> createState() => _PostActionScreenState();
}

class _PostActionScreenState extends State<PostActionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  DateTime? _pickedDate;
  String _category = 'Nettoyage';
  bool _isSubmitting = false;
  bool _dateError = false; // affiche une erreur si la date n'est pas choisie lors de la soumission
  Uint8List? _pickedImageBytes;
  XFile? _pickedXFile;

  Future<void> _pickImage() async {
    final XFile? result = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (result == null) return;
    final bytes = await result.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedXFile = result;
      _pickedImageBytes = bytes;
    });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _pickedDate = date;
        _dateError = false; // efface l'erreur dès qu'une date est choisie
      });
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate() || _pickedDate == null) {
      if (_pickedDate == null) {
        setState(() => _dateError = true);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Veuillez compléter tous les champs et choisir une date.',
          ),
        ),
      );
      return;
    }
    setState(() => _dateError = false);

    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    final createdAt = DateTime.now();
    final action = VolunteerAction(
      actionId: '',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      photoUrl: '',
      category: _category,
      location: _locationController.text.trim(),
      date: _pickedDate!,
      userId: user.uid,
      userName: user.name,
      userPhoto: user.photoUrl,
      likes: [],
      datePublication: Timestamp.fromDate(createdAt),
      status: 'en attente',
    );

    // Images d'illustration par défaut de haute qualité basées sur la catégorie
    final Map<String, String> defaultCategoryImages = {
      'Nettoyage': 'https://images.unsplash.com/photo-1530587191325-3db32d826c18?w=800',
      'Aide': 'https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?w=800',
      'Soutien scolaire': 'https://images.unsplash.com/photo-1427504494785-3a9ca7044f45?w=800',
      'Dons': 'https://images.unsplash.com/photo-1532629345422-7515f3d16bb6?w=800',
      'Événements': 'https://images.unsplash.com/photo-1511578314322-379afb476865?w=800',
      'Autres': 'https://images.unsplash.com/photo-1559027615-cd4487df1365?w=800',
    };
    final defaultUrl = defaultCategoryImages[_category] ?? 'https://images.unsplash.com/photo-1559027615-cd4487df1365?w=800';

    try {
      debugPrint('Début de la soumission de l\'action...');
      final firestoreService = FirestoreService();
      final actionId = FirebaseFirestore.instance
          .collection('actions')
          .doc()
          .id;
      
      String finalPhotoUrl = defaultUrl;
      bool usingFallback = true;

      if (_pickedImageBytes != null) {
        try {
          debugPrint('Upload de la photo vers Cloudinary (${(_pickedImageBytes!.length / 1024).toStringAsFixed(0)} KB)...');
          // Upload vers Cloudinary — gratuit, sans Firebase Storage
          finalPhotoUrl = await StorageService().uploadActionPhoto(
            actionId,
            _pickedImageBytes!,
          );
          usingFallback = false;
          debugPrint('Photo uploadée avec succès sur Cloudinary !');
        } catch (uploadError) {
          debugPrint('Erreur d\'upload Cloudinary : $uploadError. Passage à l\'illustration par défaut.');
        }
      }

      debugPrint('Enregistrement dans Firestore avec photoUrl: $finalPhotoUrl');

      final savedAction = action.copyWith(
        actionId: actionId,
        photoUrl: finalPhotoUrl,
      );
      
      await firestoreService.createActionWithId(savedAction, actionId).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception(
          'L\'enregistrement dans la base de données Firestore a expiré. Veuillez vérifier votre connexion.'
        ),
      );
      
      debugPrint('Action enregistrée avec succès dans Firestore !');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(usingFallback 
              ? 'Action soumise ! (Illustration par défaut utilisée)' 
              : 'Action soumise pour validation.'
            ),
          ),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      debugPrint('Erreur lors de la soumission : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'envoi : ${e.toString()}'),
            duration: const Duration(seconds: 7),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Poster une action')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Titre'),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Entrez un titre'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 4,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Entrez une description'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                    items: const [
                      DropdownMenuItem(value: 'Nettoyage', child: Text('Nettoyage')),
                      DropdownMenuItem(value: 'Aide', child: Text('Aide')),
                      DropdownMenuItem(value: 'Soutien scolaire', child: Text('Soutien scolaire')),
                      DropdownMenuItem(value: 'Dons', child: Text('Dons')),
                      DropdownMenuItem(value: 'Événements', child: Text('Événements')),
                      DropdownMenuItem(value: 'Autres', child: Text('Autres')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _category = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(labelText: 'Lieu'),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Entrez le lieu'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: Text(
                      _pickedDate == null
                          ? 'Sélectionner une date *'
                          : 'Date : ${_pickedDate!.toLocal().toString().split(' ')[0]}',
                      style: TextStyle(
                        color: _dateError
                            ? Theme.of(context).colorScheme.error
                            : (_pickedDate != null
                                ? null
                                : Colors.grey.shade600),
                      ),
                    ),
                    trailing: Icon(
                      Icons.calendar_today,
                      color: _dateError ? Theme.of(context).colorScheme.error : null,
                    ),
                    shape: _dateError
                        ? RoundedRectangleBorder(
                            side: BorderSide(color: Theme.of(context).colorScheme.error),
                            borderRadius: BorderRadius.circular(4),
                          )
                        : null,
                    onTap: _pickDate,
                  ),
                  if (_dateError)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 4),
                      child: Text(
                        'Veuillez choisir une date',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _pickedImageBytes == null
                      ? Column(
                          children: [
                            Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Text('Aucune image sélectionnée'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.photo),
                              label: const Text('Ajouter une photo'),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Container(
                              height: 180,
                              color: Colors.black87,
                              width: double.infinity,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: kIsWeb
                                    ? Image.network(
                                        _pickedXFile!.path,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stack) =>
                                            Image.memory(
                                              _pickedImageBytes!,
                                              fit: BoxFit.contain,
                                            ),
                                      )
                                    : Image.memory(
                                        _pickedImageBytes!,
                                        fit: BoxFit.contain,
                                      ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.edit),
                              label: const Text('Changer la photo'),
                            ),
                          ],
                        ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const CircularProgressIndicator()
                        : const Text('Envoyer pour validation'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

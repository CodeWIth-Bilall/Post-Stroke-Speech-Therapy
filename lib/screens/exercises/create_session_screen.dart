import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../models/saved_session_model.dart';
import '../../services/firestore_service.dart';

class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final Set<String> _selectedPhrases = {};
  int _repetitions = 1;
  final _nameController = TextEditingController();
  final _firestoreService = FirestoreService();
  bool _isSaving = false;

  static const _categoryColors = {
    'Common': Color(0xFF4ECDC4),
    'Food & Drink': Color(0xFFFF6B6B),
    'Feelings': Color(0xFFFFA07A),
    'Medical': Color(0xFF6C63FF),
    'Sentence Builder': Color(0xFF26A69A),
    'Sentence Chain': Color(0xFFE91E63),
    'Tongue Twisters': Color(0xFFAB47BC),
  };

  static const _categoryIcons = {
    'Common': Icons.chat_bubble_outline_rounded,
    'Food & Drink': Icons.restaurant_rounded,
    'Feelings': Icons.favorite_outline_rounded,
    'Medical': Icons.medical_services_outlined,
    'Sentence Builder': Icons.construction_rounded,
    'Sentence Chain': Icons.link_rounded,
    'Tongue Twisters': Icons.record_voice_over_rounded,
  };

  Future<void> _saveSession() async {
    if (_selectedPhrases.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);

    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Session ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';

    final session = SavedSessionModel(
      id: const Uuid().v4(),
      userId: uid,
      name: name,
      phrases: _selectedPhrases.toList(),
      repetitions: _repetitions,
    );

    await _firestoreService.saveSession(session);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Session "$name" saved with ${_selectedPhrases.length} phrases!'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Create Session'),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Session Name
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'Session name (optional)',
                      prefixIcon: const Icon(Icons.label_outline_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text('Select Exercises',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  const Text('Tap a category to expand, then select phrases',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 16),

                  // Exercise categories as dropdowns
                  ...AppConstants.phraseCategories.entries.map((entry) {
                    return _buildCategoryDropdown(entry.key, entry.value);
                  }),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // Bottom bar
          if (_selectedPhrases.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Repetitions: ', style: TextStyle(fontWeight: FontWeight.w500)),
                        ...[1, 2, 3, 5].map((r) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text('${r}x', style: TextStyle(
                                fontSize: 13,
                                color: _repetitions == r ? Colors.white : AppTheme.textPrimary,
                                fontWeight: FontWeight.w600)),
                            selected: _repetitions == r,
                            selectedColor: AppTheme.primaryColor,
                            onSelected: (_) => setState(() => _repetitions = r),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveSession,
                        icon: _isSaving
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_rounded),
                        label: Text('Save Session (${_selectedPhrases.length} phrases × ${_repetitions}x)',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown(String category, List<String> phrases) {
    final color = _categoryColors[category] ?? AppTheme.primaryColor;
    final icon = _categoryIcons[category] ?? Icons.category;
    final selectedCount = phrases.where((p) => _selectedPhrases.contains(p)).length;
    final allSelected = phrases.every((p) => _selectedPhrases.contains(p));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(category,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          subtitle: Text(
            selectedCount > 0 ? '$selectedCount / ${phrases.length} selected' : '${phrases.length} phrases',
            style: TextStyle(fontSize: 12, color: selectedCount > 0 ? color : AppTheme.textSecondary),
          ),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (allSelected) {
                        _selectedPhrases.removeAll(phrases);
                      } else {
                        _selectedPhrases.addAll(phrases);
                      }
                    });
                  },
                  child: Text(allSelected ? 'Deselect All' : 'Select All',
                      style: TextStyle(color: color, fontSize: 12)),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: phrases.map((phrase) {
                final selected = _selectedPhrases.contains(phrase);
                return GestureDetector(
                  onTap: () => setState(() {
                    selected ? _selectedPhrases.remove(phrase) : _selectedPhrases.add(phrase);
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? color.withOpacity(0.15) : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? color : Colors.transparent,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(Icons.check_circle_rounded, color: color, size: 18),
                          ),
                        Flexible(
                          child: Text('"$phrase"',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                                  color: selected ? color : AppTheme.textPrimary)),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

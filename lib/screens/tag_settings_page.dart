import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/user_tag.dart';
import 'package:prasowka/providers/tag_provider.dart';
import 'package:prasowka/theme/app_theme.dart';

class TagSettingsPage extends StatelessWidget {
  const TagSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tagProvider = context.watch<TagProvider>();
    final tags = tagProvider.tags;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TAGI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context, tagProvider),
          ),
        ],
      ),
      body: tags.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.label_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Brak tagów',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dodaj tag, aby oznaczać artykuły',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: tags.length,
              itemBuilder: (context, index) {
                final tag = tags[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(
                    color: tag.color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: tag.color.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(tag.icon, color: tag.color, size: 20),
                    ),
                    title: Text(
                      tag.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, size: 20, color: Colors.grey.shade500),
                          onPressed: () => _showEditDialog(context, tagProvider, tag),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 20, color: Colors.grey.shade500),
                          onPressed: () => _confirmDelete(context, tagProvider, tag),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  static const _presetColors = [
    0xFF4CAF50, 0xFFF44336, 0xFF9C27B0, 0xFF2196F3,
    0xFFFF9800, 0xFF00BCD4, 0xFFE91E63, 0xFF3F51B5,
    0xFFF5B942, 0xFF795548,
  ];

  void _showAddDialog(BuildContext context, TagProvider provider) {
    final controller = TextEditingController();
    int selectedColor = 0xFFF5B942;
    _showColorPickerDialog(
      context,
      title: 'NOWY TAG',
      nameController: controller,
      initialColor: selectedColor,
      onColorChanged: (c) => selectedColor = c,
      onConfirm: (name) {
        if (name.isNotEmpty) {
          provider.addTag(name, color: Color(selectedColor));
        }
      },
    );
  }

  void _showEditDialog(BuildContext context, TagProvider provider, UserTag tag) {
    final controller = TextEditingController(text: tag.name);
    int selectedColor = tag.colorValue;
    _showColorPickerDialog(
      context,
      title: 'EDYTUJ TAG',
      nameController: controller,
      initialColor: selectedColor,
      onColorChanged: (c) => selectedColor = c,
      onConfirm: (name) {
        if (name.isNotEmpty) {
          provider.updateTag(tag.id, name: name, color: Color(selectedColor));
        }
      },
    );
  }

  void _showColorPickerDialog(
    BuildContext context, {
    required String title,
    required TextEditingController nameController,
    required int initialColor,
    required ValueChanged<int> onColorChanged,
    required ValueChanged<String> onConfirm,
  }) {
    int selectedColor = initialColor;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: 'Nazwa tagu'),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetColors.map((c) {
                  final isSelected = c == selectedColor;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() => selectedColor = c);
                      onColorChanged(c);
                    },
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [BoxShadow(color: Color(c).withValues(alpha: 0.5), blurRadius: 6)]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
            TextButton(
              onPressed: () {
                onConfirm(nameController.text.trim());
                Navigator.pop(ctx);
              },
              child: Text('OK', style: TextStyle(color: AppTheme.accentFor(context))),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, TagProvider provider, UserTag tag) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń tag?'),
        content: Text('Tag "${tag.name}" zostanie usunięty ze wszystkich artykułów.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
          TextButton(
            onPressed: () {
              provider.removeTag(tag.id);
              Navigator.pop(ctx);
            },
            child: const Text('Usuń', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

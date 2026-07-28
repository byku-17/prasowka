import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/settings_provider.dart';

class CategorySettingsPage extends StatelessWidget {
  const CategorySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('KATEGORIE')),
      body: ReorderableListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        onReorderItem: (oldIndex, newIndex) => settings.reorderCategories(oldIndex, newIndex),
        children: settings.allCategoriesOrdered.map((cat) {
          final isActive = settings.isCategoryActive(cat.id);
          return ListTile(
            key: ValueKey(cat.id),
            leading: Icon(cat.icon, color: isActive ? AppTheme.accentGold : Colors.grey),
            title: Text(cat.name, style: TextStyle(color: isActive ? Colors.white : Colors.grey)),
            trailing: cat.id == 'all' 
                ? const Icon(Icons.lock_outline, size: 18, color: Colors.grey)
                : Switch(
                    value: isActive,
                    onChanged: (_) => settings.toggleCategory(cat.id),
                    activeThumbColor: AppTheme.accentGold,
                  ),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(context, settings),
        backgroundColor: AppTheme.accentGold,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('NOWA KATEGORIA'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nazwa (np. AI, Finanse)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANULUJ')),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                settings.addCustomCategory(controller.text, Icons.star_border);
                Navigator.pop(context);
              }
            },
            child: const Text('DODAJ', style: TextStyle(color: AppTheme.accentGold)),
          ),
        ],
      ),
    );
  }
}

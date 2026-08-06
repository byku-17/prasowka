import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/settings_provider.dart';

class CategorySettingsPage extends StatelessWidget {
  const CategorySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMedium = settings.themeVariant == AppThemeVariant.medium;
    final isRoyal = settings.themeVariant == AppThemeVariant.royalPurple;

    // Kolory kategorii zależne od motywu
    final Color activeColor;
    final Color inactiveColor;
    final Color activeBg;
    if (isDark) {
      activeColor = AppTheme.accentGold;
      inactiveColor = Colors.white54;
      activeBg = AppTheme.accentGold.withValues(alpha: 0.08);
    } else if (isMedium) {
      activeColor = AppTheme.accentAmber;
      inactiveColor = AppTheme.graphite;
      activeBg = AppTheme.accentAmber.withValues(alpha: 0.10);
    } else if (isRoyal) {
      activeColor = AppTheme.textDark;
      inactiveColor = AppTheme.textInactive;
      activeBg = AppTheme.textDark.withValues(alpha: 0.06);
    } else {
      activeColor = AppTheme.accentAmber;
      inactiveColor = AppTheme.graphite;
      activeBg = AppTheme.accentAmber.withValues(alpha: 0.10);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('KATEGORIE')),
      body: ReorderableListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        onReorderItem: (oldIndex, newIndex) => settings.reorderCategories(oldIndex, newIndex),
        children: settings.allCategoriesOrdered.map((cat) {
          final isActive = settings.isCategoryActive(cat.id);
          return Container(
            key: ValueKey(cat.id),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: isActive ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              leading: Icon(cat.icon, color: isActive ? activeColor : inactiveColor, size: 22),
              title: Text(cat.name, style: TextStyle(
                color: isActive ? activeColor : inactiveColor,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 15,
              )),
              trailing: cat.id == 'all'
                  ? Icon(Icons.lock_outline, size: 18, color: inactiveColor)
                  : Switch(
                      value: isActive,
                      onChanged: (_) => settings.toggleCategory(cat.id),
                      activeThumbColor: activeColor,
                    ),
            ),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(context, settings),
        backgroundColor: AppTheme.accentFor(context),
        foregroundColor: isDark ? Colors.white : Colors.white,
        child: const Icon(Icons.add, color: Colors.white),
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
            child: Text('DODAJ', style: TextStyle(color: AppTheme.accentFor(context))),
          ),
        ],
      ),
    );
  }
}

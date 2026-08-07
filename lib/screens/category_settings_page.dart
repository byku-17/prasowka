import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/news_category.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/settings_provider.dart';

class CategorySettingsPage extends StatelessWidget {
  const CategorySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final accent = AppTheme.accentFor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final slot1Cat = settings.getCategoryById(settings.mainTabSlot1);
    final slot2Cat = settings.getCategoryById(settings.mainTabSlot2);
    final topicCategories = settings.topicCategories;

    return Scaffold(
      appBar: AppBar(title: const Text('KATEGORIE')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          // ─── SEKCJA: Zakładki główne ───
          _sectionHeader('ZAKŁADKI GŁÓWNE', accent),
          const SizedBox(height: 4),

          // Dzisiaj — zablokowany
          _lockedTile(
            context,
            icon: Icons.today,
            label: 'Dzisiaj',
            subtitle: 'Wszystkie newsy — zawsze na pierwszym miejscu',
            accent: accent,
          ),

          // Slot 1
          _slotTile(
            context,
            slotNumber: 1,
            category: slot1Cat,
            accent: accent,
            isDark: isDark,
            availableCategories: settings.availableCategoriesForSlots,
            onSelected: (catId) => settings.setMainTabSlot(1, catId),
          ),

          // Slot 2
          _slotTile(
            context,
            slotNumber: 2,
            category: slot2Cat,
            accent: accent,
            isDark: isDark,
            availableCategories: settings.availableCategoriesForSlots
                .where((c) => c.id != settings.mainTabSlot1)
                .toList(),
            onSelected: (catId) => settings.setMainTabSlot(2, catId),
          ),

          const SizedBox(height: 16),

          // ─── SEKCJA: Kolejność w zakładce Tematy ───
          _sectionHeader('ZAKŁADKA TEMATY', accent),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Kolejność kategorii wyświetlanych w zakładce Tematy',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
          const SizedBox(height: 4),

          if (topicCategories.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Brak kategorii do wyświetlenia',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            )
          else
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (oldIndex, newIndex) {
                settings.reorderTopicCategories(oldIndex, newIndex);
              },
              children: topicCategories.map((cat) {
                return Container(
                  key: ValueKey('topic_${cat.id}'),
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: ListTile(
                    leading: Icon(cat.icon, color: accent, size: 22),
                    title: Text(
                      cat.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    trailing: Icon(Icons.drag_handle, color: Colors.grey.shade400, size: 20),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: accent,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _lockedTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color accent,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: accent, size: 22),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: accent,
          ),
        ),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        trailing: Icon(Icons.lock_outline, size: 18, color: Colors.grey.shade400),
      ),
    );
  }

  Widget _slotTile(
    BuildContext context, {
    required int slotNumber,
    required NewsCategory? category,
    required Color accent,
    required bool isDark,
    required List<NewsCategory> availableCategories,
    required ValueChanged<String> onSelected,
  }) {
    final label = category?.name ?? 'Wybierz...';
    final icon = category?.icon ?? Icons.category_outlined;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: accent, size: 22),
        title: Text(
          'Zakładka $slotNumber',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: accent,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.unfold_more, size: 20),
        onTap: () => _showCategoryPicker(
          context,
          slotNumber: slotNumber,
          currentId: category?.id,
          available: availableCategories,
          onSelected: onSelected,
        ),
      ),
    );
  }

  void _showCategoryPicker(
    BuildContext context, {
    required int slotNumber,
    required String? currentId,
    required List<NewsCategory> available,
    required ValueChanged<String> onSelected,
  }) {
    final accent = AppTheme.accentFor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2126) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Wybierz kategorię dla zakładki $slotNumber',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: available.length,
                  itemBuilder: (ctx, index) {
                    final cat = available[index];
                    final isSelected = cat.id == currentId;
                    return ListTile(
                      leading: Icon(
                        cat.icon,
                        color: isSelected ? accent : Colors.grey,
                        size: 22,
                      ),
                      title: Text(
                        cat.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? accent : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: accent, size: 22)
                          : null,
                      onTap: () {
                        onSelected(cat.id);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

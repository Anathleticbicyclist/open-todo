import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/task_list.dart';
import '../store/todo_store.dart';
import '../theme.dart';

/// Left navigation sidebar, styled after Microsoft To Do:
/// search box on top, smart lists, then user lists, settings at the bottom.
class Sidebar extends StatelessWidget {
  final TodoStore store;
  final VoidCallback onOpenSettings;
  final VoidCallback onCloseDrawer; // no-op on wide screens

  const Sidebar({
    super.key,
    required this.store,
    required this.onOpenSettings,
    required this.onCloseDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? AppTheme.sidebarDark : AppTheme.sidebarLight;

    return Container(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: _SearchBox(store: store),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _smartTile(
                  context,
                  id: TaskList.myDayId,
                  icon: Icons.wb_sunny_outlined,
                  label: AppStrings.tr('myDay'),
                  count: store.myDayCount,
                ),
                _smartTile(
                  context,
                  id: TaskList.importantId,
                  icon: Icons.star_border,
                  label: AppStrings.tr('important'),
                  count: store.importantCount,
                ),
                _smartTile(
                  context,
                  id: TaskList.plannedId,
                  icon: Icons.calendar_today_outlined,
                  label: AppStrings.tr('planned'),
                  count: store.plannedCount,
                ),
                _smartTile(
                  context,
                  id: TaskList.allTasksId,
                  icon: Icons.home_outlined,
                  label: AppStrings.tr('allTasks'),
                  count: store.allOpenCount,
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 4),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    AppStrings.tr('lists'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                for (final list in store.customLists)
                  _customTile(context, list),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.add, size: 20),
            title: Text(AppStrings.tr('newList')),
            dense: true,
            onTap: () => _showNewListDialog(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings_outlined, size: 20),
            title: Text(AppStrings.tr('settings')),
            dense: true,
            onTap: () {
              onCloseDrawer();
              onOpenSettings();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _smartTile(
    BuildContext context, {
    required int id,
    required IconData icon,
    required String label,
    required int count,
  }) {
    final selected = store.selectedListId == id && !store.isSearching;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _NavTile(
      selected: selected,
      icon: icon,
      iconColor: isDark ? const Color(0xFF4CC2FF) : AppTheme.msBlue,
      label: label,
      count: count,
      onTap: () {
        store.selectList(id);
        onCloseDrawer();
      },
    );
  }

  Widget _customTile(BuildContext context, TaskList list) {
    final selected =
        store.selectedListId == list.id && !store.isSearching;
    final color = AppTheme.hexToColor(list.colorHex);
    return _NavTile(
      selected: selected,
      icon: Icons.list,
      iconColor: color,
      label: store.listNameOf(list.id!),
      count: store.openCounts[list.id] ?? 0,
      onTap: () {
        store.selectList(list.id!);
        onCloseDrawer();
      },
      onLongPress: () => _showListMenu(context, list),
      trailing: IconButton(
        icon: const Icon(Icons.more_horiz, size: 18),
        tooltip: AppStrings.tr('listOptions'),
        onPressed: () => _showListMenu(context, list),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  Future<void> _showNewListDialog(BuildContext context) async {
    final nameController = TextEditingController();
    String colorHex = TaskList.palette.first;
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(AppStrings.tr('newList')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: AppStrings.tr('listName'),
                      hintText: AppStrings.tr('listNameHint'),
                    ),
                    onSubmitted: (_) =>
                        Navigator.of(context).pop(nameController.text),
                  ),
                  const SizedBox(height: 16),
                  Text(AppStrings.tr('colour')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: TaskList.palette.map((hex) {
                      final selected = hex == colorHex;
                      return GestureDetector(
                        onTap: () => setState(() => colorHex = hex),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppTheme.hexToColor(hex),
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: selected
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppStrings.tr('cancel')),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(nameController.text),
                  child: Text(AppStrings.tr('create')),
                ),
              ],
            );
          },
        );
      },
    );
    if (name != null && name.trim().isNotEmpty) {
      await store.createList(name.trim(), colorHex);
    }
    nameController.dispose();
  }

  Future<void> _showListMenu(BuildContext context, TaskList list) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(AppStrings.tr('renameList')),
              onTap: () => Navigator.of(context).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(AppStrings.tr('changeColour')),
              onTap: () => Navigator.of(context).pop('color'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.danger),
              title: Text(
                AppStrings.tr('deleteList'),
                style: const TextStyle(color: AppTheme.danger),
              ),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'rename') {
      final controller = TextEditingController(text: list.name);
      final name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppStrings.tr('renameList')),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'List name'),
            onSubmitted: (_) =>
                Navigator.of(context).pop(controller.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppStrings.tr('cancel')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text),
              child: Text(AppStrings.tr('save')),
            ),
          ],
        ),
      );
      controller.dispose();
      if (name != null && name.trim().isNotEmpty) {
        await store.renameList(list, name.trim());
      }
    } else if (action == 'color') {
      final hex = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppStrings.tr('listColour')),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TaskList.palette.map((h) {
              return GestureDetector(
                onTap: () => Navigator.of(context).pop(h),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.hexToColor(h),
                    shape: BoxShape.circle,
                    border: h == list.colorHex
                        ? Border.all(
                            color:
                                Theme.of(context).colorScheme.onSurface,
                            width: 2,
                          )
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppStrings.tr('cancel')),
            ),
          ],
        ),
      );
      if (hex != null) await store.recolorList(list, hex);
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppStrings.tr(
              'deleteListTitle', {'name': list.name})),
          content: Text(AppStrings.tr('deleteListMessage')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppStrings.tr('cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(AppStrings.tr('delete')),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await store.deleteList(list.id!);
      }
    }
  }
}

class _NavTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final Color iconColor;
  final String label;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  const _NavTile({
    required this.selected,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.count,
    required this.onTap,
    this.onLongPress,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: selected
            ? (isDark
                ? const Color(0xFF2D2C2B)
                : AppTheme.msBlueLight.withOpacity(0.6))
            : null,
        borderRadius: BorderRadius.circular(4),
        border: selected
            ? Border(
                left: BorderSide(
                  color: isDark ? const Color(0xFF4CC2FF) : AppTheme.msBlue,
                  width: 3,
                ),
              )
            : null,
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, size: 20, color: iconColor),
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count > 0)
              Text(
                '$count',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing!,
            ],
          ],
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

class _SearchBox extends StatefulWidget {
  final TodoStore store;

  const _SearchBox({required this.store});

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: AppStrings.tr('search'),
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: widget.store.isSearching
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _controller.clear();
                  widget.store.setSearchQuery('');
                },
              )
            : null,
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2D2C2B)
            : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onChanged: (v) => widget.store.setSearchQuery(v),
    );
  }
}

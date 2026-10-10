import 'package:flutter/material.dart';
import 'package:bibliod/core/constants/app_constants.dart';
import 'package:bibliod/features/settings/presentation/settings_notifier.dart';

class ColumnsDialog extends StatelessWidget {
  final SettingsNotifier settingsNotifier;

  const ColumnsDialog({super.key, required this.settingsNotifier});

  static Future<void> show(
    BuildContext context,
    SettingsNotifier settingsNotifier,
  ) {
    return showDialog(
      context: context,
      builder: (context) => ColumnsDialog(settingsNotifier: settingsNotifier),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleCols = settingsNotifier.visibleColumns;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.view_column_rounded),
          SizedBox(width: 10),
          Text('Colonnes affichées'),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: ListenableBuilder(
          listenable: settingsNotifier,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Cochez les colonnes que vous souhaitez afficher dans le tableau :',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: AppConstants.columnLabels.entries.map((entry) {
                      final key = entry.key;
                      final label = entry.value;
                      final isChecked = visibleCols.contains(key);

                      return CheckboxListTile(
                        dense: true,
                        title: Text(
                          label,
                          style: const TextStyle(fontSize: 14),
                        ),
                        value: isChecked,
                        onChanged: (bool? value) {
                          settingsNotifier.toggleColumn(key);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            settingsNotifier.resetColumnsToDefault();
          },
          child: const Text('Rétablir par défaut'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

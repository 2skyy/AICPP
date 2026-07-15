import 'package:flutter/material.dart';
import '../theme/toss_colors.dart';

class TossChipSelector extends StatelessWidget {
  const TossChipSelector({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.multiSelect = false,
    this.errorText,
    this.disabled = const {},
  });

  final String label;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final bool multiSelect;
  final String? errorText;

  /// Options that are shown as checked but can't be toggled by the user
  /// (e.g. a region already selected elsewhere).
  final Set<String> disabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: TossColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            final isDisabled = disabled.contains(option);
            return GestureDetector(
              onTap: isDisabled ? null : () => onToggle(option),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? TossColors.primary.withValues(alpha: isDisabled ? 0.5 : 1)
                      : TossColors.fieldFill,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDisabled) ...[
                      const Icon(Icons.lock, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      option,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : TossColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(fontSize: 12, color: TossColors.error),
          ),
        ],
      ],
    );
  }
}

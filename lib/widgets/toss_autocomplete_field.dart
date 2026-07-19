import 'package:flutter/material.dart';
import '../theme/toss_colors.dart';

/// [TossTextField]와 같은 스타일을 쓰되, [options] 목록에서 입력값을 검색해
/// 드롭다운으로 골라 넣을 수 있는 자동완성 필드. 목록에 없는 값도 직접 입력할 수 있다.
class TossAutocompleteField extends StatelessWidget {
  const TossAutocompleteField({
    super.key,
    required this.label,
    required this.options,
    required this.controller,
    required this.focusNode,
    this.errorText,
    this.onChanged,
  });

  final String label;
  final List<String> options;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? errorText;
  final ValueChanged<String>? onChanged;

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
        RawAutocomplete<String>(
          textEditingController: controller,
          focusNode: focusNode,
          optionsBuilder: (value) {
            final query = value.text.trim();
            if (query.isEmpty) return const Iterable<String>.empty();
            return options.where((option) => option.contains(query)).take(30);
          },
          onSelected: onChanged,
          fieldViewBuilder: (context, fieldController, fieldFocusNode, onFieldSubmitted) {
            return TextField(
              controller: fieldController,
              focusNode: fieldFocusNode,
              onChanged: onChanged,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: TossColors.textPrimary,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: TossColors.fieldFill,
                errorText: errorText,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: TossColors.primary, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: TossColors.error, width: 1.5),
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, resultOptions) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240, maxWidth: 400),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: resultOptions.length,
                    itemBuilder: (context, index) {
                      final option = resultOptions.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(option),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

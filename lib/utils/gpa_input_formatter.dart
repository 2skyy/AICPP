import 'package:flutter/services.dart';

class GpaInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) return oldValue;

    final parsed = double.tryParse(text);
    if (parsed == null) return newValue;

    final decimalIndex = text.indexOf('.');
    final hasExtraDecimals =
        decimalIndex != -1 && text.length - decimalIndex - 1 > 2;
    final rounded =
        hasExtraDecimals ? double.parse(parsed.toStringAsFixed(2)) : parsed;

    if (rounded > 4.5) return oldValue;
    if (!hasExtraDecimals) return newValue;

    final formatted = rounded.toStringAsFixed(2);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class Validators {
  Validators._();

  static final _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  static bool isValidEmail(String value) => _emailRegex.hasMatch(value);

  static bool isValidPassword(String value) => value.length >= 8;

  static bool isValidGpa(String value) {
    final gpa = double.tryParse(value);
    return gpa != null && gpa >= 0 && gpa <= 4.5;
  }
}

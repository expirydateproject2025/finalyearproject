class Validators {
  static String? email(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Please enter your email';
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  static String? password(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Please enter your password';
    }
    if (value!.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }

  static String? name(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Please enter your name';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value?.isEmpty ?? true) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }
}
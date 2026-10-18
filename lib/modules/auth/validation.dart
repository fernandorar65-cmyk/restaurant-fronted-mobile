import '../../core/utils/string.dart';

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? validateName(String value) {
  if (!isNonEmptyString(value)) {
    return 'El nombre es obligatorio';
  }

  if (value.trim().length < 2) {
    return 'El nombre debe tener al menos 2 caracteres';
  }

  return null;
}

String? validateEmail(String value) {
  if (!isNonEmptyString(value)) {
    return 'El correo es obligatorio';
  }

  if (!_emailPattern.hasMatch(value.trim())) {
    return 'Ingresa un correo válido';
  }

  return null;
}

String? validatePassword(String value) {
  if (!isNonEmptyString(value)) {
    return 'La contraseña es obligatoria';
  }

  if (value.length < 8) {
    return 'La contraseña debe tener al menos 8 caracteres';
  }

  return null;
}

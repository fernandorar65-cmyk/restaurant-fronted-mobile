/// Interruptores de funcionalidades. Una sección apagada no aparece en la navegación
/// y su ruta redirige, pero su código se conserva para reactivarla cambiando el valor.
class Features {
  Features._();

  /// Cola de cocina (/owner/sede/:local/cocina). Deshabilitada por ahora.
  static const bool kitchenQueue = false;
}

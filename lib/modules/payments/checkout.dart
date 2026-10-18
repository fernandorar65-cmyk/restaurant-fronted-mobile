import 'types.dart';

/// Cómo recibe el comensal su pedido: 'dine-in' | 'pickup' | 'delivery'
typedef FulfillmentMode = String;

const Map<FulfillmentMode, String> fulfillmentLabel = {
  'dine-in': 'En mesa',
  'pickup': 'Llego al local',
  'delivery': 'Delivery',
};

/// Todos los métodos con vista implementada en el checkout del comensal.
const List<PaymentMethod> checkoutMethods = ['card', 'yape', 'plin', 'transfer', 'cash'];

/// 'card' | 'yape' | 'plin' | 'transfer' | 'cash'
typedef CheckoutMethod = String;

/// Métodos que se ofrecen hoy, en el orden en que se muestran. El efectivo tiene su
/// vista (CashPayment) pero queda oculto hasta definir ese flujo.
const List<CheckoutMethod> enabledCheckoutMethods = ['card', 'yape', 'plin', 'transfer'];

/// Solo los métodos habilitados: /pago/cash redirige a elegir otro método.
bool isCheckoutMethod(Object? value) => value is String && enabledCheckoutMethods.contains(value);

class CheckoutMethodInfo {
  const CheckoutMethodInfo({required this.hint, required this.icon});

  final String hint;

  /// Trazo SVG (heroicons) del ícono.
  final String icon;
}

const Map<CheckoutMethod, CheckoutMethodInfo> checkoutMethodInfo = {
  'card': CheckoutMethodInfo(
    hint: 'Crédito o débito',
    icon:
        'M2.25 8.25h19.5M2.25 9h19.5m-16.5 5.25h6m-6 2.25h3m-3.75 3h15a2.25 2.25 0 0 0 2.25-2.25V6.75A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25v10.5A2.25 2.25 0 0 0 4.5 19.5Z',
  ),
  'yape': CheckoutMethodInfo(
    hint: 'Escanea el QR desde tu app',
    icon:
        'M10.5 1.5H8.25A2.25 2.25 0 0 0 6 3.75v16.5a2.25 2.25 0 0 0 2.25 2.25h7.5A2.25 2.25 0 0 0 18 20.25V3.75a2.25 2.25 0 0 0-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 18.75h3',
  ),
  'plin': CheckoutMethodInfo(
    hint: 'Escanea el QR desde tu banco',
    icon:
        'M10.5 1.5H8.25A2.25 2.25 0 0 0 6 3.75v16.5a2.25 2.25 0 0 0 2.25 2.25h7.5A2.25 2.25 0 0 0 18 20.25V3.75a2.25 2.25 0 0 0-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 18.75h3',
  ),
  'transfer': CheckoutMethodInfo(
    hint: 'Desde tu banco, con comprobante',
    icon:
        'M12 21v-8.25M15.75 21v-8.25M8.25 21v-8.25M3 9l9-6 9 6m-1.5 12V10.332A48.36 48.36 0 0 0 12 9.75c-2.551 0-5.056.2-7.5.582V21M3 21h18M12 6.75h.008v.008H12V6.75Z',
  ),
  'cash': CheckoutMethodInfo(
    hint: 'Pagas al recibir o en caja',
    icon:
        'M2.25 18.75a60.07 60.07 0 0 1 15.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 0 1 3 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 0 0-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 0 1-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 0 0 3 15h-.75M15 10.5a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm3 0h.008v.008H18V10.5Zm-12 0h.008v.008H6V10.5Z',
  ),
};

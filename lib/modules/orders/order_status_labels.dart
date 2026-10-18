import '../../widgets/base/status_badge.dart' show StatusTone;
import '../auth/permissions.dart';
import 'types.dart';

const Map<AttentionStatus, String> attentionStatusLabel = {
  'open': 'Abierta',
  'account-requested': 'Cuenta solicitada',
  'closed': 'Cerrada',
  'cancelled': 'Cancelada',
};

const Map<AttentionStatus, String> attentionStatusBadgeClass = {
  'open': 'bg-secondary-container text-on-secondary-container',
  'account-requested': 'bg-tertiary-fixed text-on-tertiary-container',
  'closed': 'bg-surface-container-high text-on-surface-variant',
  'cancelled': 'bg-error-container text-on-error-container',
};

const Map<OrderedProductStatus, String> orderedProductStatusLabel = {
  'sent': 'Enviado',
  'preparing': 'En preparación',
  'ready': 'Listo',
  'delivered': 'Entregado',
  'rejected': 'Rechazado',
  'cancelled': 'Cancelado',
};

const Map<OrderedProductStatus, String> orderedProductStatusHint = {
  'sent': 'El restaurante todavía no confirmó este producto.',
  'preparing': 'Se está preparando en cocina.',
  'ready': 'Listo para servir en mesa.',
  'delivered': 'Ya está en la mesa.',
  'rejected': 'La sede rechazó este producto.',
  'cancelled': 'Este producto fue cancelado.',
};

const List<OrderedProductStatus> orderedProductStatusSteps = ['sent', 'preparing', 'ready', 'delivered'];

const Map<OrderedProductStatus, String> orderedProductBadgeClass = {
  'sent': 'bg-secondary-container text-on-secondary-container',
  'preparing': 'bg-primary text-on-primary',
  'ready': 'bg-tertiary-fixed text-on-tertiary-container',
  'delivered': 'bg-success-container text-on-success-container',
  'rejected': 'bg-error-container text-on-error-container',
  'cancelled': 'bg-surface-container-high text-on-surface-variant',
};

const Map<OrderedProductStatus, OrderedProductStatus> _nextProductStatus = {
  // Confirmar un pedido lo manda directo a cocina (ya no existe el paso "confirmado").
  'sent': 'preparing',
  'preparing': 'ready',
  'ready': 'delivered',
};

const Map<OrderedProductStatus, String> _nextProductActionLabel = {
  'sent': 'Confirmar',
  'preparing': 'Marcar listo',
  'ready': 'Marcar entregado',
};

OrderedProductStatus? nextOrderedProductStatus(OrderedProductStatus status) => _nextProductStatus[status];

String? nextOrderedProductActionLabel(OrderedProductStatus status) => _nextProductActionLabel[status];

/// Transiciones válidas de un producto solicitado.
const Map<OrderedProductStatus, List<OrderedProductStatus>> _allowedTransitions = {
  'sent': ['preparing', 'rejected', 'cancelled'],
  'preparing': ['ready', 'cancelled'],
  'ready': ['delivered', 'cancelled'],
  'delivered': [],
  'rejected': [],
  'cancelled': [],
};

/// Permiso necesario para avanzar un producto desde cada estado (detalle del pedido y tablero).
const Map<OrderedProductStatus, Permission> orderedProductStepPermission = {
  'sent': 'orders.manage',
  'preparing': 'kitchen.manage',
  // Servir un plato listo lo hace quien gestiona pedidos (mozos, jefe de sala).
  'ready': 'orders.manage',
};

bool canTransitionOrderedProduct(OrderedProductStatus from, OrderedProductStatus to) => _allowedTransitions[from]?.contains(to) ?? false;

bool canRejectOrderedProduct(OrderedProductStatus status) => canTransitionOrderedProduct(status, 'rejected');

bool canCancelOrderedProduct(OrderedProductStatus status) => canTransitionOrderedProduct(status, 'cancelled');

/// Producto en curso: todavía no se entregó ni se descartó.
bool isPendingProduct(OrderedProductStatus status) => status == 'sent' || status == 'preparing' || status == 'ready';

bool isBillableProduct(OrderedProductStatus status) => status != 'rejected' && status != 'cancelled';

/// Tono visual único por estado (se usa con StatusBadge, que agrega el ícono).
const Map<AttentionStatus, StatusTone> attentionStatusTone = {
  'open': 'info',
  'account-requested': 'warning',
  'closed': 'muted',
  'cancelled': 'danger',
};

const Map<OrderedProductStatus, StatusTone> orderedProductStatusTone = {
  'sent': 'neutral',
  'preparing': 'progress',
  'ready': 'success',
  'delivered': 'muted',
  'rejected': 'danger',
  'cancelled': 'muted',
};

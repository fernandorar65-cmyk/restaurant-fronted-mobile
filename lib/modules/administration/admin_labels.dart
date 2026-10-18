import 'types.dart';

// Los valores de tono son `StatusTone` del badge de estado:
// 'neutral' | 'info' | 'progress' | 'success' | 'warning' | 'danger' | 'muted'.
// Las clases (`*Class`) son las de Tailwind del front web; en Flutter sirven como
// referencia del token de color a usar.

const Map<EmployeeArea, String> employeeAreaLabel = {
  'kitchen': 'Cocina',
  'floor': 'Sala',
  'support': 'Soporte',
  'management': 'Dirección',
};

const Map<EmployeeStatus, String> employeeStatusLabel = {
  'active': 'Activo',
  'on-leave': 'Excedencia',
  'inactive': 'Inactivo',
};

const Map<EmployeeStatus, String> employeeStatusClass = {
  'active': 'bg-primary/10 text-primary',
  'on-leave': 'bg-tertiary-fixed text-on-tertiary-container',
  'inactive': 'bg-surface-container-high text-on-surface-variant',
};

const Map<InventoryStatus, String> inventoryStatusLabel = {
  'ok': 'Óptimo',
  'low': 'Bajo',
  'critical': 'Crítico',
};

const Map<InventoryStatus, String> inventoryStatusClass = {
  'ok': 'bg-success-container text-on-success-container',
  'low': 'bg-tertiary-fixed text-on-tertiary-container',
  'critical': 'bg-error-container text-on-error-container',
};

const Map<InventoryStatus, String> inventoryStatusTone = {
  'ok': 'success',
  'low': 'warning',
  'critical': 'danger',
};

const Map<EmployeeStatus, String> employeeStatusTone = {
  'active': 'success',
  'on-leave': 'warning',
  'inactive': 'muted',
};

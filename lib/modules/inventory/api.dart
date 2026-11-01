import '../../core/http/http_client.dart';
import '../../core/utils/json.dart';
import '../../core/utils/string.dart';
import '../../core/utils/time.dart';
import '../administration/api.dart' show inventoryStatusFor;
import '../expenses/api.dart';
import '../expenses/types.dart';
import 'types.dart';

double _round(num value) => (value * 1000).roundToDouble() / 1000;

double _roundCents(num value) => (value * 100).roundToDouble() / 100;

/// Insumos de una sede. Backend: GET /restaurants/:id/supplies
Future<List<Supply>> fetchSupplies(String restaurantId) async {
  final payload = await http('/inventoryItems?${whereQuery({'restaurantId': restaurantId})}');
  final items = asList(payload).map(Supply.tryParse).whereType<Supply>().where((item) => item.restaurantId == restaurantId).toList()
    ..sort((a, b) => normalizeSearch(a.name).compareTo(normalizeSearch(b.name)));
  return items;
}

JsonMap _cleanSupply(SupplyDraft draft) => {
      'name': draft.name.trim(),
      'category': draft.category,
      'unit': draft.unit,
      'minStock': _round(draft.minStock),
      'unitCost': _roundCents(draft.unitCost),
      'supplier': draft.supplier.trim(),
      'isActive': draft.isActive,
    };

/// POST /restaurants/:id/supplies
Future<Supply> createSupply(String restaurantId, SupplyDraft draft) async {
  final stock = _round(draft.stock);
  final payload = await http(
    '/inventoryItems',
    method: 'POST',
    body: {
      'restaurantId': restaurantId,
      ..._cleanSupply(draft),
      'stock': stock,
      'status': inventoryStatusFor(stock, draft.minStock),
      'updatedAt': nowIso(),
    },
  );
  final supply = Supply.tryParse(payload);
  if (supply == null) throw HttpError('No se pudo crear el insumo.', 500);
  return supply;
}

/// PATCH /supplies/:id — el stock solo cambia con movimientos.
Future<Supply> updateSupply(Supply item, SupplyDraft draft) async {
  final payload = await http(
    '/inventoryItems/${item.id}',
    method: 'PATCH',
    body: {..._cleanSupply(draft), 'status': inventoryStatusFor(item.stock, draft.minStock), 'updatedAt': nowIso()},
  );
  final supply = Supply.tryParse(payload);
  if (supply == null) throw HttpError('No se pudo guardar el insumo.', 500);
  return supply;
}

/// Movimientos de una sede, del más reciente al más antiguo. Backend: GET /restaurants/:id/stock-movements
Future<List<StockMovement>> fetchMovements(String restaurantId) async {
  final payload = await http('/inventoryMovements?${whereQuery({'restaurantId': restaurantId})}');
  final movements = asList(payload)
      .map(StockMovement.tryParse)
      .whereType<StockMovement>()
      .where((movement) => movement.restaurantId == restaurantId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return movements;
}

/// Stock resultante de aplicar un movimiento.
double stockAfter(num stock, MovementType type, num quantity) {
  if (type == 'count') return _round(quantity);
  return _round(type == 'purchase' ? stock + quantity : stock - quantity);
}

String _pad(int value) => '$value'.padLeft(2, '0');

String _today() {
  final date = DateTime.now();
  return '${date.year}-${_pad(date.month)}-${_pad(date.day)}';
}

/// Muestra una cantidad sin decimales sobrantes ("2" y no "2.0"), como en JS.
String _formatQuantity(num value) => value == value.roundToDouble() ? '${value.round()}' : '$value';

/// Registra un movimiento: actualiza el stock del insumo, guarda el movimiento y, si es una
/// compra marcada como gasto, crea el gasto en Cuentas → Gastos.
/// Backend: POST /supplies/:id/movements (una sola transacción).
Future<({Supply item, StockMovement movement})> registerMovement(Supply item, MovementDraft draft, String? createdBy) async {
  final nextStock = stockAfter(item.stock, draft.type, draft.quantity);
  if (nextStock < 0) throw HttpError('No hay stock suficiente: quedan ${_formatQuantity(item.stock)} ${item.unit}.', 400);

  final isPurchase = draft.type == 'purchase';
  final draftUnitCost = draft.unitCost;
  final unitCost = isPurchase && draftUnitCost != null ? _roundCents(draftUnitCost) : null;
  final now = nowIso();

  // 1. Gasto (solo compras)
  String? expenseId;
  if (isPurchase && draft.registerExpense && unitCost != null && unitCost * draft.quantity > 0) {
    final categories = await fetchExpenseCategories();
    final category = categories.where((entry) => entry.id == 'supplies').firstOrNull ?? categories.firstOrNull;
    if (category != null) {
      final supplier = draft.supplier.trim();
      final expense = await createExpense(
        item.restaurantId,
        ExpenseDraft(
          category: category.id,
          kind: 'variable',
          description: '${item.name} (${_formatQuantity(draft.quantity)} ${item.unit})',
          amount: unitCost * draft.quantity,
          date: _today(),
          supplier: supplier.isNotEmpty ? supplier : (item.supplier.isNotEmpty ? item.supplier : null),
          paymentMethod: 'transfer',
          notes: 'Registrado desde Insumos',
        ),
        createdBy,
      );
      expenseId = expense.id;
      await waitForJsonServer();
    }
  }

  // 2. Insumo
  final patch = <String, dynamic>{'stock': nextStock, 'status': inventoryStatusFor(nextStock, item.minStock), 'updatedAt': now};
  if (unitCost != null) patch['unitCost'] = unitCost;
  if (isPurchase && draft.supplier.trim().isNotEmpty) patch['supplier'] = draft.supplier.trim();
  final updated = Supply.tryParse(await http('/inventoryItems/${item.id}', method: 'PATCH', body: patch));
  if (updated == null) throw HttpError('No se pudo actualizar el stock.', 500);
  await waitForJsonServer();

  // 3. Movimiento
  final payload = await http(
    '/inventoryMovements',
    method: 'POST',
    body: {
      'restaurantId': item.restaurantId,
      'itemId': item.id,
      'itemName': item.name,
      'unit': item.unit,
      'type': draft.type,
      'delta': _round(nextStock - item.stock),
      'stockAfter': nextStock,
      'unitCost': unitCost,
      'reason': draft.reason.trim(),
      'expenseId': expenseId,
      'createdBy': createdBy,
      'createdAt': now,
    },
  );
  final movement = StockMovement.tryParse(payload);
  if (movement == null) throw HttpError('No se pudo registrar la ${(movementTypeLabel[draft.type] ?? '').toLowerCase()}.', 500);

  return (item: updated, movement: movement);
}

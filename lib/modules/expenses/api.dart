import '../../core/http/http_client.dart';
import '../../core/utils/json.dart';
import '../../core/utils/time.dart';
import 'types.dart';

/// Error del API de gastos (equivale a `throw new Error(...)` en la web).
class ExpensesApiError implements Exception {
  ExpensesApiError(this.message);

  final String message;

  @override
  String toString() => message;
}

bool _isIdLike(Object? value) => value is String || value is num;

bool _isExpense(Object? value) {
  if (value is! Map) return false;
  return _isIdLike(value['id']) &&
      _isIdLike(value['restaurantId']) &&
      value['category'] is String &&
      value['amount'] is num &&
      value['date'] is String;
}

Expense _toExpense(Object? value) => Expense.fromJson(asMap(value));

JsonMap _clean(ExpenseDraft draft) {
  final supplier = draft.supplier?.trim();

  return {
    'category': draft.category,
    'kind': draft.kind,
    'description': draft.description.trim(),
    'amount': (draft.amount * 100).round() / 100,
    'date': draft.date,
    'supplier': supplier == null || supplier.isEmpty ? null : supplier,
    'paymentMethod': draft.paymentMethod,
    'notes': draft.notes.trim(),
  };
}

/// Gastos de una sede entre dos fechas (inclusive), del más reciente al más antiguo.
/// Contrato pensado para el backend: GET /restaurants/:id/expenses?from=…&to=…
Future<List<Expense>> fetchExpenses(String restaurantId, String from, String to) async {
  // json-server convierte "1" en número al filtrar, así que la sede se filtra aquí.
  final payload = await http('/expenses?${encodeQuery('date:gte')}=${encodeQuery(from)}&${encodeQuery('date:lte')}=${encodeQuery(to)}');
  final rows = payload is List ? payload.where(_isExpense).map(_toExpense).toList() : <Expense>[];
  return rows.where((expense) => expense.restaurantId == restaurantId).toList()
    ..sort((a, b) => a.date == b.date ? b.createdAt.compareTo(a.createdAt) : b.date.compareTo(a.date));
}

/// POST /restaurants/:id/expenses
Future<Expense> createExpense(String restaurantId, ExpenseDraft draft, String? createdBy) async {
  final payload = await http('/expenses', method: 'POST', body: {
    'restaurantId': restaurantId,
    ..._clean(draft),
    'createdBy': createdBy,
    'createdAt': nowIso(),
  });
  if (!_isExpense(payload)) throw ExpensesApiError('No se pudo registrar el gasto.');
  return _toExpense(payload);
}

/// PATCH /expenses/:id
Future<Expense> updateExpense(String id, ExpenseDraft draft) async {
  final payload = await http('/expenses/$id', method: 'PATCH', body: _clean(draft));
  if (!_isExpense(payload)) throw ExpensesApiError('No se pudo guardar el gasto.');
  return _toExpense(payload);
}

/// DELETE /expenses/:id
Future<void> deleteExpense(String id) async {
  await http('/expenses/$id', method: 'DELETE');
}

// Categorías

bool _isExpenseCategory(Object? value) => value is Map && _isIdLike(value['id']) && value['name'] is String;

ExpenseCategory _toExpenseCategory(Object? value) => ExpenseCategory.fromJson(asMap(value));

JsonMap _cleanCategory(ExpenseCategoryDraft draft) =>
    {'name': draft.name.trim(), 'hint': draft.hint.trim(), 'defaultKind': draft.defaultKind, 'icon': draft.icon};

/// GET /expense-categories — categorías de la organización, compartidas por sus sedes.
Future<List<ExpenseCategory>> fetchExpenseCategories() async {
  final payload = await http('/expenseCategories');
  return payload is List ? payload.where(_isExpenseCategory).map(_toExpenseCategory).toList() : [];
}

/// POST /expense-categories
Future<ExpenseCategory> createExpenseCategory(String id, ExpenseCategoryDraft draft) async {
  final payload = await http('/expenseCategories', method: 'POST', body: {'id': id, ..._cleanCategory(draft)});
  if (!_isExpenseCategory(payload)) throw ExpensesApiError('No se pudo crear la categoría.');
  return _toExpenseCategory(payload);
}

/// PATCH /expense-categories/:id
Future<ExpenseCategory> updateExpenseCategory(String id, ExpenseCategoryDraft draft) async {
  final payload = await http('/expenseCategories/$id', method: 'PATCH', body: _cleanCategory(draft));
  if (!_isExpenseCategory(payload)) throw ExpensesApiError('No se pudo guardar la categoría.');
  return _toExpenseCategory(payload);
}

/// Cuántos gastos (de todas las sedes) usan cada categoría.
Future<Map<String, int>> countExpensesByCategory() async {
  final payload = await http('/expenses');
  final counts = <String, int>{};
  for (final expense in payload is List ? payload.where(_isExpense) : const []) {
    final category = asString((expense as Map)['category']);
    counts[category] = (counts[category] ?? 0) + 1;
  }
  return counts;
}

Future<void> _pause(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

/// DELETE /expense-categories/:id?moveTo=… — los gastos de la categoría pasan a `moveTo`.
///
/// En el backend será una sola transacción. json-server recarga db.json tras cada escritura
/// y puede perder un cambio que llega justo en ese momento (responde 200 igual), así que
/// aquí se comprueba el resultado y se reintenta lo que no quedó aplicado.
Future<void> deleteExpenseCategory(String id, String? moveTo) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    if (attempt > 0) await _pause(jsonServerWriteGapMs);

    final results = await Future.wait<Object?>([http('/expenses'), fetchExpenseCategories()]);
    final expenses = results[0];
    final categories = results[1] as List<ExpenseCategory>;
    final pending = moveTo != null && moveTo.isNotEmpty && expenses is List
        ? expenses.where(_isExpense).where((item) => asString((item as Map)['category']) == id).toList()
        : const [];
    final exists = categories.any((category) => category.id == id);

    if (pending.isEmpty && !exists) return;

    for (final expense in pending) {
      await http('/expenses/${asId((expense as Map)['id'])}', method: 'PATCH', body: {'category': moveTo});
    }
    if (exists) {
      if (pending.isNotEmpty) await _pause(jsonServerWriteGapMs);
      await http('/expenseCategories/$id', method: 'DELETE');
    }
  }

  throw ExpensesApiError('No se pudo eliminar la categoría. Inténtalo de nuevo.');
}

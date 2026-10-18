import '../../core/utils/json.dart';

/// Categoría de gasto. Las define la organización (se pueden agregar, editar y eliminar)
/// y se comparten entre todas sus sedes.
class ExpenseCategory {
  const ExpenseCategory({required this.id, required this.name, required this.hint, required this.defaultKind, required this.icon});

  final String id;
  final String name;

  /// Texto de ayuda: qué entra en esta categoría.
  final String hint;

  /// Tipo sugerido al elegir la categoría (se puede cambiar en cada gasto).
  final ExpenseKind defaultKind;
  final ExpenseIcon icon;

  factory ExpenseCategory.fromJson(JsonMap json) => ExpenseCategory(
        id: asId(json['id']),
        name: asString(json['name']),
        hint: asString(json['hint']),
        defaultKind: json['defaultKind'] == 'fixed' ? 'fixed' : 'variable',
        icon: isExpenseIcon(json['icon']) ? json['icon'] as String : 'dots',
      );

  JsonMap toJson() => {'id': id, 'name': name, 'hint': hint, 'defaultKind': defaultKind, 'icon': icon};

  ExpenseCategory copyWith({String? id, String? name, String? hint, ExpenseKind? defaultKind, ExpenseIcon? icon}) => ExpenseCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        hint: hint ?? this.hint,
        defaultKind: defaultKind ?? this.defaultKind,
        icon: icon ?? this.icon,
      );
}

/// `Omit<ExpenseCategory, 'id'>`
class ExpenseCategoryDraft {
  const ExpenseCategoryDraft({required this.name, required this.hint, required this.defaultKind, required this.icon});

  final String name;
  final String hint;
  final ExpenseKind defaultKind;
  final ExpenseIcon icon;

  factory ExpenseCategoryDraft.fromJson(JsonMap json) => ExpenseCategoryDraft(
        name: asString(json['name']),
        hint: asString(json['hint']),
        defaultKind: json['defaultKind'] == 'fixed' ? 'fixed' : 'variable',
        icon: isExpenseIcon(json['icon']) ? json['icon'] as String : 'dots',
      );

  factory ExpenseCategoryDraft.fromCategory(ExpenseCategory category) =>
      ExpenseCategoryDraft(name: category.name, hint: category.hint, defaultKind: category.defaultKind, icon: category.icon);

  JsonMap toJson() => {'name': name, 'hint': hint, 'defaultKind': defaultKind, 'icon': icon};

  ExpenseCategoryDraft copyWith({String? name, String? hint, ExpenseKind? defaultKind, ExpenseIcon? icon}) => ExpenseCategoryDraft(
        name: name ?? this.name,
        hint: hint ?? this.hint,
        defaultKind: defaultKind ?? this.defaultKind,
        icon: icon ?? this.icon,
      );
}

/// Fijo: se repite cada mes (alquiler, sueldos). Variable: depende de la operación (insumos).
/// 'fixed' | 'variable'
typedef ExpenseKind = String;

/// 'transfer' | 'card' | 'cash' | 'direct-debit'
typedef ExpensePaymentMethod = String;

/// Gasto registrado en una sede.
class Expense {
  const Expense({
    required this.id,
    required this.restaurantId,
    required this.category,
    required this.kind,
    required this.description,
    required this.amount,
    required this.date,
    this.supplier,
    required this.paymentMethod,
    required this.notes,
    this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String restaurantId;

  /// Id de la categoría (`expenseCategories`).
  final String category;
  final ExpenseKind kind;
  final String description;
  final double amount;

  /// Fecha del gasto, YYYY-MM-DD.
  final String date;
  final String? supplier;
  final ExpensePaymentMethod paymentMethod;
  final String notes;
  final String? createdBy;
  final String createdAt;

  factory Expense.fromJson(JsonMap json) {
    final supplier = asStringOrNull(json['supplier']);
    final date = asString(json['date']);

    return Expense(
      id: asId(json['id']),
      restaurantId: asId(json['restaurantId']),
      category: asString(json['category']),
      kind: json['kind'] == 'fixed' ? 'fixed' : 'variable',
      description: asString(json['description']),
      amount: asDouble(json['amount']),
      date: date,
      supplier: supplier == null || supplier.isEmpty ? null : supplier,
      paymentMethod: asStringOrNull(json['paymentMethod']) ?? 'transfer',
      notes: asString(json['notes']),
      createdBy: asStringOrNull(json['createdBy']),
      createdAt: asStringOrNull(json['createdAt']) ?? date,
    );
  }

  JsonMap toJson() => {
        'id': id,
        'restaurantId': restaurantId,
        'category': category,
        'kind': kind,
        'description': description,
        'amount': amount,
        'date': date,
        'supplier': supplier,
        'paymentMethod': paymentMethod,
        'notes': notes,
        'createdBy': createdBy,
        'createdAt': createdAt,
      };

  Expense copyWith({
    String? id,
    String? restaurantId,
    String? category,
    ExpenseKind? kind,
    String? description,
    double? amount,
    String? date,
    String? supplier,
    ExpensePaymentMethod? paymentMethod,
    String? notes,
    String? createdBy,
    String? createdAt,
  }) =>
      Expense(
        id: id ?? this.id,
        restaurantId: restaurantId ?? this.restaurantId,
        category: category ?? this.category,
        kind: kind ?? this.kind,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        supplier: supplier ?? this.supplier,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        notes: notes ?? this.notes,
        createdBy: createdBy ?? this.createdBy,
        createdAt: createdAt ?? this.createdAt,
      );
}

/// `Pick<Expense, 'category' | 'kind' | 'description' | 'amount' | 'date' | 'supplier' | 'paymentMethod' | 'notes'>`
class ExpenseDraft {
  const ExpenseDraft({
    required this.category,
    required this.kind,
    required this.description,
    required this.amount,
    required this.date,
    this.supplier,
    required this.paymentMethod,
    required this.notes,
  });

  final String category;
  final ExpenseKind kind;
  final String description;
  final double amount;
  final String date;
  final String? supplier;
  final ExpensePaymentMethod paymentMethod;
  final String notes;

  factory ExpenseDraft.fromJson(JsonMap json) => ExpenseDraft(
        category: asString(json['category']),
        kind: json['kind'] == 'fixed' ? 'fixed' : 'variable',
        description: asString(json['description']),
        amount: asDouble(json['amount']),
        date: asString(json['date']),
        supplier: asStringOrNull(json['supplier']),
        paymentMethod: asStringOrNull(json['paymentMethod']) ?? 'transfer',
        notes: asString(json['notes']),
      );

  factory ExpenseDraft.fromExpense(Expense expense) => ExpenseDraft(
        category: expense.category,
        kind: expense.kind,
        description: expense.description,
        amount: expense.amount,
        date: expense.date,
        supplier: expense.supplier,
        paymentMethod: expense.paymentMethod,
        notes: expense.notes,
      );

  JsonMap toJson() => {
        'category': category,
        'kind': kind,
        'description': description,
        'amount': amount,
        'date': date,
        'supplier': supplier,
        'paymentMethod': paymentMethod,
        'notes': notes,
      };

  ExpenseDraft copyWith({
    String? category,
    ExpenseKind? kind,
    String? description,
    double? amount,
    String? date,
    String? supplier,
    ExpensePaymentMethod? paymentMethod,
    String? notes,
  }) =>
      ExpenseDraft(
        category: category ?? this.category,
        kind: kind ?? this.kind,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        supplier: supplier ?? this.supplier,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        notes: notes ?? this.notes,
      );
}

const Map<ExpenseKind, String> expenseKindLabel = {
  'fixed': 'Fijo',
  'variable': 'Variable',
};

const Map<ExpensePaymentMethod, String> expensePaymentMethodLabel = {
  'transfer': 'Transferencia',
  'card': 'Tarjeta',
  'cash': 'Efectivo',
  'direct-debit': 'Débito automático',
};

/// Íconos disponibles para las categorías (trazos heroicons).
const Map<String, String> expenseIcons = {
  'bag':
      'M15.75 10.5V6a3.75 3.75 0 1 0-7.5 0v4.5m11.356-1.993 1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 0 1-1.12-1.243l1.264-12A1.125 1.125 0 0 1 5.513 7.5h12.974c.576 0 1.059.435 1.119 1.007Z',
  'people':
      'M15 19.128a9.38 9.38 0 0 0 2.625.372 9.337 9.337 0 0 0 4.121-.952 4.125 4.125 0 0 0-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 0 1 8.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0 1 11.964-3.07M12 6.375a3.375 3.375 0 1 1-6.75 0 3.375 3.375 0 0 1 6.75 0Zm8.25 2.25a2.625 2.625 0 1 1-5.25 0 2.625 2.625 0 0 1 5.25 0Z',
  'home':
      'm2.25 12 8.954-8.955a1.126 1.126 0 0 1 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25',
  'bolt': 'm3.75 13.5 10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75Z',
  'wrench':
      'M11.42 15.17 17.25 21A2.652 2.652 0 0 0 21 17.25l-5.877-5.877M11.42 15.17l2.496-3.03c.317-.384.74-.626 1.208-.766M11.42 15.17l-4.655 5.653a2.548 2.548 0 1 1-3.586-3.586l6.837-5.63m5.108-.233c.55-.164 1.163-.188 1.743-.14a4.5 4.5 0 0 0 4.486-6.336l-3.276 3.277a3.004 3.004 0 0 1-2.25-2.25l3.276-3.276a4.5 4.5 0 0 0-6.336 4.486c.091 1.076-.071 2.264-.904 2.95l-.102.085m-1.745 1.437L5.909 7.5H4.5L2.25 3.75l1.5-1.5L7.5 4.5v1.409l4.26 4.26m-1.745 1.437 1.745-1.437m6.615 8.206L15.75 15.75M4.867 19.125h.008v.008h-.008v-.008Z',
  'megaphone':
      'M10.34 15.84c-.688-.06-1.386-.09-2.09-.09H7.5a4.5 4.5 0 1 1 0-9h.75c.704 0 1.402-.03 2.09-.09m0 9.18c.253.962.584 1.892.985 2.783.247.55.06 1.21-.463 1.511l-.657.38c-.551.318-1.26.117-1.527-.461a20.845 20.845 0 0 1-1.44-4.282m3.102.069a18.03 18.03 0 0 1-.59-4.59c0-1.586.205-3.124.59-4.59m0 9.18a23.848 23.848 0 0 1 8.835 2.535M10.34 6.66a23.847 23.847 0 0 0 8.835-2.535m0 0A23.74 23.74 0 0 0 18.795 3m.38 1.125a23.91 23.91 0 0 1 1.014 5.395m-1.014 8.855c-.118.38-.245.754-.38 1.125m.38-1.125a23.91 23.91 0 0 0 1.014-5.395m0-3.46c.495.413.811 1.035.811 1.73 0 .695-.316 1.317-.811 1.73m0-3.46a24.347 24.347 0 0 1 0 3.46',
  'receipt':
      'M9 14.25l6-6m4.5-3.493V21.75l-3.75-1.5-3.75 1.5-3.75-1.5-3.75 1.5V4.757c0-1.108.806-2.057 1.907-2.185a48.507 48.507 0 0 1 11.186 0c1.1.128 1.907 1.077 1.907 2.185ZM9.75 9h.008v.008H9.75V9Zm.375 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm4.125 4.5h.008v.008h-.008V13.5Zm.375 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Z',
  'dots':
      'M6.75 12a.75.75 0 1 1-1.5 0 .75.75 0 0 1 1.5 0ZM12.75 12a.75.75 0 1 1-1.5 0 .75.75 0 0 1 1.5 0ZM18.75 12a.75.75 0 1 1-1.5 0 .75.75 0 0 1 1.5 0Z',
  'truck':
      'M8.25 18.75a1.5 1.5 0 0 1-3 0m3 0a1.5 1.5 0 0 0-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 0 1-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 0 1-3 0m3 0a1.5 1.5 0 0 0-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 0 0-3.213-9.193 2.056 2.056 0 0 0-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.422-1.048-.987-1.106a48.554 48.554 0 0 0-10.026 0 1.106 1.106 0 0 0-.987 1.106v7.635m12-6.677v6.677m0 4.5v-4.5m0 0h-12',
  'sparkles':
      'M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09Z',
  'computer':
      'M9 17.25v1.007a3 3 0 0 1-.879 2.122L7.5 21h9l-.621-.621A3 3 0 0 1 15 18.257V17.25m6-12V15a2.25 2.25 0 0 1-2.25 2.25H5.25A2.25 2.25 0 0 1 3 15V5.25m18 0A2.25 2.25 0 0 0 18.75 3H5.25A2.25 2.25 0 0 0 3 5.25m18 0V12a2.25 2.25 0 0 1-2.25 2.25H5.25A2.25 2.25 0 0 1 3 12V5.25',
  'shield':
      'M9 12.75 11.25 15 15 9.75m-3-7.036A11.959 11.959 0 0 1 3.598 6 11.99 11.99 0 0 0 3 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285Z',
};

/// Clave de [expenseIcons].
typedef ExpenseIcon = String;

bool isExpenseIcon(Object? value) => value is String && expenseIcons.containsKey(value);

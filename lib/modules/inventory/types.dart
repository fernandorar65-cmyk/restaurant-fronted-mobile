import '../../core/utils/json.dart';
import '../administration/api.dart' show inventoryStatusFor;
import '../administration/types.dart' show InventoryStatus;

export '../administration/types.dart' show InventoryStatus;

/// Categorías de insumo para ordenar la despensa.
/// 'meat' | 'seafood' | 'produce' | 'dairy' | 'pantry' | 'drinks' | 'cleaning' | 'other'
typedef SupplyCategory = String;

/// `SUPPLY_CATEGORIES` en TS.
const List<SupplyCategory> supplyCategories = ['meat', 'seafood', 'produce', 'dairy', 'pantry', 'drinks', 'cleaning', 'other'];

const Map<SupplyCategory, String> supplyCategoryLabel = {
  'meat': 'Carnes',
  'seafood': 'Pescados y mariscos',
  'produce': 'Verduras y frutas',
  'dairy': 'Lácteos y huevos',
  'pantry': 'Despensa',
  'drinks': 'Bebidas',
  'cleaning': 'Limpieza y descartables',
  'other': 'Otros',
};

bool isSupplyCategory(Object? value) => value is String && supplyCategories.contains(value);

/// `SUPPLY_UNITS` en TS.
const List<String> supplyUnits = ['kg', 'g', 'l', 'ml', 'ud', 'caja', 'botella'];

bool _isId(Object? value) => value is String || value is num;

/// Insumo de una sede (colección `inventoryItems`, compartida con el inventario de Administración).
class Supply {
  const Supply({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.category,
    required this.unit,
    required this.stock,
    required this.minStock,
    required this.unitCost,
    required this.status,
    required this.supplier,
    required this.updatedAt,
    required this.isActive,
  });

  final String id;
  final String restaurantId;
  final String name;
  final SupplyCategory category;
  final String unit;
  final double stock;
  final double minStock;

  /// Costo de la última compra por unidad.
  final double unitCost;
  final InventoryStatus status;
  final String supplier;
  final String updatedAt;
  final bool isActive;

  /// Equivalente a `isSupply` + `toSupply`: null si faltan campos obligatorios.
  static Supply? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }

    final json = asMap(value);

    if (!_isId(json['id']) ||
        !_isId(json['restaurantId']) ||
        json['name'] is! String ||
        json['stock'] is! num ||
        json['minStock'] is! num) {
      return null;
    }

    return Supply.fromJson(json);
  }

  /// El estado se recalcula siempre desde stock y mínimo.
  factory Supply.fromJson(JsonMap json) {
    final stock = asDouble(json['stock']);
    final minStock = asDouble(json['minStock']);

    return Supply(
      id: asId(json['id']),
      restaurantId: asId(json['restaurantId']),
      name: asString(json['name']),
      category: isSupplyCategory(json['category']) ? json['category'] as String : 'other',
      unit: asStringOrNull(json['unit']) ?? 'ud',
      unitCost: json['unitCost'] is num ? (json['unitCost'] as num).toDouble() : 0,
      stock: stock,
      minStock: minStock,
      status: inventoryStatusFor(stock, minStock),
      supplier: asString(json['supplier']),
      updatedAt: asString(json['updatedAt']),
      isActive: json['isActive'] is bool ? json['isActive'] as bool : true,
    );
  }

  JsonMap toJson() => {
        'id': id,
        'restaurantId': restaurantId,
        'name': name,
        'category': category,
        'unit': unit,
        'stock': stock,
        'minStock': minStock,
        'unitCost': unitCost,
        'status': status,
        'supplier': supplier,
        'updatedAt': updatedAt,
        'isActive': isActive,
      };

  Supply copyWith({
    String? id,
    String? restaurantId,
    String? name,
    SupplyCategory? category,
    String? unit,
    double? stock,
    double? minStock,
    double? unitCost,
    InventoryStatus? status,
    String? supplier,
    String? updatedAt,
    bool? isActive,
  }) =>
      Supply(
        id: id ?? this.id,
        restaurantId: restaurantId ?? this.restaurantId,
        name: name ?? this.name,
        category: category ?? this.category,
        unit: unit ?? this.unit,
        stock: stock ?? this.stock,
        minStock: minStock ?? this.minStock,
        unitCost: unitCost ?? this.unitCost,
        status: status ?? this.status,
        supplier: supplier ?? this.supplier,
        updatedAt: updatedAt ?? this.updatedAt,
        isActive: isActive ?? this.isActive,
      );
}

/// `Pick<Supply, 'name' | 'category' | 'unit' | 'minStock' | 'unitCost' | 'supplier' | 'isActive'> & { stock }`.
class SupplyDraft {
  const SupplyDraft({
    required this.name,
    required this.category,
    required this.unit,
    required this.minStock,
    required this.unitCost,
    required this.supplier,
    required this.isActive,
    required this.stock,
  });

  final String name;
  final SupplyCategory category;
  final String unit;
  final double minStock;
  final double unitCost;
  final String supplier;
  final bool isActive;

  /// Solo al crear: stock con el que arranca.
  final double stock;

  factory SupplyDraft.fromJson(JsonMap json) => SupplyDraft(
        name: asString(json['name']),
        category: isSupplyCategory(json['category']) ? json['category'] as String : 'other',
        unit: asString(json['unit'], 'ud'),
        minStock: asDouble(json['minStock']),
        unitCost: asDouble(json['unitCost']),
        supplier: asString(json['supplier']),
        isActive: asBool(json['isActive'], true),
        stock: asDouble(json['stock']),
      );

  /// Borrador a partir de un insumo existente (para editarlo).
  factory SupplyDraft.fromSupply(Supply item) => SupplyDraft(
        name: item.name,
        category: item.category,
        unit: item.unit,
        minStock: item.minStock,
        unitCost: item.unitCost,
        supplier: item.supplier,
        isActive: item.isActive,
        stock: item.stock,
      );

  JsonMap toJson() => {
        'name': name,
        'category': category,
        'unit': unit,
        'minStock': minStock,
        'unitCost': unitCost,
        'supplier': supplier,
        'isActive': isActive,
        'stock': stock,
      };

  SupplyDraft copyWith({
    String? name,
    SupplyCategory? category,
    String? unit,
    double? minStock,
    double? unitCost,
    String? supplier,
    bool? isActive,
    double? stock,
  }) =>
      SupplyDraft(
        name: name ?? this.name,
        category: category ?? this.category,
        unit: unit ?? this.unit,
        minStock: minStock ?? this.minStock,
        unitCost: unitCost ?? this.unitCost,
        supplier: supplier ?? this.supplier,
        isActive: isActive ?? this.isActive,
        stock: stock ?? this.stock,
      );
}

/// Movimiento de stock.
/// - purchase: entrada por compra · usage: salida por consumo · waste: merma · count: conteo físico (fija el stock).
typedef MovementType = String;

/// `MOVEMENT_TYPES` en TS.
const List<MovementType> movementTypes = ['purchase', 'usage', 'waste', 'count'];

const Map<MovementType, String> movementTypeLabel = {
  'purchase': 'Entrada',
  'usage': 'Salida',
  'waste': 'Merma',
  'count': 'Conteo',
};

const Map<MovementType, String> movementTypeHint = {
  'purchase': 'Compra o recepción de mercadería',
  'usage': 'Consumo en cocina o barra',
  'waste': 'Vencido, dañado o descartado',
  'count': 'Inventario físico: fija el stock real',
};

/// `WASTE_REASONS` en TS.
const List<String> wasteReasons = ['Vencido', 'Dañado', 'Error de preparación', 'Devolución', 'Otro'];

class StockMovement {
  const StockMovement({
    required this.id,
    required this.restaurantId,
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.type,
    required this.delta,
    required this.stockAfter,
    this.unitCost,
    required this.reason,
    this.expenseId,
    this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String restaurantId;
  final String itemId;

  /// Nombre y unidad al momento del movimiento (por si el insumo cambia o se elimina).
  final String itemName;
  final String unit;
  final MovementType type;

  /// Variación del stock: positiva entra, negativa sale.
  final double delta;
  final double stockAfter;
  final double? unitCost;
  final String reason;

  /// Gasto creado en Cuentas → Gastos para esta compra.
  final String? expenseId;
  final String? createdBy;
  final String createdAt;

  /// Equivalente a `isMovement` + `toMovement`.
  static StockMovement? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }

    final json = asMap(value);

    if (!_isId(json['id']) || !_isId(json['itemId']) || !movementTypes.contains(json['type']) || json['delta'] is! num) {
      return null;
    }

    return StockMovement.fromJson(json);
  }

  factory StockMovement.fromJson(JsonMap json) => StockMovement(
        id: asId(json['id']),
        restaurantId: asId(json['restaurantId']),
        itemId: asId(json['itemId']),
        itemName: asString(json['itemName']),
        unit: asString(json['unit']),
        type: asString(json['type'], 'usage'),
        delta: asDouble(json['delta']),
        stockAfter: asDouble(json['stockAfter']),
        unitCost: json['unitCost'] is num ? (json['unitCost'] as num).toDouble() : null,
        reason: asString(json['reason']),
        expenseId: asStringOrNull(json['expenseId']),
        createdBy: asStringOrNull(json['createdBy']),
        createdAt: asString(json['createdAt']),
      );

  JsonMap toJson() => {
        'id': id,
        'restaurantId': restaurantId,
        'itemId': itemId,
        'itemName': itemName,
        'unit': unit,
        'type': type,
        'delta': delta,
        'stockAfter': stockAfter,
        'unitCost': unitCost,
        'reason': reason,
        'expenseId': expenseId,
        'createdBy': createdBy,
        'createdAt': createdAt,
      };
}

class MovementDraft {
  const MovementDraft({
    required this.type,
    required this.quantity,
    this.unitCost,
    required this.reason,
    required this.supplier,
    required this.registerExpense,
  });

  final MovementType type;

  /// Cantidad para entrada/salida/merma; stock contado para conteo.
  final double quantity;
  final double? unitCost;
  final String reason;
  final String supplier;

  /// Solo entradas: registrar la compra como gasto de la sede.
  final bool registerExpense;

  factory MovementDraft.fromJson(JsonMap json) => MovementDraft(
        type: asString(json['type'], 'purchase'),
        quantity: asDouble(json['quantity']),
        unitCost: asDoubleOrNull(json['unitCost']),
        reason: asString(json['reason']),
        supplier: asString(json['supplier']),
        registerExpense: asBool(json['registerExpense']),
      );

  JsonMap toJson() => {
        'type': type,
        'quantity': quantity,
        'unitCost': unitCost,
        'reason': reason,
        'supplier': supplier,
        'registerExpense': registerExpense,
      };

  MovementDraft copyWith({
    MovementType? type,
    double? quantity,
    double? Function()? unitCost,
    String? reason,
    String? supplier,
    bool? registerExpense,
  }) =>
      MovementDraft(
        type: type ?? this.type,
        quantity: quantity ?? this.quantity,
        unitCost: unitCost != null ? unitCost() : this.unitCost,
        reason: reason ?? this.reason,
        supplier: supplier ?? this.supplier,
        registerExpense: registerExpense ?? this.registerExpense,
      );
}

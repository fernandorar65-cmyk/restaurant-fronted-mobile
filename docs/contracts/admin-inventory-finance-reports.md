# Contrato de datos: administration, inventory, finance, reports

Errors: TS `new Error(msg)` → `HttpError(msg, 500)` (400 for validation). Nullable fields in copyWith are `T? Function()?` (`copyWith(userId: () => null)`). Classes without "Draft" have `static X? tryParse(Object?)`.

## administration/types.dart
- typedefs `EmployeeArea`, `EmployeeStatus`, `InventoryStatus` (= String); consts `employeeAreas`, `employeeStatuses`, `inventoryStatuses`; `isEmployeeArea/isEmployeeStatus/isInventoryStatus(Object?)`
- `Employee`: id, name, email, phone, roleId, roleName, restaurantId, restaurantName, area, status, hiredAt, `String? userId`
- `EmployeeDraft`: name, email, phone, roleId, restaurantId, area, status, `String? userId`
- `SystemUser`: id, name, email, isActive, isBlocked, `String? roleId`, `List<String> restaurantIds`, `String? employeeId`
- `SystemUserDraft`: `roleId?`, `restaurantIds`, `employeeId?`
- `Role` / `RoleDraft`: (id,) name, description, `List<Permission> permissions`
- `InventoryItem`: id, restaurantId, name, unit, `double stock`, `double minStock`, status, supplier, updatedAt, isActive
- `InventoryItemDraft`: restaurantId, name, unit, stock, minStock, supplier, isActive

## administration/admin_labels.dart
`const Map<String,String>`: `employeeAreaLabel`, `employeeStatusLabel`, `employeeStatusClass`, `inventoryStatusLabel`, `inventoryStatusClass`, `inventoryStatusTone`, `employeeStatusTone` (tone values are StatusBadge tones)

## administration/api.dart
- `InventoryStatus inventoryStatusFor(num stock, num minStock)`
- `fetchEmployees()`, `fetchRoles()`, `fetchInventoryItems()`, `fetchUsers()` → Future<List<…>>
- `updateEmployee(String id, EmployeeDraft draft, {required String roleName, required String restaurantName})`, `createEmployee(EmployeeDraft draft, {required roleName, required restaurantName})` → Future<Employee>
- `syncEmployeeUserLink(String employeeId, String? previousUserId, String? nextUserId)`, `deleteEmployee(Employee employee)`
- `updateInventoryStock(InventoryItem item, double stock)`, `createInventoryItem(InventoryItemDraft)`, `updateInventoryItem(String id, InventoryItemDraft)`
- `createRole(RoleDraft)`, `updateRole(String id, RoleDraft)`, `deleteRole(String id)`
- `updateUserActive(String id, bool)`, `updateUserBlocked(String id, bool)`, `updateUserAccess(SystemUser user, SystemUserDraft draft)` → Future<SystemUser>

## inventory/types.dart (re-exports InventoryStatus)
- typedefs `SupplyCategory`, `MovementType`; consts `supplyCategories`, `supplyCategoryLabel`, `supplyUnits`, `movementTypes`, `movementTypeLabel`, `movementTypeHint`, `wasteReasons`; `isSupplyCategory`
- `Supply`: id, restaurantId, name, category, unit, `double stock, minStock, unitCost`, status, supplier, updatedAt, isActive
- `SupplyDraft` (+ `SupplyDraft.fromSupply(Supply)`): name, category, unit, minStock, unitCost, supplier, isActive, stock
- `StockMovement`: id, restaurantId, itemId, itemName, unit, type, `double delta, stockAfter`, `double? unitCost`, reason, `String? expenseId`, `String? createdBy`, createdAt
- `MovementDraft`: type, `double quantity`, `double? unitCost`, reason, supplier, registerExpense

## inventory/api.dart
- `fetchSupplies(String restaurantId)`, `createSupply(String restaurantId, SupplyDraft)`, `updateSupply(Supply item, SupplyDraft)`
- `fetchMovements(String restaurantId)` → Future<List<StockMovement>>
- `double stockAfter(num stock, MovementType type, num quantity)`
- `registerMovement(Supply item, MovementDraft draft, String? createdBy)` → `Future<({Supply item, StockMovement movement})>`

## finance/types.dart
- `OperatingExpenses` (rent, utilities, maintenance, marketing, other): `static zero`, `static keys`, `operator [](String)`, `operator +`
- `RevenueByMethod` (card, yape, plin, transfer, cash): same helpers
- `DailyFinancial`: id, restaurantId, date, `double revenue`, `int orders, guests`, foodCost, laborCost, operatingCost, profit, expenses, byMethod
- `typedef FinancePeriodKind = String` ('day'|'month'|'year'), const `financePeriods`
- `FinanceTotals`: revenue, costs, foodCost, laborCost, operatingCost, profit; `int orders, guests, days`; expenses, byMethod

## finance/period.dart
- `toDateKey(DateTime)`, `parseDateKey(String)`; `PeriodRange{from,to}`, `TimeBucket{key,label,from,to}`
- `periodRange(kind, anchor)`, `previousAnchor(kind, anchor)`, `shiftAnchor(kind, anchor, int step)`, `timeBuckets(kind, anchor)`
- `emptyTotals()`, `sumTotals(List<DailyFinancial>)`, `periodLabel(kind, anchor)`, `comparisonLabel(kind)`

## finance/api.dart
- `fetchDailyFinancials(String from, String to)` → Future<List<DailyFinancial>>

## finance/finance_period.dart
- const `financePeriodQuery` = {day: dia, month: mes, year: anio}
- `class FinancePeriod extends ChangeNotifier`: `FinancePeriod({String? periodo, String? fecha})`, `today`, `period` (get/set), `anchor` (get/set), `Map<String,String> periodQuery()`

## reports/metrics.dart
- `typedef MetricsPeriod = String`; `RankedItem{label, num value, String? detail}`; `SiteMetrics` (TS number|null → double?, qrShare int?)
- `isInPeriod(String iso, MetricsPeriod, String timeZone, [DateTime? now])`
- `computeSiteMetrics({required attentions, products, history, payments, period, timeZone})`
- `DailyClosingMethodTotal{method, double amount, int count}`, `DailyClosingEmployeeTotal{name, amount, count}`
- `DailyClosingSummary`: dateKey, open, closed, cancelled, `List<Attention> openAttentions`, totalPaid, byMethod, byEmployee, pendingPayments
- `computeDailyClosing({required attentions, payments, dateKey, timeZone})`

## reports/api.dart
- `DailyClosingRecord`: id, restaurantId, dateKey, totalPaid, closedAttentions, cancelledAttentions, openAttentions, byMethod, `String? closedBy`, createdAt
- `fetchDailyClosings(String restaurantId)`, `saveDailyClosing(String restaurantId, DailyClosingSummary, String? closedBy)`

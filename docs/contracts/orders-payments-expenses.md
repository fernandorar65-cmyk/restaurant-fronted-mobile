# Contrato de datos: orders, payments, expenses (+ SiteActivityStore, CheckoutController)

## modules/orders/types.dart
- typedefs `AttentionStatus`, `OrderedProductStatus`, `StatusHistoryEntityType` (= String)
- `Attention { id, restaurantId, tableNumber, status, openedAt, String? closedAt, guestName?, customerId?, cancellationReason? }` (fromJson/toJson/copyWith)
- `OrderedProduct { id, attentionId, restaurantId, productId, name, double unitPrice, int quantity, double subtotal, notes, status, String? rejectionReason, requestedAt, batchId, String? createdBy, String? customerId }`
- `OrderBatchOptions { batchId, String? createdBy, String? customerId }`
- `NewOrderedProductInput { productId, name, double unitPrice, int quantity, notes }`
- `AttentionWithProducts extends Attention { List<OrderedProduct> products }` + `AttentionWithProducts.from(Attention, List<OrderedProduct>)`
- `StatusHistoryEntry { id, entityType, entityId, String? fromStatus, toStatus, String? userName, String? reason, changedAt }`

## modules/orders/order_status_labels.dart
- Maps: `attentionStatusLabel`, `attentionStatusBadgeClass`, `orderedProductStatusLabel`, `orderedProductStatusHint`, `orderedProductBadgeClass`, `orderedProductStepPermission` (Map<String, Permission>), `attentionStatusTone`, `orderedProductStatusTone` (Map<String, StatusTone>)
- `orderedProductStatusSteps`; `nextOrderedProductStatus(s)`, `nextOrderedProductActionLabel(s)` → String?
- `canTransitionOrderedProduct(from, to)`, `canRejectOrderedProduct(s)`, `canCancelOrderedProduct(s)`, `isPendingProduct(s)`, `isBillableProduct(s)` → bool

## modules/orders/rounds.dart
- `OrderRound { batchId, requestedAt, String? createdBy, List<OrderedProduct> products }`; `groupByRound(List<OrderedProduct>)`
- `statusSinceMap(List<StatusHistoryEntry>)` → Map<String,String>; `historyStatusLabel(StatusHistoryEntry)`
- `incomingDelayMinutes=5, kitchenDelayMinutes=15, deliveryDelayMinutes=5`; `typedef DelayLevel`; `delayLevel(num minutes, num threshold)`; maps `delayRingClass`, `delayTextClass`, `delayLabel`

## modules/orders/api.dart
- `ConflictError`, `BusinessRuleError`, `OrdersApiError` (with `message`); `String errorMessage(Object? error, String fallback)`
- `fetchAllAttentions()`, `fetchAttentionsBySite(String)`, `fetchAttentionsByCustomer(String)`, `fetchAttentionById(String)` → Attention?
- `isAttentionActive(Attention)`; `fetchOpenAttentionForTable(restaurantId, tableNumber)`; `assertTableCanOpen(restaurantId, tableNumber)`
- `openOrReuseAttention(restaurantId, tableNumber, {String? customerId, String? userName})`
- `requestAccount(Attention)`, `reopenAttention(Attention, String? userName)`, `closeAttention(Attention, String? userName)`, `cancelAttention(Attention, String? userName, String reason)`
- `fetchAllOrderedProducts()`, `fetchOrderedProductsBySite(String)`, `fetchOrderedProductsByAttention(String)`
- `fetchAttentionsWithProductsBySite(String)` → List<AttentionWithProducts>
- `CartIssue { productId, name, kind, double? currentPrice }`; `OrderItemCheck { productId, name, double unitPrice }`; `validateOrderItems(restaurantId, List<OrderItemCheck>)`
- `addOrderedProducts(Attention, List<NewOrderedProductInput>, OrderBatchOptions)`
- `updateOrderedProductStatus(OrderedProduct, String toStatus, String? userName, [String? reason])`
- `BulkUpdateResult { updated, failed: List<BulkUpdateFailure{product,message}> }`; `updateOrderedProductsStatus(List<OrderedProduct>, toStatus, userName, [reason])`
- `fetchAllStatusHistory()`, `fetchStatusHistory(entityType, entityId)`, `fetchAttentionTimeline(String attentionId, List<String> productIds)`

## modules/payments/types.dart
- typedefs `PaymentMethod`, `PaymentStatus`; `PaymentAllocation { orderedProductId, double amount }`
- `Payment { id, attentionId, List<String> orderedProductIds, allocations, double amount, method, status, payerName?, processedByEmployeeName?, externalReference?, createdAt, requestId? }`
- `CreatePaymentPayload { attentionId, allocations, amount, method, status, payerName?, processedByEmployeeName?, externalReference?, requestId }`

## modules/payments/account.dart
- `ProductBalance { OrderedProduct product, double allocated, double pending }`; `AccountSummary { total, paid, remaining, List<ProductBalance> products }`
- `countsAsPaid(Payment)`; `computeAccount(List<OrderedProduct>, List<Payment>)`

## modules/payments/api.dart
- `paymentMethods`; `fetchAllPayments()`, `fetchPaymentsByAttention(String)`; `createPayment(CreatePaymentPayload)`
- `nextPaymentStatuses(String status)`; `updatePaymentStatus(Payment, String status)`
- maps `paymentMethodLabel`, `paymentStatusLabel`, `paymentStatusBadgeClass`, `paymentStatusTone`

## modules/payments/checkout.dart
- typedefs `FulfillmentMode`, `CheckoutMethod`; `fulfillmentLabel`, `checkoutMethods`, `enabledCheckoutMethods`; `isCheckoutMethod`
- `CheckoutMethodInfo { hint, icon }`; `checkoutMethodInfo`

## modules/payments/checkout_controller.dart
- `typedef GeoPoint = ({double lat, double lng})`; `distanceKm(a, b)`
- `CheckoutController({required DinerStore diner, required CartStore cart, required CheckoutStore checkout})` (ChangeNotifier; starts load() itself; forwards store notifications)
  - fields `site`, `products`, `isLoading`, `bool loadError`; getters `availableModes`, `subtotal`, `deliveryFee`, `total`, `prepMinutes`, `arrivalSlots`, `deliveryDistanceKm`, `fulfillmentError`; `load()`, `reload()`, `dispose()`

## modules/expenses/types.dart
- typedefs `ExpenseKind`, `ExpensePaymentMethod`, `ExpenseIcon`
- `ExpenseCategory { id, name, hint, defaultKind, icon }`, `ExpenseCategoryDraft` (+ `.fromCategory`)
- `Expense { id, restaurantId, category, kind, description, double amount, date, supplier?, paymentMethod, notes, createdBy?, createdAt }`, `ExpenseDraft` (+ `.fromExpense`)
- maps `expenseKindLabel`, `expensePaymentMethodLabel`, `expenseIcons`; `isExpenseIcon`

## modules/expenses/api.dart
- `ExpensesApiError`; `fetchExpenses(restaurantId, from, to)`, `createExpense(restaurantId, ExpenseDraft, String? createdBy)`, `updateExpense(id, ExpenseDraft)`, `deleteExpense(id)`
- `fetchExpenseCategories()`, `createExpenseCategory(String id, ExpenseCategoryDraft)`, `updateExpenseCategory(id, draft)`, `countExpensesByCategory()` → Map<String,int>, `deleteExpenseCategory(id, String? moveTo)`

## stores/site_activity_store.dart
- `SiteActivityCounts { incoming, kitchen, ready, accountRequested }`; `SiteActivityStore(SessionStore, ToastStore)`: `restaurantId`, `counts`, `int revision` (increments on any change — portal views listen to reload), `watchSite(String?)`, `refresh()`, `stop()`

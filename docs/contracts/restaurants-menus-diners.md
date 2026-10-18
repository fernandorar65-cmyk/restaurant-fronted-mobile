# Contrato de datos: restaurants, organizations, menus, diners

Shared rules for every file:
- **Parsing:** each model has `const` named constructors, a lenient `fromJson(JsonMap)` and `toJson()`. The TS normalizers (`toRestaurantSite`, `toLiveTable`, `toSiteOperation`, `toMenuProduct`, `toProfile`) now live inside `fromJson`.
- **Validation:** the strict TS type guards are kept as private `_isX(Object?)` functions in each api.dart.
- **Union types:** all string unions are `typedef X = String`.

## lib/modules/restaurants/types.dart
- `RestaurantSummary{id,name}` (from src/types)
- `Organization{id,name,code}` with `copyWith`
- `RestaurantKpis{revenueLabel,revenueHint,marginLabel,stockLabel,stockHint,stockNote,occupancyLabel,occupancyHint, double occupancyPercent}`
- `SiteFulfillment{bool dineIn,pickup,delivery; double deliveryRadiusKm,deliveryFee,minOrder}` with `copyWith`. Its `fromJson(Object?)` takes any value and returns the default (dineIn only) when there is no config.
- `RestaurantSite{id,code,slug,name,city,address,imageUrl,category,categoryLabel,cuisine,status,statusLabel,badgeLabel,badgeTone,capacityLabel,roleLabel, RestaurantKpis kpis, currency,timezone, double? lat,lng, SiteFulfillment fulfillment}` with `copyWith`
- `SiteFloor{id,name}` with `copyWith`
- `LiveTable{number,floorId,code,status,int seats,int occupiedSeats,floorStatus,int guests,tagLabel,tagTone,location,staff,statusLabel,courseLabel,dish,note,qrToken,bool qrActive}` with `copyWith`
- `SiteStaffMember{id,name,role,area,status}` with `copyWith`
- `KitchenStation{name,chef,progressLabel,double progressPercent,detail}`
- `SiteAlert{title,status,description}`
- `SiteOperation{id,restaurantId,shiftLabel, SiteOperationKpis kpis, List<SiteFloor> floors, List<LiveTable> tables, List<SiteStaffMember> staff, SiteOperationQuality quality, List<KitchenStation> stations, List<SiteAlert> alerts, SiteOperationCellar cellar, SiteOperationBrigade brigade}` with `copyWith`
- `SiteOperationKpis` (all strings except `int occupancyCurrent,occupancyMax`), `SiteOperationQuality{chef,title,description,imageUrl,extra}`, `SiteOperationCellar{sommelier,int champagnes,reds,whites,double pairingPercent}`, `SiteOperationBrigade{int present,total, kitchen,floor,support,headChef}`
- Typedefs: `RestaurantCategory`, `RestaurantOperationalStatus`, `RestaurantBadgeTone`, `TableTagTone`, `TableFloorStatus`, `TableStatus`, `StaffArea`, `StaffShiftStatus`
- Constants: `tableFloorStatuses`, `tableStatuses`, `tableTagTones`, `staffAreas`, `staffShiftStatuses`, `const SiteFloor defaultFloor`

## lib/modules/restaurants/site_labels.dart
- `const Map<String,String>`: `floorStatusLabel`, `staffAreaLabel`, `staffStatusLabel`, `tableStatusLabel`, `restaurantStatusLabel`
- `const List<String>`: `CURRENCY_OPTIONS`, `TIMEZONE_OPTIONS`

## lib/modules/restaurants/api.dart
- `bool isRestaurantOpen(RestaurantSite site)`
- `Future<List<Organization>> fetchOrganizations()`
- `Future<List<RestaurantSite>> fetchRestaurants()`
- `Future<RestaurantSite?> fetchRestaurantBySlug(String slug)`
- `Future<RestaurantSite?> fetchRestaurantById(String id)` (null on 404)
- `class RestaurantDraft{name,city,address,cuisine,status,statusLabel,category,categoryLabel,currency,timezone}`
- `class NewRestaurantDraft extends RestaurantDraft{+code, imageUrl, int? floorsCount}`
- `Future<RestaurantSite> createRestaurant(NewRestaurantDraft draft)` (also POSTs `/siteOperations`)
- `Future<RestaurantSite> updateRestaurant(String id, RestaurantDraft draft, {String? imageUrl})`
- `class OrganizationDraft{name,code}`
- `Future<Organization> updateOrganization(String id, OrganizationDraft draft)`
- `Future<SiteOperation?> fetchSiteOperation(String restaurantId)`
- `Future<SiteOperation> updateSiteOperationFloors(String operationId, List<SiteFloor> floors, List<LiveTable> tables)`
- `Future<SiteOperation> updateSiteOperationTables(String operationId, List<LiveTable> tables)`

## lib/modules/organizations/types.dart
- `typedef OrganizationId = String;`

## lib/modules/menus/types.dart
- `typedef MenuStatus`
- `Menu{id,restaurantId,name,status}` with `copyWith`
- `MenuCategory{id,restaurantId,menuId,name,description,int position}` with `copyWith`
- `MenuProduct{id,restaurantId,categoryId,name,description,double price,imageUrl,bool isActive,isAvailable,int position,List<String> tags,allergens,ingredients,portion,presentation,longDescription,int? prepMinutes}`; `copyWith` has `bool clearPrepMinutes`.
- `MenuCategoryDraft{name,description}`
- `MenuProductDraft{categoryId,name,description,double price,imageUrl,isActive,isAvailable,tags,allergens,ingredients,portion,presentation,longDescription,int? prepMinutes}`

## lib/modules/menus/api.dart
- `fetchMenus(String restaurantId)` → `Future<List<Menu>>`
- `fetchActiveMenu(String restaurantId)` → `Future<Menu?>`
- `createMenu(String restaurantId, String name)` → `Future<Menu>`
- `updateMenuStatus(Menu menu, MenuStatus status)` → `Future<List<Menu>>`
- `fetchMenuCategories(String restaurantId)` / `fetchActiveMenuCategories(String restaurantId)` → `Future<List<MenuCategory>>`
- `fetchMenuProducts(String restaurantId)` → `Future<List<MenuProduct>>`
- `fetchCustomerMenu(String restaurantId)` → `Future<({List<MenuCategory> categories, List<MenuProduct> products})>`
- `reorderMenuCategories(List<MenuCategory>)` / `reorderMenuProducts(List<MenuProduct>)`
- `createMenuCategory(String restaurantId, String menuId, MenuCategoryDraft draft, int position)` → `Future<MenuCategory>`
- `updateMenuCategory(String id, MenuCategoryDraft draft)`, `deleteMenuCategory(String id)`
- `searchMenuSuggestions(String restaurantId, String query, [int limit = 6])` → `Future<List<MenuProduct>>`
- `createMenuProduct(String restaurantId, MenuProductDraft draft, [int position = 0])`
- `patchMenuProduct(String id, JsonMap changes)`, `updateMenuProduct(String id, MenuProductDraft draft)`, `deleteMenuProduct(String id)`
- `imageFileToDataUrl(Uint8List file, [int maxSize = 640])` → `Future<String>` (PNG data URL)

## lib/modules/diners/types.dart
- `CustomerProfile{id,name,email,String? phone,String? birthday,List<String> dietaryPreferences,allergens,bool marketingOptIn,String? createdAt}` with `copyWith`
- `CustomerProfileDraft{name,phone?,birthday?,dietaryPreferences,allergens,marketingOptIn}` + `factory CustomerProfileDraft.fromProfile(CustomerProfile)`
- `const List<String>`: `DIETARY_PREFERENCES`, `ALLERGEN_OPTIONS`

## lib/modules/diners/api.dart (usan `DinerCustomer` de lib/stores/diner_store.dart)
- `Future<DinerCustomer> loginCustomer(String email, String password)`
- `Future<DinerCustomer> registerCustomer(String name, String email, String password)`
- `Future<CustomerProfile> fetchCustomerProfile(String id)`
- `Future<CustomerProfile> updateCustomerProfile(String id, CustomerProfileDraft draft)`
- `Future<void> changeCustomerPassword(String id, String currentPassword, String nextPassword)`

Deviations: TS `throw new Error(msg)` → `HttpError(msg, 500)`; `fetchCustomerMenu` returns a record; `patchMenuProduct` takes a JsonMap; counts are `int`, money/coords `double`.

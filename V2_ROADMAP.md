# DeuxOrders iOS V2 Roadmap

Last reviewed: 2026-04-24

This roadmap is the implementation contract for bringing `theossalmeida/deuxorders-frontend-ios` to parity with the current mobile web app in `C:\Projetos\DeuxOrders web`, backed by `C:\Projetos\DeuxOrders backend`.

The iOS agent should treat the web mobile app as the product reference, not the current iOS UI. The current iOS app already covers login, dashboard, orders, products, clients, cash, and local reminders, but V2 must rebuild the app around the web V2 information architecture, visual identity, data contracts, and missing modules.

Current mobile web parity snapshot reviewed on 2026-04-24 includes:

- Grouped mobile navigation with bottom tabs for `Pedidos`, `Estoque`, and `Caixa`, plus grouped popover destinations.
- Order item editing with one editable unit-value input per item; the value defaults from the product/backend response and can be changed to any non-negative value.
- Product selection grouped by product name, with size chosen separately; the selected size label is displayed, never the UUID, and the price changes with the selected product-size variant.
- Recipe option selection on orders using existing `massa` and `sabor` fields from `order_items`.
- Products list loading `size=100` so the catalog is not capped at the first 20 items.
- Historical orders are valid business data; delivery dates in the past must not block saving or status changes.

## 1. Product Goal

Build a native SwiftUI iOS app that matches the mobile web app's operational experience for Deuxcerie:

- Fast order management for day-to-day production.
- Clear cash, inventory, product, and client management.
- Visual identity aligned with the V2 web app.
- API behavior aligned with the current backend, including auth, UTC dates, integer-cent money, pagination, file uploads, and business rule errors.
- A maintainable iOS architecture with shared networking, typed DTOs, predictable loading/error states, and testable services.

## 2. Source Projects Reviewed

### Web frontend

Path: `C:\Projetos\DeuxOrders web`

Relevant stack:

- Next `16.2.3`, React `19.2.4`, Tailwind `4`, shadcn/base UI, TanStack Query.
- Mobile shell in `src/components/shell/mobile-top-bar.tsx` and `src/components/shell/mobile-bottom-nav.tsx`.
- API boundary in `src/lib/api/*` and `src/types/*`.
- Current modules: Auth, Dashboard, Orders, Products, Product Recipes, Clients, Cash, Inventory, Push/PWA.

### Backend

Path: `C:\Projetos\DeuxOrders backend`

Relevant stack:

- .NET 10, EF Core, PostgreSQL, JWT bearer auth.
- Base URL from backend docs:
  - Production: `https://api-orders.deuxcerie.com.br`
  - Local: `http://localhost:5062`
  - Prefix: `/api/v1`
- Controllers reviewed: Auth, Orders, Products, Clients, Dashboard, Cash, Inventory, Push.

### Current iOS app

Repository: `https://github.com/theossalmeida/deuxorders-frontend-ios`

Current local inspection path: `ios-inspect`

Relevant stack:

- SwiftUI app with service/view-model/view files.
- Main files: `DeuxOrdersApp.swift`, `MainTabView.swift`, `OrderService.swift`, `ProductService.swift`, `ClientService.swift`, `CashService.swift`, `DashboardService.swift`, `NotificationService.swift`.
- Current gaps:
  - No Inventory module.
  - No Product Recipe editor.
  - Several DTO keys do not match the backend/web contract.
  - Multiple duplicated service clients and hard-coded base URLs.
  - Local notification permission is requested on app launch.
  - Dashboard and cash filters still use legacy `startDate`/`endDate` query names.
  - iOS UI uses generic SwiftUI grouped cards instead of the web mobile V2 shell and list system.

## 3. Non-Negotiable Data Rules

The iOS app must follow these across every module:

- Money is always an integer number of cents in app models and API DTOs. Example: `1999` means `R$ 19,99`.
- Never store or send money as `Double` except transient UI text parsing; convert immediately to `Int`.
- Dates sent to the backend are ISO 8601 UTC strings.
- Local date filters must be converted to UTC bounds before request:
  - start: local selected day at `00:00:00` converted to UTC ISO.
  - end: selected end day + 1 at local `00:00:00` converted to UTC ISO when the backend endpoint expects exclusive bounds.
- Enums are strings in most read/list query contracts, except order update status currently uses integer values.
- JSON keys must match backend/web casing exactly.
- All authenticated requests must send `Authorization: Bearer <token>`.
- `401` must delete the keychain token and return the user to login.
- Business rule errors may be plain string bodies, not JSON.
- Order `deliveryDate` may be in the past for historical entry/correction. Do not add client-side validation that blocks past delivery dates, including when changing an older order to `Completed`.
- Order item unit value is editable on new and edit order screens. The default comes from the selected product variant/backend response, but the user may override it; only non-negative values are invalid.

## 4. V2 Visual Identity

The native iOS app should feel like the mobile web V2, adapted to iOS patterns.

### Brand tokens

Use a central `DesignSystem` or equivalent:

```swift
enum DSColor {
    static let brand = Color(red: 88/255, green: 22/255, blue: 41/255)      // #581629
    static let brand2 = Color(red: 122/255, green: 29/255, blue: 56/255)    // #7A1D38
    static let brandSoft = Color(red: 243/255, green: 228/255, blue: 231/255)
    static let brandInk = Color(red: 42/255, green: 12/255, blue: 22/255)
    static let background = Color(red: 250/255, green: 247/255, blue: 242/255)
    static let background2 = Color(red: 241/255, green: 236/255, blue: 227/255)
    static let foreground = Color(red: 26/255, green: 21/255, blue: 18/255)
    static let foregroundSoft = Color(red: 93/255, green: 84/255, blue: 74/255)
    static let ok = Color(red: 63/255, green: 122/255, blue: 90/255)
    static let warn = Color(red: 184/255, green: 121/255, blue: 31/255)
    static let destructive = Color(red: 176/255, green: 66/255, blue: 66/255)
}
```

Chart colors:

- `#581629`
- `#A07A3A`
- `#3F7A5A`
- `#B85C3A`
- `#6B5842`

### Typography

- Use SF Pro for native UI.
- Use monospaced digits for IDs, money, quantities, and dates where the web uses `font-mono`.
- Use tight, utilitarian labels:
  - Section labels: uppercase, small, semibold, muted.
  - Primary amounts: large, semibold, monospaced.
  - Cards/lists: compact and scan-friendly.

### Layout Language

Replicate the mobile web layout patterns:

- Top bar:
  - Sticky-style page title area with optional eyebrow and right action.
  - Titles: `Pedidos`, `Materiais`, `Caixa`, etc.
- Main navigation:
  - iOS `TabView` should mirror the web mobile group tabs from `src/components/shell/nav-items.ts`:
    - `Pedidos` opens the `Vendas` group.
    - `Estoque` opens the `Estoque` group.
    - `Caixa` opens the `Financeiro` group.
  - The web bottom nav highlights an active group when any child route is active.
  - Groups with more than one destination open a small grouped popover above the bottom bar:
    - `Vendas`: `Painel`, `Pedidos`, `Produtos`, `Clientes`.
    - `Estoque`: `Estoque`.
    - `Financeiro`: `Caixa`, `Lancamentos`.
  - Add secondary destinations through in-section menus or a "More" tab if native UX requires it:
    - Dashboard, Products, Clients, Cash Entries.
  - Do not keep the current five equal tabs as the final V2 navigation without evaluating discoverability against the web grouping.
- Cards:
  - Use 12-16 pt radius. Web uses `rounded-xl`/`rounded-2xl`; native can use 12/16.
  - Use subtle borders and grouped surfaces, not heavy shadows.
- Lists:
  - Group orders and cash entries by day.
  - Use bordered grouped blocks with row dividers.
  - Keep row heights compact.
- Buttons:
  - Primary brand fill.
  - Secondary outline/neutral.
  - Destructive red.
  - Icon-only buttons for common actions where labels are obvious.

### Status Style

Order status labels:

| Status | Label | Visual intent |
|---|---|---|
| `Received` | `Recebido` | blue chip |
| `Pending` | `Pendente` | amber chip |
| `Preparing` | `Preparando` | orange chip |
| `WaitingPickupOrDelivery` | `Aguardando Retirada/Entrega` | violet chip |
| `Completed` | `Concluido` | green chip |
| `Canceled` | `Cancelado` | red chip |

Cash:

- Inflow: green, positive amount.
- Outflow: red or foreground amount with minus sign, depending on context.
- Net daily totals use green for positive and destructive for negative.

## 5. iOS Architecture Target

Replace the current duplicated service pattern with a shared API layer.

### Suggested modules

```text
DeuxOrders/
  App/
    DeuxOrdersApp.swift
    AppSession.swift
    AppEnvironment.swift
  DesignSystem/
    Colors.swift
    Typography.swift
    Components/
  Networking/
    APIClient.swift
    APIError.swift
    APIEndpoint.swift
    DateCoding.swift
    MultipartFormData.swift
  Auth/
  Dashboard/
  Orders/
  Products/
  Inventory/
  Clients/
  Cash/
  Notifications/
```

### APIClient requirements

- Single configurable base URL. Do not hard-code `https://deux-erp.deuxcerie.com.br/api/v1/` in every service.
- Production default should be `https://api-orders.deuxcerie.com.br/api/v1` unless the deployed backend is confirmed otherwise.
- Support:
  - `GET`
  - JSON `POST`, `PUT`, `PATCH`, `DELETE`
  - `multipart/form-data`
  - raw `PUT` to presigned upload URL without bearer token
  - file download responses for dashboard export
- Shared `JSONDecoder`:
  - Handles ISO8601 with fractional seconds and without fractional seconds.
  - Fails visibly in debug; do not silently return `Date()` on parse failure.
- Shared `JSONEncoder`:
  - ISO8601 UTC date strings when encoding `Date`, or explicit string fields where the view model formats dates.
- `APIError` should include:
  - `unauthorized`
  - `validation(String)`
  - `server(status: Int, message: String?)`
  - `decoding(Error)`
  - `network(URLError)`

### Auth/session

- Store JWT in Keychain.
- Decode JWT claims locally to determine role where needed.
- Administrator-only actions:
  - `PATCH /orders/{id}/pay`
  - `PATCH /orders/{id}/unpay`
  - `DELETE /orders/{id}`
  - `DELETE /products/{id}`
- Hide or disable admin-only UI for non-admin users.

## 6. Current iOS Contract Fixes

These should be fixed before adding new features.

### Base URL

Current iOS uses:

- `https://deux-erp.deuxcerie.com.br/api/v1/...`

Backend docs say production is:

- `https://api-orders.deuxcerie.com.br/api/v1/...`

Confirm the active production API host, then set it once in `AppEnvironment`.

### Order input keys

Current iOS `OrderInput.swift` uses lowercase keys:

```swift
clientid
deliverydate
productid
unitprice
```

V2 must use backend/web keys:

```json
{
  "clientId": "guid",
  "deliveryDate": "2026-04-25T14:30:00Z",
  "items": [
    {
      "productId": "guid",
      "quantity": 2,
      "unitPrice": 1500,
      "observation": "string",
      "massa": "string",
      "sabor": "string"
    }
  ],
  "references": ["order-references/abc.jpg"]
}
```

### Product keys

Current iOS maps:

- `description = "descricao"`
- `size = "tamanho"`
- multipart field `descricao`

Backend/web use:

- response key `description`
- response key `size`
- multipart field `Description`
- multipart field `Size`

Use canonical fields:

```text
Name
Price
Description
Category
Size
Image
```

The web `FormData` appends fields from TypeScript component names; backend model binding is case-insensitive, but iOS should still use backend model names.

### Client status

Current iOS model uses `isActive`; backend/web use `status`.

Use:

```swift
let status: Bool
```

### Dashboard filters

Prefer current web contract:

- `createdAtFrom`
- `createdAtTo`
- `status`

Legacy `startDate`/`endDate` are accepted by backend but should not be the V2 default.

### Cash filters

Use:

- `from`
- `to`
- `type`
- `category`
- `source`
- `includeDeleted`
- `page`
- `size`

### Notifications

Current iOS asks notification permission on app launch. V2 must not do this.

V2 notification settings should be user-controlled from an authenticated settings/notifications screen or prompt card.

## 7. Backend Contract Gaps To Resolve

These are the known backend/web mismatches reviewed on 2026-04-24. iOS must not invent private contracts for these; either implement tolerant decoding where noted or wait for one canonical backend/web contract.

### Delivery field

There is a mismatch between the web frontend and backend source for delivery.

Web expects order DTOs to include:

```ts
delivery: string | null
```

Web sends create/update:

```json
{ "delivery": "pickup" }
```

or:

```json
{ "delivery": "Rua X, 123" }
```

Backend source reviewed on 2026-04-24 has:

- Domain field: `Order.DeliveryAddress`
- `CreateOrderRequest` does not include delivery/deliveryAddress.
- `UpdateOrderRequest` does not include delivery/deliveryAddress.
- `OrderResponse` does not include delivery/deliveryAddress.

Before iOS implements delivery parity, backend must expose one canonical API field. Recommended canonical field because the web already uses it:

```json
"delivery": "pickup"
```

Rules:

- `null` or `"pickup"` means `Retirada`.
- Any other non-empty string means `Entrega` address.
- Create and update should accept `delivery`.
- Response should return `delivery`.

If the backend team chooses `deliveryAddress` instead, the web app must be aligned too. Do not let iOS invent a third contract.

### Product metadata fields

The mobile web model expects products to include:

```json
{
  "description": "string or null",
  "hasRecipe": true
}
```

Backend source reviewed on 2026-04-24 still has `ProductResponse` returning only:

```text
id, name, price, status, image, category, size
```

Recommended resolution:

- Backend should include `description` and `hasRecipe` on product list/detail responses.
- Until resolved, iOS should decode both fields as optional and default `hasRecipe` to `false` only as a compatibility fallback.
- The product detail screen should not crash if `description` is missing.

### Historical delivery dates

The backend validator has been adjusted so updating older orders is allowed. iOS must keep the same rule:

- Past `deliveryDate` values are allowed on create and update.
- Changing an older order to `Completed` must be allowed.
- Validation should only require a valid date value, not a future date.

## 8. API Contracts For iOS

All paths below are relative to `/api/v1`.

### Auth

#### `POST /auth/login`

Request:

```json
{ "email": "user@example.com", "password": "secret" }
```

Response:

```json
{ "token": "<jwt>" }
```

Behavior:

- On `200`, store token in Keychain.
- On `401`, show `Email ou senha incorretos.`
- On `429`, show rate-limit message if body/header includes one.

### Dashboard

#### `GET /dashboard/summary`

Query:

```text
createdAtFrom=UTC_ISO
createdAtTo=UTC_ISO
status=Received
```

Response:

```json
{
  "totalRevenue": 150000,
  "totalValue": 160000,
  "totalDiscount": 10000,
  "totalOrders": 12,
  "pendingOrders": 3,
  "completedOrders": 8,
  "canceledOrders": 1,
  "averageRevenuePerOrder": 12500
}
```

#### `GET /dashboard/revenue-over-time`

Response:

```json
{
  "dataPoints": [
    { "date": "2026-04-24", "revenue": 45000, "orderCount": 3 }
  ]
}
```

#### `GET /dashboard/top-products?limit=10`

Response:

```json
[
  {
    "productId": "guid",
    "productName": "Bolo",
    "totalRevenue": 90000,
    "totalQuantitySold": 6,
    "orderCount": 4
  }
]
```

#### `GET /dashboard/top-clients?limit=10`

Response:

```json
[
  {
    "clientId": "guid",
    "clientName": "Maria",
    "totalRevenue": 75000,
    "orderCount": 5
  }
]
```

#### `GET /dashboard/export`

Query:

```text
from=YYYY-MM-DD
to=YYYY-MM-DD
status=Received
format=csv|pdf
```

Response: file bytes.

### Orders

#### Order status enum

```swift
enum OrderStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case completed = "Completed"
    case canceled = "Canceled"
    case received = "Received"
    case preparing = "Preparing"
    case waitingPickupOrDelivery = "WaitingPickupOrDelivery"
}
```

Integer mapping for update status:

```text
Pending = 1
Completed = 2
Canceled = 3
Received = 4
Preparing = 5
WaitingPickupOrDelivery = 6
```

#### `GET /orders/all`

Query:

```text
page=1
size=20
status=Received
from=YYYY-MM-DD or ISO accepted by backend
to=YYYY-MM-DD or ISO accepted by backend
search=client/id text
```

Current web default:

- from = today local date
- to = today + 6 days local date

Response:

```json
{
  "items": [
    {
      "id": "guid",
      "deliveryDate": "2026-04-25T14:30:00Z",
      "status": "Received",
      "clientId": "guid",
      "clientName": "Maria",
      "totalPaid": 3000,
      "totalValue": 3000,
      "references": ["https://signed-read-url"],
      "items": [
        {
          "productId": "guid",
          "productName": "Bolo",
          "productSize": "P",
          "observation": "sem acucar",
          "massa": "tradicional",
          "sabor": "chocolate",
          "quantity": 2,
          "paidUnitPrice": 1500,
          "baseUnitPrice": 1500,
          "itemCanceled": false,
          "totalPaid": 3000,
          "totalValue": 3000
        }
      ],
      "delivery": "pickup",
      "paidAt": "2026-04-24T10:00:00Z",
      "paidByUserName": "Theo"
    }
  ],
  "totalCount": 42,
  "pageNumber": 1,
  "pageSize": 20
}
```

Note: `delivery` requires backend alignment as described above.

Order date and value rules:

- `deliveryDate` may be historical; do not block past dates in the app.
- Create uses `unitPrice`; update uses `paidUnitPrice`.
- Both price fields are integer cents and may be changed by the user.
- Only negative prices are invalid. Zero is allowed if the business intentionally enters it.

#### `GET /orders/{id}`

Response: same order object.

#### `POST /orders/new`

Request:

```json
{
  "clientId": "guid",
  "deliveryDate": "2026-04-25T14:30:00Z",
  "items": [
    {
      "productId": "guid",
      "quantity": 2,
      "unitPrice": 1500,
      "observation": "sem acucar",
      "massa": "tradicional",
      "sabor": "chocolate"
    }
  ],
  "references": ["order-references/abc.jpg"],
  "delivery": "pickup"
}
```

Response: created order.

#### `PUT /orders/{id}`

Request:

```json
{
  "deliveryDate": "2026-04-25T14:30:00Z",
  "status": 5,
  "items": [
    {
      "productId": "guid",
      "quantity": 3,
      "paidUnitPrice": 1400,
      "observation": "string",
      "massa": "string",
      "sabor": "string"
    }
  ],
  "references": ["order-references/new.jpg"],
  "delivery": "Rua X, 123"
}
```

Response may be either:

```json
{ "...order fields": "..." }
```

or:

```json
{
  "response": { "...order fields": "..." },
  "warnings": ["Estoque insuficiente para X"]
}
```

iOS must support both.

#### Status/action endpoints

```text
PATCH /orders/{id}/complete
PATCH /orders/{id}/cancel
PATCH /orders/{id}/items/{productId}/cancel
PATCH /orders/{id}/items/{productId}/quantity
PATCH /orders/{id}/pay                 Administrator
PATCH /orders/{id}/unpay               Administrator
DELETE /orders/{id}                    Administrator
```

Quantity body:

```json
{ "increment": 1 }
```

Unpay body:

```json
{ "reason": "Motivo com pelo menos 5 caracteres" }
```

#### Reference upload

1. Request upload URL:

```text
POST /orders/references/presigned-url
```

Request:

```json
{
  "fileName": "photo.jpg",
  "contentType": "image/jpeg",
  "orderId": "guid optional"
}
```

Response:

```json
{
  "uploadUrl": "https://r2-presigned-url",
  "objectKey": "order-references/{guid}.jpg"
}
```

2. Upload bytes:

```text
PUT uploadUrl
Content-Type: image/jpeg
```

3. Include `objectKey` in create/update `references`.

4. Delete a reference:

```text
DELETE /orders/{id}/references
```

Body:

```json
{ "objectKey": "order-references/abc.jpg" }
```

### Products

#### Product response

```json
{
  "id": "guid",
  "name": "Bolo de Mel",
  "price": 2500,
  "status": true,
  "image": "https://cdn/products-images/abc.jpg",
  "description": "string",
  "category": "Bolos",
  "size": "M",
  "hasRecipe": true
}
```

`hasRecipe` is expected by the web app; if missing from backend response, backend should expose it consistently.

#### `GET /products/all`

Query:

```text
search=bolo
status=true
page=1
size=100
```

Backend returns paginated shape:

```json
{
  "items": [ProductResponse],
  "totalCount": 42,
  "pageNumber": 1,
  "pageSize": 100
}
```

Web also tolerates raw arrays. iOS should decode the paginated shape and optionally be tolerant during migration.

#### `GET /products/dropdown?status=true`

Response:

```json
[
  {
    "id": "guid",
    "name": "Bolo",
    "price": 2500,
    "category": "Bolos",
    "size": "M"
  }
]
```

Mobile product picker behavior:

- Group variants by normalized product name so duplicate database rows such as `Naked Cake` appear once in the picker.
- Show size choices inside that product row.
- The size dropdown/select value is the product UUID internally, but the visible label must be the chosen size (`P`, `M`, `G`, etc.) or `Padrao` when empty; never display the UUID.
- The displayed price and the product added to the order must change when the selected size changes.
- Search must match product name and size.
- Adding the same selected product variant again increments quantity; selecting a different size creates/updates the distinct variant item.

#### `POST /products/new` multipart

Fields:

```text
Name: string required
Price: int cents required
Description: string optional
Category: string optional
Size: string optional
Image: file optional, jpeg/png/webp, max 5 MB
```

Response: product.

#### `PUT /products/{id}` multipart

Same fields as create.

#### Product action endpoints

```text
PATCH /products/{id}/active
PATCH /products/{id}/inactive
DELETE /products/{id}/image
DELETE /products/{id}        Administrator
```

#### `GET /products/{id}/stats`

Query:

```text
month=2026-04
```

Response:

```json
{
  "soldThisMonth": 12,
  "revenueThisMonth": 90000
}
```

`month` is required in `YYYY-MM` format. `revenueThisMonth` is integer cents.

### Product recipes

This is missing in current iOS and required for V2.

#### `GET /products/{id}/recipe`

Response:

```json
{
  "hasRecipe": true,
  "items": [
    {
      "materialId": "guid",
      "materialName": "Farinha",
      "quantity": 250,
      "measureUnit": "G"
    }
  ]
}
```

Backend may serialize `measureUnit` as string or numeric in some paths. iOS should tolerate both:

```text
1 = ML
2 = G
3 = U
```

#### `PUT /products/{id}/recipe`

Request:

```json
{
  "items": [
    { "materialId": "guid", "quantity": 250 }
  ]
}
```

Send an empty `items` array to clear the recipe.

### Product recipe options

Recipe options define per-product variations: dough type (massa), filling (recheio), or flavor (sabor). Each option has its own ingredient recipe for inventory deduction.

#### Recipe option type enum

```swift
enum ProductRecipeOptionType: String, Codable {
    case dough = "Dough"
    case filling = "Filling"
    case flavor = "Flavor"
}
```

Integer mapping:

```text
Dough = 1
Filling = 2
Flavor = 3
```

#### `GET /products/{id}/recipe-options`

Response:

```json
{
  "options": [
    {
      "id": "guid",
      "type": "Dough",
      "name": "Chocolate",
      "hasRecipe": true,
      "items": [
        {
          "materialId": "guid",
          "materialName": "Cacau em pó",
          "quantity": 50,
          "measureUnit": "G"
        }
      ]
    }
  ]
}
```

`type` is serialized as string. `measureUnit` may be string or numeric (same tolerance as base recipes). Options are sorted by type then name.

#### `PUT /products/{id}/recipe-options`

Upserts a single recipe option by product + type + name combination. Send empty `items` to delete the option.

Request:

```json
{
  "type": "Dough",
  "name": "Chocolate",
  "items": [
    { "materialId": "guid", "quantity": 50 }
  ]
}
```

Response: single `ProductRecipeOptionResponse` (same shape as one element in the GET response).

Business rules:

- All referenced materials must exist and be active.
- Name is trimmed before matching.
- Sending `items: []` deletes the option if it exists and returns `hasRecipe: false`.

#### `GET /products/{id}/order-options`

Returns the preset catalog of available recipe option names. These are global constants, not per-product — the endpoint exists for convenience.

Response:

```json
{
  "cakeDoughs": ["Baunilha", "Red Velvet", "Chocolate", "Limão", "Caramelo"],
  "cakeFillings": ["brulee", "branco", "doce de leite", "limao", "beijinho", "chocolate", "cream cheese frosting"],
  "brigadeiroFlavors": ["chocolate", "brulee", "beijinho", "limão", "churros", "casadinho"],
  "cookieFlavors": ["churros", "cacau", "tradicional", "brookie", "caramelo salgado"]
}
```

iOS should use these catalogs to populate the massa/sabor pickers in the order creation flow, matching the web behavior in `src/lib/recipe-options.ts`.

### Inventory

This module is missing in current iOS and required for V2.

#### Measure unit enum

```swift
enum MeasureUnit: String, Codable, CaseIterable {
    case ml = "ML"
    case g = "G"
    case u = "U"
}
```

Backend may accept numeric enum values in JSON. Web sends:

```text
ML = 1
G = 2
U = 3
```

For create/update, send numeric values if matching current web behavior; support string decoding on responses.

#### `GET /inventory/all`

Query:

```text
search=farinha
status=true
page=1
size=100
```

Response:

```json
{
  "items": [
    {
      "id": "guid",
      "name": "Farinha",
      "quantity": 1000,
      "unitCost": 8,
      "measureUnit": "G",
      "status": true,
      "createdAt": "2026-04-24T10:00:00Z",
      "updatedAt": "2026-04-24T10:00:00Z"
    }
  ],
  "totalCount": 1,
  "pageNumber": 1,
  "pageSize": 100
}
```

`unitCost` is cents per unit.

#### `POST /inventory/new`

Request:

```json
{
  "name": "Farinha",
  "quantity": 1000,
  "totalCost": 800,
  "measureUnit": 2
}
```

Backend calculates unit cost from total cost and quantity.

#### `PUT /inventory/{id}`

Request:

```json
{
  "name": "Farinha premium",
  "measureUnit": 2
}
```

#### `POST /inventory/{id}/restock`

Request:

```json
{
  "quantity": 500,
  "totalCost": 450
}
```

#### Inventory action endpoints

```text
PATCH /inventory/{id}/active
PATCH /inventory/{id}/inactive
GET /inventory/dropdown?status=true
```

Dropdown response:

```json
[
  { "id": "guid", "name": "Farinha", "measureUnit": "G" }
]
```

### Clients

#### Client list response

```json
{
  "items": [
    {
      "id": "guid",
      "name": "Maria Silva",
      "mobile": "21999999999",
      "status": true,
      "totalOrders": 4,
      "totalSpent": 12000
    }
  ],
  "totalCount": 1,
  "pageNumber": 1,
  "pageSize": 100
}
```

The web currently unwraps `items`, but backend returns paginated shape.

#### `GET /clients/all`

Query:

```text
search=maria
status=true
page=1
size=100
```

#### `GET /clients/dropdown?status=true`

Response:

```json
[
  { "id": "guid", "name": "Maria" }
]
```

#### `GET /clients/{id}?orders=true`

Response:

```json
{
  "id": "guid",
  "name": "Maria",
  "mobile": "21999999999",
  "status": true,
  "stats": {
    "totalOrders": 4,
    "totalSpent": 12000,
    "lastOrderDate": "2026-04-20T10:00:00Z"
  },
  "orders": {
    "items": [
      {
        "id": "guid",
        "deliveryDate": "2026-04-25T14:30:00Z",
        "status": "Received",
        "totalPaid": 3000,
        "totalValue": 3000
      }
    ]
  }
}
```

iOS domain model may expose `totalSpentCents`, but DTO must decode `totalSpent`.

#### Client write/action endpoints

```text
POST /clients/new
PUT /clients/{id}
PATCH /clients/{id}/active
PATCH /clients/{id}/inactive
DELETE /clients/{id}
```

Create:

```json
{ "name": "Maria Silva", "mobile": "21999999999" }
```

Update:

```json
{ "name": "Maria S.", "mobile": "21999990000", "status": true }
```

### Cash

#### Enums

```swift
enum CashFlowType: String, Codable {
    case inflow = "Inflow"
    case outflow = "Outflow"
}

enum CashFlowSource: String, Codable {
    case manual = "Manual"
    case orderPayment = "OrderPayment"
    case orderReversal = "OrderReversal"
}

enum CashFlowCategory: String, Codable {
    case order = "Order"
    case orderReversal = "OrderReversal"
    case rawMaterial = "RawMaterial"
    case supplier = "Supplier"
    case salary = "Salary"
    case tax = "Tax"
    case utilities = "Utilities"
    case equipment = "Equipment"
    case marketing = "Marketing"
    case other = "Other"
}
```

#### `GET /cash/entries`

Query:

```text
from=UTC_ISO
to=UTC_ISO
type=Inflow
category=RawMaterial
source=Manual
includeDeleted=false
page=1
size=50
```

Response:

```json
{
  "items": [
    {
      "id": "guid",
      "createdAt": "2026-04-24T10:00:00Z",
      "billingDate": "2026-04-24T00:00:00Z",
      "type": "Outflow",
      "category": "RawMaterial",
      "counterparty": "Fornecedor",
      "amountCents": 5000,
      "notes": "string",
      "source": "Manual",
      "sourceId": null,
      "authorUserId": "guid",
      "authorUserName": "Theo",
      "updatedAt": null,
      "deletedAt": null
    }
  ],
  "totalCount": 1,
  "pageNumber": 1,
  "pageSize": 50
}
```

#### `GET /cash/summary`

Response:

```json
{
  "totalInflowCents": 100000,
  "totalOutflowCents": 25000,
  "netBalanceCents": 75000,
  "totalCount": 12,
  "inflowByCategory": { "Order": 100000 },
  "outflowByCategory": { "RawMaterial": 25000 }
}
```

#### Cash write/action endpoints

```text
GET /cash/entries/{id}
POST /cash/entries
PUT /cash/entries/{id}
DELETE /cash/entries/{id}
GET /cash/audit/{entryId}
```

Create/update:

```json
{
  "billingDate": "2026-04-24T00:00:00Z",
  "type": "Outflow",
  "category": "RawMaterial",
  "counterparty": "Fornecedor",
  "amountCents": 5000,
  "notes": "string"
}
```

Delete:

```json
{ "reason": "Motivo com pelo menos 5 caracteres" }
```

### Push/notifications

Backend supports web push subscription endpoints:

```text
POST /push/status
POST /push/subscribe
DELETE /push/unsubscribe
```

These are web-push browser subscription endpoints, not native APNs endpoints.

For native iOS V2, choose one:

1. Keep native local reminders only, but move permission request to a user action.
2. Add real native push through APNs with backend changes.

Do not try to use browser Web Push subscription payloads from native Swift; APNs requires a different device token flow.

Recommended V2 scope:

- Phase 1: user-controlled local notification reminders for due today/due tomorrow.
- Phase 2: backend APNs support if production needs native remote notifications for new orders/cash.

## 9. Screen-by-Screen V2 Requirements

### Mobile web parity checkpoints

Use these as final acceptance checks before calling iOS V2 equivalent to the mobile web app:

- Shell uses the same three primary mobile groups: `Pedidos`, `Estoque`, `Caixa`.
- Secondary destinations remain discoverable from their group: `Painel`, `Produtos`, `Clientes`, and `Lancamentos`.
- Mobile pages use compact grouped cards, warm off-white background, sticky top context, and bottom safe-area padding.
- New/edit order screens keep the same section order: `Cliente`/`Status`, `Itens`, `Entrega`, `Referencias`, `Resumo`.
- Product picker is a full-screen mobile overlay with search, grouped product names, size selector, visible size labels, and variant-specific prices.
- Order item rows show product name, size, one editable `Valor un.` input, quantity controls, expand/collapse details, and remove action.
- Cake items require `massa` plus one or two `sabor` fillings; brigadeiro/cookie items require one `sabor`; other products do not show recipe option controls.
- Mobile order summary and sticky footer recalculate totals from editable unit values.
- Product catalog loads all active products using `size=100` and displays dense two-column cards on iPhone.
- Historical orders can be created/edited and moved to `Completed` without future-date validation.

### Login

Reference: web `src/app/(auth)/login/page.tsx`.

Native requirements:

- Brand-first login using Deuxcerie V2 colors.
- Email and password fields.
- Client-side validation:
  - email required and valid.
  - password required.
- Submit to `POST /auth/login`.
- Store token in keychain.
- Move to authenticated shell on success.
- Handle `401`, `429`, `503`, malformed responses.
- Do not request notification permission from login/app launch.

### Authenticated shell

Reference: web `src/app/(app)/layout.tsx`, mobile top/bottom nav.

Native requirements:

- Token gate on launch.
- Shared session expiration handling.
- Main group tabs:
  - `Pedidos`
  - `Estoque`
  - `Caixa`
- Secondary destinations:
  - Dashboard
  - Products
  - Clients
  - Cash Entries
  - Settings/Notifications
- Keep background warm off-white.
- Avoid deeply nested tab stacks that lose context.

### Dashboard

Reference: web dashboard components:

- `dashboard-kpis.tsx`
- `revenue-section.tsx`
- `pipeline-section.tsx`
- `top-products-section.tsx`
- `top-clients-section.tsx`
- `page-filters.tsx`

Native requirements:

- Preset picker: Today, Week, Month, Custom.
- KPI band:
  - revenue
  - total value
  - discount
  - orders
  - pending/completed/canceled
  - average revenue per order
- Revenue chart.
- Pipeline/status section.
- Top products ranked list.
- Top clients ranked list.
- Export CSV/PDF through share sheet.
- Use UTC `createdAtFrom`/`createdAtTo`.

### Orders list

Reference:

- `src/app/(app)/orders/page.tsx`
- `orders-toolbar.tsx`
- `orders-mobile-list.tsx`
- `order-card.tsx`

Native requirements:

- Default date range: today through today + 6 days.
- Search by client or order ID.
- Status filter.
- Group orders by local delivery day.
- Group header:
  - relative day (`Hoje`, `Amanha`, `Ontem`) where applicable.
  - short date.
  - count.
- Row:
  - client name.
  - monospaced full or shortened order ID.
  - delivery time.
  - total paid.
  - status chip.
  - delivery mode: retirada/entrega.
  - item count.
- Pull to refresh.
- Empty states:
  - no results with filters: offer clear filters.
  - no orders: prompt create.
- Primary action: new order.

### New order

Reference: web `src/app/(app)/orders/new/page.tsx`.

Native requirements:

- Wizard or stepped form with these sections:
  - Cliente
  - Itens
  - Entrega
  - Referencias
  - Resumo
- Client picker:
  - fetch active clients from `/clients/dropdown?status=true`.
  - searchable.
- Product picker:
  - fetch active products from `/products/dropdown?status=true`.
  - searchable.
  - group rows by product name and expose size as a secondary selector in the row.
  - display product name, category, selected size, and selected size price.
  - display the size label, not the product UUID.
  - changing size must immediately change the shown price and the product variant used when the item is added.
- Item editor:
  - quantity stepper.
  - exactly one editable unit-value input per item on mobile, labelled like the web `Valor un.` field.
  - the unit-value input defaults from the selected product variant price and can be overridden before saving.
  - do not add a second read-only value field beside the input on mobile; it causes overflow and diverges from the web.
  - optional observation.
  - recipe option pickers (massa/sabor) — shown conditionally based on product category/name:
    - **Cake** (`category` contains "bolo"/"bolos" or `name` contains "bolo"/"cake"): show massa picker (from `cakeDoughs`) and sabor/recheio picker (from `cakeFillings`, multi-select, pipe-delimited: `"brulee|chocolate"`).
    - **Brigadeiro** (`category`/`name` contains "brigadeiro"): show sabor picker (from `brigadeiroFlavors`, single-select).
    - **Cookie** (`category`/`name` contains "cookie"): show sabor picker (from `cookieFlavors`, single-select).
    - Other products: no massa/sabor pickers.
  - Validation: cakes require massa and at least one recheio; brigadeiro/cookie require sabor. Show inline error if missing before submit.
  - Fetch available options from `GET /products/{productId}/order-options` or use a local copy of the preset catalog.
- Delivery:
  - mode `Retirada` sends `delivery: "pickup"`.
  - mode `Entrega` sends address string.
  - delivery date/time defaults to tomorrow.
- References:
  - allow up to 3 images.
  - compress/resize before upload where appropriate.
  - request presigned URL, upload bytes, store objectKey.
- Summary:
  - subtotal/total in cents.
  - totals must recalculate from the current editable unit values times quantity.
  - sticky bottom create action.
- Create order after all uploads succeed.

### Order detail

Reference: web `src/app/(app)/orders/[id]/page.tsx`.

Native requirements:

- Header with back, order/client identity, edit/cancel actions.
- Total card with status chip and status pipeline.
- Items list/table:
  - product name.
  - size.
  - quantity.
  - paid/base unit price.
  - observation/massa/sabor.
  - canceled item styling.
- Delivery card:
  - mode icon.
  - date and time.
  - address if delivery.
- Payment card:
  - paid/pending state.
  - paid date and user.
  - admin mark paid/unpay actions.
- References gallery.
- Client summary card.
- Advance status:
  - `Received` -> update status `Preparing`.
  - `Preparing` -> update status `WaitingPickupOrDelivery`.
  - `WaitingPickupOrDelivery` -> complete.
  - no advance for completed/canceled/pending unless product decision changes.

### Edit order

Reference: web `src/app/(app)/orders/[id]/edit/page.tsx`.

Native requirements:

- Edit date/time.
  - Past dates must remain valid for historical order entry/correction.
- Edit delivery mode/address.
- Add/update items while respecting backend rules.
  - Preserve the same mobile item editor as new order: one editable unit-value input, quantity stepper, observation, and conditional massa/sabor controls.
  - Send overridden item value as `paidUnitPrice` in integer cents.
- Add references through presigned upload.
- Remove existing references.
- Decode update response with optional warnings.
- Show inventory warnings after save if backend returns them.

### Products

Reference:

- `products/page.tsx`
- `products-grid.tsx`
- `product-card.tsx`
- `ProductForm.tsx`
- product detail components.

Native requirements:

- Fetch `/products/all` with `size=100` by default so the mobile catalog matches the web and does not stop at the backend default page size.
- Grid or dense two-column cards on iPhone where practical.
- Search.
- Status filter active/inactive.
- Category filter.
- Product card:
  - image square or patterned fallback.
  - category label.
  - name.
  - price.
  - recipe icon if `hasRecipe`.
  - active toggle.
- Product detail:
  - image gallery/main image.
  - name, category, size, description, price, status.
  - recipe card.
  - edit and image delete actions.
- Create/edit:
  - multipart form.
  - image picker.
  - fields: name, description, price, category, size, image.
  - convert UI price to cents.

### Product recipe editor

Reference:

- `product-recipe-card.tsx`
- `recipe-editor-sheet.tsx`

Native requirements:

- **Base recipe** (the product's default ingredient list):
  - Fetch recipe via `GET /products/{id}/recipe`.
  - If none, show empty state and add action.
  - Editor:
    - material picker from `/inventory/dropdown?status=true`.
    - quantity integer per product unit.
    - display measure unit per material.
    - add/remove materials.
    - save full recipe via `PUT /products/{id}/recipe`.
    - clear recipe by saving empty array.
- **Recipe options** (per-product variations for dough/filling/flavor):
  - Fetch all options via `GET /products/{id}/recipe-options`.
  - Display grouped by type (Dough, Filling, Flavor) with option name and `hasRecipe` indicator.
  - Each option has its own ingredient list (same editor pattern as base recipe).
  - Create/update an option via `PUT /products/{id}/recipe-options` with type, name, and items.
  - Delete an option by sending empty items array.
  - Option names come from the preset catalog (`GET /products/{id}/order-options`) — the editor should allow selecting from these presets when creating a new option.
  - The web groups options by type in the recipe card component.

### Inventory

Reference:

- `inventory/page.tsx`
- `inventory-mobile-list.tsx`
- `new-material-sheet.tsx`
- `restock-sheet.tsx`
- inventory detail page.

Native requirements:

- New tab/section labelled `Estoque`.
- Materials list:
  - search.
  - status filter: active/inactive/all.
  - material name.
  - inactive chip.
  - quantity with unit.
  - unit cost per unit.
  - negative quantity warning.
- Create material:
  - name.
  - measure unit.
  - initial quantity.
  - total cost in BRL converted to cents.
- Material detail:
  - quantity.
  - unit cost.
  - status.
  - created/updated.
  - edit name/unit.
  - restock action.
  - active/inactive action.
- Restock:
  - quantity.
  - total cost in cents.

### Clients

Reference:

- `clients/page.tsx`
- `clients-mobile-list.tsx`
- client detail components.

Native requirements:

- Search.
- Status filter active/inactive.
- Client row:
  - avatar/initial.
  - name.
  - mobile.
  - status.
  - optional totals when list endpoint provides them.
- Create/edit:
  - name required.
  - mobile optional.
- Detail:
  - contact card.
  - KPI band:
    - total orders.
    - total spent.
    - last order date.
  - notes card if backend supports notes later; otherwise omit or mark future.
  - order history list.
- Active/inactive/delete actions.

### Cash dashboard

Reference:

- `cash/page.tsx`
- `cash-hero-balance.tsx`
- `cash-flow-chart.tsx`
- `cash-category-section.tsx`
- recent entries.

Native requirements:

- Preset picker: Today, Week, Month, Custom.
- Hero balance card:
  - burgundy gradient.
  - net balance.
  - inflow.
  - outflow.
  - entries count.
- Flow chart:
  - inflow/outflow bars.
- Category breakdown:
  - outflow by category.
  - icon/color per category.
- Recent entries list.
- Link to all entries.
- New entry action.

### Cash entries

Reference:

- `cash/entries/page.tsx`
- `entries-mobile-list.tsx`
- `cash-entry-row.tsx`
- `CashEntryForm`.

Native requirements:

- List grouped by billing date.
- Header daily net amount.
- Search by counterparty.
- Filters:
  - type.
  - category.
  - source.
  - date range.
  - include deleted if admin/product decision.
- Row:
  - type icon.
  - counterparty.
  - billing date.
  - category.
  - signed amount.
  - source badge.
- Create/edit entry:
  - billing date.
  - type.
  - category.
  - counterparty.
  - amount in BRL converted to cents.
  - notes.
- Delete:
  - require reason.
  - call DELETE with JSON body.
- Detail:
  - all fields.
  - source link if order payment/reversal.
  - audit log if needed.

### Notifications/settings

Native V2 requirements:

- Add settings/notifications screen.
- Request local notification permission only from a button tap.
- Show states:
  - not determined.
  - denied.
  - authorized.
- Schedule due-today 08:00 and due-tomorrow 15:00 reminders only after permission.
- Because local notifications depend on locally fetched orders, refresh schedules after successful order list load.
- Future APNs remote push should be a separate backend project.

## 10. Implementation Phases

### Phase 0 - Contract Alignment

- Confirm production API host.
- Resolve delivery field mismatch between web and backend.
- Resolve product response metadata mismatch for `description` and `hasRecipe`, or keep iOS tolerant until backend/web align.
- Confirm whether `/clients/all` returns `status` or `isActive`; V2 should standardize on `status`.
- Decide native notifications scope: local only vs APNs.

Acceptance:

- A short `API_CONTRACT_NOTES.md` or GitHub issue exists for backend/web mismatches.
- iOS V2 DTOs are based on confirmed contracts.

### Phase 1 - Foundation

- Add shared `APIClient`.
- Add shared error handling and session expiration.
- Add shared date/money formatters.
- Add design system tokens/components.
- Replace hard-coded URLs.
- Fix auth flow and keychain session gate.
- Remove notification permission request from app launch.

Acceptance:

- Login works.
- A `401` logs out globally.
- All services use one base API client.
- Unit tests cover date parsing, money parsing, and representative API error decoding.

### Phase 2 - Orders Parity

- Rebuild orders list with grouped mobile V2 layout.
- Rebuild new order flow with client/product pickers, item customization, delivery, references, and summary.
- Rebuild order detail and edit.
- Match mobile web product variant flow: grouped product names, size selector, variant-specific price, and no UUID shown to users.
- Match mobile web item value flow: one editable unit-value input, non-negative integer-cent value, totals recalculated from overrides.
- Preserve historical order support; past delivery dates must be accepted in create/edit/status flows.
- Implement upload presigned URL flow.
- Implement payment/admin actions.
- Decode update warnings.

Acceptance:

- iOS can create the same order payload as web.
- iOS can create/edit older orders and mark them completed without future-date validation.
- iOS can override item unit values and sends `unitPrice`/`paidUnitPrice` correctly.
- iOS can upload and display references.
- iOS can advance statuses and show inventory warnings.
- iOS and web show the same order totals/statuses for the same data.

### Phase 3 - Products and Recipes

- Fix product DTO keys and multipart fields.
- Rebuild product list card visual.
- Rebuild product create/edit/detail.
- Load the products list with `size=100`.
- Add recipe fetch/editor.
- Add recipe option editor for dough/filling/flavor variants.
- Add material dropdown integration for recipes.

Acceptance:

- Product create/update works with image, category, size, description.
- Recipe add/edit/clear works.
- Recipe option add/edit/clear works for cake doughs, cake fillings, brigadeiro flavors, and cookie flavors.
- Product cards show recipe indicator.

### Phase 4 - Inventory

- Add inventory models/service/view models.
- Add materials list/detail/create/edit/restock.
- Add active/inactive actions.
- Add measure unit mapping tolerant of string/numeric backend values.

Acceptance:

- iOS reaches parity with mobile web inventory.
- Recipe editor can use active materials.

### Phase 5 - Clients

- Fix client status model.
- Rebuild client list/detail/create/edit.
- Add client KPI and order history.
- Add active/inactive/delete actions with business-rule error display.

Acceptance:

- iOS client detail matches web client detail data.
- Client list supports search/status filters.

### Phase 6 - Cash

- Align cash DTOs/filters.
- Rebuild cash dashboard with hero balance, chart, category breakdown, recent entries.
- Rebuild entries list grouped by date.
- Add create/edit/delete/detail and audit view if needed.

Acceptance:

- Summary and entries match web for the same date range.
- Create/edit/delete flows preserve cents and UTC dates.

### Phase 7 - Dashboard

- Align dashboard filters to `createdAtFrom`/`createdAtTo`.
- Rebuild KPI, revenue, pipeline, top product, and top client sections.
- Add export share flow.

Acceptance:

- Dashboard numbers match web for same filters.
- CSV/PDF export downloads and opens share sheet.

### Phase 8 - Notifications and Polish

- Add notification settings screen.
- Add user-controlled local notification authorization.
- Schedule due reminders after order refresh.
- Add app-wide empty/loading/error states.
- Add accessibility labels, Dynamic Type checks, and VoiceOver pass.
- Add offline/network retry affordances for read screens.

Acceptance:

- No permission prompt appears before explicit user action.
- Notification settings accurately reflect system permission.
- Main workflows are usable with Dynamic Type up to at least accessibility medium.

## 11. Test Plan

### Unit tests

- APIClient:
  - attaches bearer token.
  - handles `401` by clearing session.
  - decodes plain string error bodies.
  - decodes JSON error bodies if present.
- Date coding:
  - fractional ISO.
  - non-fractional ISO.
  - local date range to UTC bounds.
- Money:
  - `"15,50"` -> `1550`.
  - `"15.50"` -> `1550`.
  - `1550` -> `R$ 15,50`.
- Enum decoding:
  - order status strings.
  - measure unit strings and numeric values.

### Integration tests or mocked service tests

- Login success/failure.
- Orders list decode.
- Create order payload encoding.
- Update order response with and without warnings.
- Product multipart body field names.
- Inventory create/restock payloads.
- Cash entry create/delete payloads.

### Manual QA

- Login/logout/session expiration.
- Create an order with:
  - pickup.
  - delivery address.
  - multiple items.
  - duplicate product names with different sizes; verify the picker shows one product row, size labels are visible, selected size changes price, and no UUID is displayed.
  - an overridden non-negative unit value; verify totals and payload use the override.
  - item observation/massa/sabor.
  - references.
- Create or edit an older order with a past delivery date and change it to `Completed`.
- Advance order through Received -> Preparing -> WaitingPickupOrDelivery -> Completed.
- Cancel order and cancel item.
- Mark paid/unpaid as admin.
- Create product with image.
- Add recipe and verify inventory warning behavior when preparing order.
- Create/restock material.
- Create client and verify detail stats after order creation.
- Create cash inflow/outflow and verify dashboard.
- Export dashboard CSV/PDF.
- Enable local notifications from settings only.

## 12. Open Backend/Web Issues For Follow-Up

- Align `delivery` vs `deliveryAddress`.
- Confirm product `description` is included in `ProductResponse`; backend reviewed has `ProductResponse` without description while web expects it.
- Confirm product `hasRecipe` is included in `ProductResponse`; web expects it.
- Confirm API reference is updated for inventory, cash, push, delivery, paidAt, and paidByUserName.
- Confirm production base URL and CORS/native client expectations.
- Consider adding first-class native APNs subscription endpoints if remote iOS push is required.

## 13. Definition Of Done For iOS V2

- The app uses a single shared networking/session layer.
- No known DTO key mismatches remain.
- All V2 web mobile modules exist on iOS:
  - Auth
  - Dashboard
  - Orders
  - Products
  - Product Recipes
  - Inventory
  - Clients
  - Cash
  - Notification settings/local reminders
- iOS visual language matches the web V2 brand and mobile layout patterns.
- Critical workflows are covered by tests or documented manual QA.
- The app can be run against local and production APIs by changing environment configuration, not source code.

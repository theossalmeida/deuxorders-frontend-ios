# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is an Xcode project. All building, testing, and running is done through Xcode or `xcodebuild`.

```bash
# Build
xcodebuild -project DeuxOrders.xcodeproj -scheme DeuxOrders -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests
xcodebuild -project DeuxOrders.xcodeproj -scheme DeuxOrders -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a single test
xcodebuild -project DeuxOrders.xcodeproj -scheme DeuxOrders -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:DeuxOrdersTests/DeuxOrdersTests/testName
```

## Architecture

**Pattern:** MVVM with SwiftUI. No third-party dependencies — only Apple frameworks.

**Auth flow:** `LoginView` → `LoginViewModel` → `AuthService` → receives JWT → stored in Keychain via `KeychainService.save(token, forKey: "user_token")` → `MainTabView` presented.

**Session expiration:** Any 401 response clears the Keychain token and posts `Notification.Name.sessionExpired`. `LoginView` observes this notification and sets `isAuthenticated = false` to return to login.

**Data flow:** Each domain (Orders, Clients, Products) follows the same pattern:
- `Model` (Codable structs) in `Models/`
- `Service` (URLSession-based API calls) in `Services/`
- `ViewModel` (`@MainActor ObservableObject`) in `ViewModels/`
- `View` (SwiftUI) in `Views/`

`OrdersViewModel`, `DashboardViewModel`, and `CashFlowViewModel` are all instantiated as `@StateObject` in `MainTabView` and passed down to their respective views. `ProductsView` and `ClientsView` create their own VMs internally.

**Reusable order form components:** `OrderFormComponents.swift` contains `OrderBasicInfoSection`, `AddItemFormSection`, and `OrderTotalSection`, shared by `NewOrderView` and `EditOrderView`.

**Shared formatters:** `Formatters` is a caseless enum defined in `NewOrderView.swift` with two static properties used app-wide: `Formatters.currency` (BRL `NumberFormatter`) and `Formatters.iso8601` (`ISO8601DateFormatter`).

**Dashboard concurrency:** `DashboardViewModel.loadAll()` fires all four analytics fetches in parallel using `async let` and tuple unpacking. `DateRangePreset` enum drives date range selection (today/week/month/custom).

**Dashboard export:** `DashboardViewModel.exportOrders(format:)` calls `/dashboard/export?startDate=&endDate=&format=csv|pdf` (optionally `&status=`), writes the result to `FileManager.default.temporaryDirectory`, and exposes the URL via `exportedFileURL` — the view presents a `UIActivityViewController` sheet when this is non-nil.

**Reference image uploads:** `OrderService` supports a two-step S3 presigned upload flow: `getPresignedUrl(fileName:contentType:)` → POST `/orders/references/presigned-url` → returns `uploadUrl` + `objectKey`; then `uploadImage(to:data:contentType:)` → PUT directly to the presigned URL (no auth header). `deleteReference(orderId:objectKey:)` → DELETE `/orders/{id}/references` with `{ objectKey }` body. The `objectKey` strings are stored in `Order.references`.

**Light mode only:** `DeuxOrdersApp` sets `.preferredColorScheme(.light)` — the app does not support dark mode.

**Local notifications:** `NotificationService` (singleton) schedules two `UNCalendarNotificationTrigger`s with `repeats: true` — 8:00 AM (pending orders today) and 3:00 PM (pending orders tomorrow). Re-scheduled via `scheduleNotifications(orders:)` after every `loadOrders()` call.

**Navigation:** 5-tab layout — Painel (Dashboard) | Pedidos (Orders) | Caixa (Cash Flow) | Produtos (Products) | Clientes (Clients). Tab accent color is brand burgundy.

**Cash flow module:** `CashFlowViewModel` manages entries, summary, filters, and chart data. `CashService` calls `/cash/entries` (CRUD) and `/cash/summary`. Cash dashboard shows hero balance, bar chart, category breakdown, and recent entries. Entries support filtering by type (Inflow/Outflow) and search by counterparty.

**Order payment tracking:** `Order` has `paidAt` and `paidByUserName` fields. `OrderService.payOrder(id:)` → PATCH `/orders/{id}/pay`; `unpayOrder(id:reason:)` → PATCH `/orders/{id}/unpay`. Payment creates a cash entry automatically on the backend.

**Detail views:** `OrderDetailView` shows status pipeline, items, delivery, payment, client cards. `ClientDetailView` loads stats + order history via GET `/clients/{id}?orders=true`. `ProductDetailView` shows image, info, performance placeholder, and inline edit.

**Order status pipeline:** Visual stepper in `OrderDetailView`: Received → Preparing → WaitingPickupOrDelivery → Completed. Canceled shown as a branch. `Order.nextStatus` computed property determines the next logical status.

## API

Base URL: `https://api-orders.deuxcerie.com.br/api/v1/`

All authenticated requests use `Authorization: Bearer <token>` loaded from Keychain. The `OrderService` handles auth, fetching, mutations, and date decoding (ISO 8601 with and without fractional seconds — dual formatters to handle backend inconsistency).

`OrderService` also exposes `/clients/dropdown?status=true` and `/products/dropdown?status=true` for populating order form pickers. Payment endpoints: PATCH `/orders/{id}/pay` and PATCH `/orders/{id}/unpay` (body: `{ reason }`).

`CashService` exposes: GET `/cash/entries` (paginated, filterable), GET `/cash/entries/{id}`, POST `/cash/entries`, PUT `/cash/entries/{id}`, DELETE `/cash/entries/{id}` (body: `{ reason }`), GET `/cash/summary`.

`ClientService.fetchClientDetail(id:)` calls GET `/clients/{id}?orders=true` returning `ClientDetail` with stats and order history.

**Monetary values are stored as integers in cents** (e.g., `totalPaid: 1500` = R$15,00). Divide by 100.0 for display and format with `BRL` locale.

## Conventions

- UI language is Portuguese (Brazil). All user-facing strings, labels, and error messages are in pt-BR.
- Brand color: `Color(red: 88/255, green: 22/255, blue: 41/255)` (dark burgundy).
- `NetworkError` (defined in `AuthModels.swift`) is the single error type for all network failures across all services.
- Optimistic UI updates with rollback: used in `OrdersViewModel`, `ClientsViewModel`, and `ProductsViewModel` — local state updated first, reverted on API failure.
- `OrderStatus` raw values match backend strings exactly: `"Pending"`, `"Completed"`, `"Canceled"`. The enum has `localizedName` (pt-BR display string) and `color` computed properties for UI.
- `KeychainService` is a caseless enum with static methods. Service identifier: `"br.com.deuxcerie.orders"`.
- `ProductResponse` uses `CodingKeys` to map `descricao` (Portuguese backend field) → `description`. `OrderInput` and `OrderItemInput` use snake_case keys (`clientid`, `deliverydate`, `productid`, `unitprice`) due to backend inconsistency.

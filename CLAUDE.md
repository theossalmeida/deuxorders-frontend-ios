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

**Auth flow:** `LoginView` → `LoginViewModel` → `AuthService` → receives JWT → stored in `UserDefaults` under `"user_token"` → `MainTabView` presented.

**Data flow:** Each domain (Orders, Clients, Products) follows the same pattern:
- `Model` (Codable structs) in `Models/`
- `Service` (URLSession-based API calls) in `Services/`
- `ViewModel` (`@MainActor ObservableObject`) in `ViewModels/`
- `View` (SwiftUI) in `Views/`

The `OrdersViewModel` is instantiated once in `MainTabView` and passed down to `OrdersView`, `NewOrderView`, and `EditOrderView` — these three views share the same VM instance.

**Background notifications:** `NotificationService` (singleton) registers two `BGAppRefreshTask`s at app init (8:00 and 15:00). They fetch pending orders and fire local notifications. Must be re-scheduled every time the app goes to background via `scheduleAllTasks()`.

## API

Base URL: `https://api-orders.deuxcerie.com.br/api/v1/`

All authenticated requests use `Authorization: Bearer <token>` from `UserDefaults`. The `OrderService` handles auth, fetching, mutations, and date decoding (ISO 8601 with and without fractional seconds).

**Monetary values are stored as integers in cents** (e.g., `totalPaid: 1500` = R$15,00). Divide by 100.0 for display and format with `BRL` locale.

## Conventions

- UI language is Portuguese (Brazil). All user-facing strings, labels, and error messages are in pt-BR.
- Brand color: `Color(red: 88/255, green: 22/255, blue: 41/255)` (dark burgundy).
- `NetworkError` (defined in `AuthModels.swift`) is the single error type for all network failures across all services.
- Optimistic UI updates in `OrdersViewModel.updateOrderStatus` — status is updated locally first, then reverted on failure.

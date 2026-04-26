# API Contract Notes

Last updated: 2026-04-26

These are the backend/web contract points iOS V2 depends on while matching the mobile web app.

## Confirmed In iOS V2

- Production API base URL is centralized in `AppEnvironment` as `https://api-orders.deuxcerie.com.br/api/v1/`.
- Product money values decode and persist in iOS models as integer cents.
- Product list decoding accepts the canonical paginated shape and the temporary raw-array shape.
- Order create/update encodes delivery as the canonical `delivery` key.
- Order read decoding accepts both canonical `delivery` and legacy `deliveryAddress`.
- Product responses tolerate missing `description` and default missing `hasRecipe` to `false`.
- Client decoding accepts canonical `status` and legacy `isActive`, but encodes `status`.
- Dashboard summary/chart/ranking queries use `createdAtFrom` and `createdAtTo`.
- Dashboard export uses `from` and `to`.
- Inventory measure units decode from both string and numeric enum values; writes send numeric values.

## Backend/Web Follow-Up

- Align all order endpoints on a single delivery field. The current iOS V2 implementation sends `delivery` and only keeps `deliveryAddress` as a read fallback.
- Ensure product list/detail responses include `description` and `hasRecipe`.
- Confirm `/clients/all` consistently returns `status`.
- Keep native notifications local-only until backend APNs endpoints exist. Browser Web Push subscription payloads should not be reused by native iOS.

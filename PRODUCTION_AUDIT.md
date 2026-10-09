# Production Audit — Driver and Provider Flutter App

Date: 2026-07-31

## Scope and evidence

This checkout contains one Flutter project that combines Driver and Provider
features. It does not contain a User application or Backend source code. The
User app, backend controllers/services/repositories/database queries, server
Socket.IO handlers, dispatch, payments, and server-side authorization could
therefore not be inspected. They require their repositories and environment
configuration before a complete system audit can be signed off.

This report is based on static inspection of all Dart modules, API constants,
services, controllers, navigation calls, socket registration, Android/iOS
configuration, and dependency configuration in this checkout. A full Flutter
analyzer run was requested but not authorized, so runtime/API-contract findings
still require integration and device testing.

## Executive production verdict

**Not production-ready.** Driver ride lifecycle code is substantially wired to
APIs and Socket.IO, and Provider fleet/live-tracking data has API-backed paths.
However, release is blocked by missing system repositories, mock/static screens,
incomplete Provider CRUD and wallet flows, no token-refresh strategy, no
pagination, route duplication, PII-heavy debug logging, incomplete error states,
and insufficient tests.

## Critical findings

| Area | Finding | Impact | Required action |
|---|---|---|---|
| System scope | User app and Backend are absent | Booking, payment, dispatch, DB, server socket and RBAC behavior cannot be verified | Supply both repositories, API schema, migrations and environment templates |
| Provider session | Splash restored every session through the Driver profile endpoint | Valid Provider sessions could receive 403 and be cleared | Fixed in this audit: restore now selects the profile endpoint using `app_mode` |
| Provider architecture | Two independent Provider UI trees exist under `features/provider` and `features/provider_app` | Divergent screens, unreachable fixes, inconsistent navigation and duplicated maintenance | Consolidate on `features/provider`; migrate useful `provider_app` code and delete the duplicate tree after regression testing |
| Release secrets | Google Maps API key is committed in AndroidManifest | Key theft/quota abuse risk | Rotate key, restrict by application/signing certificate, inject through build configuration |
| Backend lifecycle | Backend source is unavailable | Cannot verify state transitions, idempotency, transactions or race conditions | Audit server with booking state-machine tests before release |
| Test coverage | Only the template widget test is present | Core auth/booking/payment/socket regressions are undetected | Add unit, widget, contract and end-to-end tests |

## User app audit

**Status: blocked — source not present.** None of Login/OTP/session refresh,
home content, booking, user ride tracking, chat/call, history, payment, promo,
rating or navigation can be verified from this repository.

Priority: **Critical**. Required inputs are the User Flutter repository,
flavor/environment files, API/OpenAPI contract, socket event contract and test
credentials.

## Driver app audit

### Authentication and session

- Login and OTP repositories exist and use server endpoints.
- Cookie and token storage use `flutter_secure_storage`; migration removes
  legacy plaintext values when secure storage succeeds.
- Session restore validates the profile before entering the app.
- Logout calls the backend, clears secure credentials/preferences and closes
  the socket.
- **Critical missing:** no refresh-token endpoint, refresh lock, retry queue or
  token-expiry-aware renewal. A 401 immediately logs the user out.
- **High:** unauthorized handling performs navigation from the API singleton;
  simultaneous requests are guarded, but navigation and UI messaging remain
  coupled to networking.
- **High:** many controllers print response-derived personal data. Release logs
  must be disabled/redacted.
- **Medium:** splash enforces an artificial two-second delay.

### Home and availability

- Driver profile, rating, earnings, trips, hours and assigned vehicles are
  mapped dynamically with null fallbacks.
- Online/offline and heartbeat flows exist.
- `acceptedTrips` is now mapped and acceptance-rate fallback is calculated when
  the dashboard does not return a rate.
- **High:** acceptance rate fallback assumes `totalTrips` is the denominator.
  Backend should expose `totalRequests` and a canonical `acceptanceRate`; trips
  completed and requests offered are not semantically equivalent.
- **High:** foreground tracking is not a durable Android/iOS background service
  despite background permissions. Location updates can stop when the app is
  suspended or killed.
- **Medium:** location errors are printed but not queued/retried or surfaced.

### Ride lifecycle

- Passenger endpoints exist for accept, reject, arrive, start and complete.
- Goods endpoints exist for accept/reject, arrival, pickup OTP, start, location,
  destination, delivery OTP and completion.
- Active-trip recovery and status-based navigation exist in Driver Home.
- Cancellation listeners exist on pickup, arrived and in-progress screens.
- Pickup and delivery OTP input is validated as four digits before submission.
- Chat uses socket history/message events; listeners are removed in dispose.
- “Voice call” is a normal device `tel:` call, not in-app VoIP. Rename the
  feature or integrate a consented VoIP provider if true voice calling is a
  requirement.
- **High:** `RideService` returns only booleans, discarding error bodies/status
  and preventing actionable recovery.
- **High:** lifecycle transition validity is trusted to the backend, which is
  unavailable for audit. Buttons require server-confirmed state and idempotency.
- **High:** delivery/start OTP can be present in the ride payload; ensure the
  backend never exposes verification secrets to the Driver before entry.
- **Medium:** rating-user support is unclear; current review endpoint is named
  `submitDriverReview`, which suggests the wrong review direction.

### History and earnings

- The main booking-history controller merges passenger history, ongoing trips
  and goods bookings and deduplicates by ID.
- **High:** no pagination or load-more behavior exists.
- **High:** errors are swallowed and represented as empty lists; users cannot
  distinguish “no bookings” from network/server failure.
- **High:** `trips_screen.dart` contains a completely static trip list and fare.
  Remove the route or bind it to `BookingHistoryController`.
- **High:** Activity and some earnings labels contain static currency values.
  Every monetary widget must bind to a typed API model.

## Provider app audit

### Dashboard

- Dashboard stats endpoint maps vehicle, driver, booking, running-trip, revenue
  and wallet values.
- Provider name and KYC status are API-backed.
- Pull-to-refresh exists.
- **High:** dynamic values are assigned with unchecked `dynamic` arithmetic;
  malformed/null numeric strings can throw or silently map incorrectly.
- **High:** dashboard “live trip data” remains `RxList<dynamic>` instead of a
  typed model.
- **Medium:** initial loading performs dashboard first and then other calls,
  increasing startup latency; independent calls can run concurrently.

### Driver management

- Add, fetch, detail, approve and vehicle-assignment paths exist.
- Nested driver profile images are mapped and displayed with fallback.
- **Critical missing:** no edit-driver API flow.
- **Critical missing:** no remove/deactivate-driver API flow.
- **High:** status editing is absent; approval is not equivalent to operational
  enable/disable.
- **High:** lists have no pagination, retry UI or explicit error state.

### Fleet management

- Add, fetch, update and assign/reassign paths exist.
- Vehicle photos/documents are submitted through multipart form data.
- **Critical missing:** no delete/deactivate-vehicle API flow.
- **High:** edit UI and update contract are incomplete; update lookup compares a
  vehicle number against an ID and then merely refetches.
- **High:** default capacity (`4 seater`), route (`No Route`) and other model
  fallbacks can conceal missing backend fields as real operational data.
- **Medium:** file MIME detection and upload retry/progress need contract tests.

### Live tracking

- The reachable Fleet Monitoring screen polls every 10 seconds, pauses outside
  active lifecycle, prevents overlapping requests, plots typed locations, fits
  bounds and displays active-trip details.
- Offline marker text was corrected in this audit.
- **High:** duplicate live-tracking model/service/screen exists in the unused
  `provider_app` tree.
- **High:** marker location validity checks should reject out-of-range and zero
  coordinates, not just null values.
- **Medium:** polling should use backoff/jitter after repeated failures and show
  staleness based on `lastLocationAt`.

### Wallet, profile and analytics

- Provider profile and KYC views have API-backed portions.
- **Critical:** Provider Wallet is a static prototype with hardcoded totals,
  fares, distance, time, payouts and transactions.
- **Critical missing:** no Provider wallet/ledger/payout endpoint is defined.
- **High missing:** company details edit, bank-details management and complete
  provider document lifecycle are not demonstrated end-to-end.
- **High:** analytics is limited to dashboard counters; no time-series endpoint,
  filter contract or export exists.
- Profile phone/email fake fallbacks were removed in this audit.

## Hardcoded and mock data inventory

Data hardcoding that must be removed or the screens must be made unreachable:

- `features/dashboard/trips_screen.dart`: static statuses, routes, times, fares.
- `features/provider/screens/provider_wallet_screen.dart`: static wallet,
  earnings, fare breakdown, payout and transaction values.
- `features/providers/provider_list_screen.dart`: mock provider names/phones.
- `features/providers/provider_detail_screen.dart`: mock vehicle list.
- `support/ticket_chat_screen.dart`: generated mock support replies.
- `features/provider_app/dashboard` and `features/provider_app/fleet`: static
  trip locations and earnings in the duplicate Provider tree.
- `features/dashboard/activity_screen.dart`: static currency values.
- Profile placeholder identity values were partially removed in this audit.

Static display copy, theme colors, spacing, country dial code, empty-state text
and icons are not business-data hardcoding and should not be replaced by APIs.
They should move to localization/design tokens where appropriate.

## API audit

- Centralized client adds Cookie and Bearer authentication and globally handles
  401 responses.
- Null-tolerant mapping exists in many models but is inconsistent; numerous
  screens still consume raw `Map`/`dynamic` values.
- No OpenAPI-generated client or schema validation exists.
- No pagination contract is used for drivers, fleet, notifications or history.
- No standardized `Result<T>`/failure type exists; some services return
  `Response`, some booleans, and controllers often swallow exceptions.
- Request cancellation is absent when screens close.
- Retries/backoff exist neither globally nor for safe idempotent reads.
- Base URLs are compile-time constants instead of environment/flavor config.
- Network status exists, but offline caching/queued actions are not implemented.
- The API client still has verbose logging in several non-GET wrappers and
  feature controllers. Redact tokens, OTPs, phones, emails and payload bodies.

## Socket.IO audit

- Authentication is sent through query, auth and Cookie header; server behavior
  must be verified before retaining all three mechanisms.
- Reconnection, connection state, stored callback registration and explicit
  listener removal exist.
- Driver ride-request, cancellation, goods lifecycle, chat and payment events
  are represented.
- **High:** debug listeners duplicate subscriptions for several production
  events and log complete payloads, increasing noise and PII exposure.
- **High:** event names mix uppercase underscore, colon and dotted conventions;
  this needs a versioned shared contract with the backend.
- **High:** emits are dropped when disconnected. Critical actions need API
  confirmation or an idempotent queue/ack protocol.
- **High:** no acknowledgement timeout/correlation IDs are used.
- **Medium:** generic snackbars for arbitrary events can show backend/internal
  messages directly to users.
- Provider-side socket behavior is not implemented/verified; Provider live
  tracking uses polling only.

## Navigation audit

- Driver and primary Provider shells use `IndexedStack` and back-history logic.
- Active Driver trip resume exists via profile/ongoing-trip recovery.
- Two navigation systems (`Navigator` and GetX) are mixed throughout.
- Duplicate Provider navigation shells have four versus five tabs and different
  styling/behavior.
- Some child back actions use `offAll`, destroying the stack instead of popping.
- No declarative route table, guards, deep links or booking deep-link resume is
  configured.
- Screen lists are rebuilt from getters on each shell rebuild; keep stable child
  instances where their state must survive.

## UI, accessibility and performance audit

- ScreenUtil is used widely, but fixed heights and large nested Rows can still
  overflow with accessibility text scaling/localization.
- Material styles are custom; Material 3 adoption is not consistent.
- Loading/empty/error handling varies widely. Provider live tracking is a good
  pattern; history and CRUD screens need equivalent states.
- Network images mostly lack caching policy, semantic labels and consistent
  broken-image handling.
- Many large screen widgets exceed 1,000 lines and mix networking, lifecycle,
  parsing and rendering, making rebuilds and testing expensive.
- Periodic timers and socket listeners are generally disposed in audited ride
  screens, but every new route requires lifecycle tests.
- No localization framework is configured.
- No performance profiling evidence exists for maps, long lists or image-heavy
  fleet screens.

## Security audit

- Secure session storage is a positive baseline.
- Rotate and externalize the committed Maps key.
- Implement access/refresh token rotation and server-side revocation.
- Confirm cookies use Secure, HttpOnly and appropriate SameSite attributes.
- Enforce role authorization on every backend route; client role selection is
  not a security boundary.
- Never log OTPs, tokens, cookies, phone/email, exact location or booking payloads
  in release builds.
- Apply certificate/network security policy appropriate to the threat model.
- Add jailbreak/root/emulator policy only if required by business risk; do not
  treat it as a substitute for backend authorization.
- Validate upload content by signature and server-side scanning, not extension.
- Define retention/consent rules for background location and call/chat data.

## Backend audit checklist (blocked until source is supplied)

Priority **Critical** for all release-gating items:

1. Encode booking lifecycle as an explicit state machine with authorized
   transitions, optimistic locking and idempotency keys.
2. Make accept/assignment atomic so two drivers cannot win one booking.
3. Wrap trip completion, ledger entry, commission and payout mutations in a
   database transaction/outbox workflow.
4. Store OTP hashes with expiry, attempt limits, purpose and one-time use.
5. Enforce Driver/User/Provider/Admin ownership and role scopes in middleware
   and repository queries.
6. Authenticate socket handshake, join only authorized rooms and validate every
   event payload server-side.
7. Persist chat with ordering, delivery status and authorization.
8. Add payment webhook signature verification, replay protection and
   reconciliation.
9. Add cancellation policy, refunds, driver reassignment and race-condition
   tests.
10. Add indexes for active booking, driver availability/location, provider
    membership and history pagination queries; verify with query plans.
11. Add structured redacted logs, traces, metrics, alerting and audit logs.
12. Publish OpenAPI and socket schemas and run consumer contract tests.

## Prioritized missing-feature backlog

| Priority | Module / screen | Missing functionality | Suggested implementation |
|---|---|---|---|
| Critical | User app | Entire source unavailable | Add repository and run full audit |
| Critical | Backend | Entire source unavailable | Add server, schema/migrations and tests |
| Critical | Provider Wallet | Real ledger, payouts, filters, transactions | Typed paginated wallet APIs and state/controller |
| Critical | Provider Drivers | Edit/remove/deactivate | Role-protected PATCH/DELETE endpoints plus confirmation/error UI |
| Critical | Provider Fleet | Delete/deactivate and complete edit | Typed PATCH/DELETE APIs, conflict validation and refresh |
| Critical | Auth | Token refresh/rotation | Single-flight refresh interceptor and secure rotated token storage |
| High | Driver History | Pagination and failure state | Cursor pagination, retry/empty/error states |
| High | Support Chat | Real support messaging | Persisted socket/API chat; remove fake delayed responses |
| High | Navigation | Unified routing/deep links | One declarative router with role/active-booking guards |
| High | Driver Tracking | Reliable background operation | Platform-compliant foreground/background service and retry queue |
| High | Socket | Ack/idempotency/offline queue | Versioned event envelope and API fallback |
| High | Provider Analytics | Time-series/filter/export | Analytics endpoints and typed charts |
| Medium | UI | Localization/accessibility | ARB localization, semantics and text-scale tests |
| Medium | Images | Caching and upload progress | Cached image layer and cancellable upload state |
| Medium | Observability | Crash/performance/network monitoring | Redacted telemetry with release health dashboards |

## Changes completed during this audit

- Provider session restore now validates through the Provider profile endpoint.
- API GET response bodies are no longer dumped to logs; debug logs retain only
  method/path/status.
- Provider live-map offline marker text is correct.
- Fake phone/email profile fallbacks were removed.
- Driver accepted-trip count and acceptance-rate mapping were completed in the
  preceding implementation work.
- Provider live tracking, typed markers and driver details were completed in the
  preceding implementation work, though the duplicate Provider tree still needs
  consolidation.

## Release gate

Do not approve production release until all Critical items are closed, the User
and Backend repositories have been audited, Flutter analyze/tests pass in CI,
contract tests run against staging, and passenger/goods lifecycle E2E tests cover
reconnect, duplicate actions, cancellations, payment failure and app termination.

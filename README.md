# PRM393 PE – Shopping App (Flutter)

A Flutter shopping app for the PRM393 individual practical exam (PE).
All data is stored on the device with SQLite (`sqflite`). Remember Me is stored in `SharedPreferences`.

## Features

| Requirement | Implementation |
|---|---|
| Register | Full Name, Email, Password, Confirm Password with validation; duplicate email check; password stored as SHA-256 hash |
| Login + Remember Me | Login by email/password; Remember Me saves the email in `SharedPreferences` and logs the user in automatically next launch |
| Product list | `ListView.builder` with image, name, description, price |
| Product CRUD | Add / edit / delete product; image from a URL or a local file picked from the gallery |
| Search & sort | Real-time search by name; sort by price ascending / descending |
| Cart | Add from the list or the detail screen, change quantity, remove, checkout |
| Revenue | Every checkout records an order; total revenue filtered by All / Day / Month / Year |
| UI | Material 3, `go_router` navigation with auth redirect, `SnackBar`, `AlertDialog`, `Dialog`, one screen per feature |

## Project structure

```
lib/
  main.dart                 # app entry, providers
  app_router.dart           # go_router routes + login redirect
  data/app_database.dart    # SQLite schema, queries, seed products
  models/models.dart        # AppUser, Product, CartItem, OrderRecord
  providers/                # AuthProvider, ProductProvider, CartProvider (ChangeNotifier)
  screens/                  # login, register, product list/detail/form, cart, revenue
  utils/                    # validators, price format and revenue filters
  widgets/                  # product image, cart badge + add-to-cart feedback
test/app_logic_test.dart    # unit tests on an in-memory database
```

## Run

```bash
flutter pub get
flutter run
```

Register a new account on first launch; 5 sample products are seeded automatically.

## SePay bank-transfer checkout (optional)

Without configuration, Checkout places the order right after the confirm dialog.
With SePay configured, Checkout shows a VietQR code with a unique transfer note
(`PRM<timestamp>`), polls the SePay transactions API every 5 seconds, and places
the order only when a transfer with that note and at least the order total arrives
(10-minute timeout, cancel anytime).

1. Copy `sepay.example.json` to `sepay.json` (git-ignored) and fill in your bank
   code (e.g. `VCB`, `MB`, `TCB`), account number linked to SePay, and the API
   token from my.sepay.vn → Company configuration → API Access.
2. Run with:

```bash
flutter run --dart-define-from-file=sepay.json
```

Note: the token is compiled into the app, which is fine for a demo but not for a
public release; production apps should check payments from a backend or webhook.

## Test

```bash
flutter analyze
flutter test
```

The tests cover validation, register/login/Remember Me, password hashing, product search/sort/CRUD, cart and checkout, and revenue filtering by day/month/year.

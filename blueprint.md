# Cash Book App Blueprint

## Overview

A simple and elegant app to manage your daily income and expenses. It helps you track your financial transactions and provides a clear overview of your balance.

## Features

- **Onboarding Screen:** A beautiful introduction for new users to get acquainted with the app's features.
- **Track Income & Expenses:** Easily add new transactions, categorizing them as income or expense.
- **View Transaction History:** See a list of all your past transactions, sorted by date.
- **Current Balance:** Get a real-time view of your current balance on the home screen.
- **Total Income & Expense:** See a summary of your total income and total expense on the home screen.
- **Edit & Delete Transactions:** Easily edit or delete any transaction from the list.
- **Date Selection:** Choose a specific date for each transaction, with today's date as the default.
- **Currency Selection:** Choose your preferred currency symbol from a wide range of global currencies in the settings screen.

## Project Structure

```
lib/
|-- models/
|   `-- transaction.dart
|-- screens/
|   |-- add_transaction_screen.dart
|   |-- home_screen.dart
|   |-- onboarding_screen.dart
|   |-- settings_screen.dart
|   `-- splash_screen.dart
|-- services/
|   |-- transaction_service.dart
|   `-- settings_service.dart
|-- widgets/
|   `-- transaction_list.dart
`-- main.dart
```

## Design & Style

- **Theme:** Modern and clean design using Material 3 components.
- **Color Scheme:** Based on a modern teal (`0xFF006B5D`) seed color, with a clear distinction between income (green) and expense (red).
- **Typography:** Using a combination of `GoogleFonts.oswald`, `GoogleFonts.poppins`, and `GoogleFonts.lato` for a professional and readable text hierarchy.

## Current Task: UI/UX Enhancement and Bug Fixes

### Plan:

1.  **Refine UI/UX:** Improved the overall look and feel of the app, including the home screen balance card, summary cards, and transaction list items for a more modern and intuitive user experience.
2.  **Code Refactoring:** Restructured the code for better readability and maintainability.
3.  **Bug Fixing:** Analyzed the code, identified, and fixed several bugs related to type mismatches, deprecated code, and incorrect widget parameters.
4.  **Verification:** Ran `flutter analyze` to ensure the code is clean and free of any warnings or errors.
5.  **Update `blueprint.md`:** Document the changes in the blueprint.

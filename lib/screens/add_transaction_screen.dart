import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../services/settings_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final Transaction? transaction;

  const AddTransactionScreen({super.key, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  late double _amount;
  late DateTime _date;
  late TransactionType _type;
  late PaymentMethod _paymentMethod;
  late String _category;
  String? _customPaymentMethod;

  final List<String> _defaultMainCategories = [
    'Investment',
    'Salary',
    'Groceries',
    'Restaurant',
    'Fuel',
    'Rent',
    'Internet',
    'Electricity',
    'Pharmacy',
    'Gift',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _title = widget.transaction!.title;
      _amount = widget.transaction!.amount;
      _date = widget.transaction!.date;
      _type = widget.transaction!.type;
      _paymentMethod = widget.transaction!.paymentMethod;
      _category = widget.transaction!.category.isEmpty
          ? 'General'
          : widget.transaction!.category;
      _customPaymentMethod = widget.transaction!.customPaymentMethod;
    } else {
      _title = '';
      _amount = 0.0;
      _date = DateTime.now();
      _type = TransactionType.expense;
      _paymentMethod = PaymentMethod.cash;
      _category = 'General';
      _customPaymentMethod = null;
    }
  }

  void _submitData() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final transactionService = Provider.of<TransactionService>(
        context,
        listen: false,
      );

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        if (widget.transaction == null) {
          await transactionService.addTransaction(
            _title,
            _amount,
            _type,
            _date,
            _paymentMethod,
            _category,
            customPaymentMethod: _customPaymentMethod,
          );
        } else {
          final updatedTransaction = Transaction(
            id: widget.transaction!.id,
            title: _title,
            amount: _amount,
            date: _date,
            type: _type,
            paymentMethod: _paymentMethod,
            category: _category,
            customPaymentMethod: _customPaymentMethod,
          );
          await transactionService.updateTransaction(updatedTransaction);
        }

        // Close loading dialog
        if (mounted) Navigator.of(context).pop();

        // Close the form
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        // Close loading dialog
        if (mounted) Navigator.of(context).pop();

        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: ${transactionService.error ?? e.toString()}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _presentDatePicker() {
    showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    ).then((pickedDate) {
      if (pickedDate == null) {
        return;
      }
      setState(() {
        _date = pickedDate;
      });
    });
  }

  Future<void> _showAddNewDialog(String title, Function(String) onAdd) async {
    final controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New $title'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Enter $title name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                onAdd(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  IconData _getPaymentMethodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return Icons.money;
      case PaymentMethod.online:
        return Icons.online_prediction;
      case PaymentMethod.card:
        return Icons.credit_card;
      case PaymentMethod.bankTransfer:
        return Icons.account_balance;
      case PaymentMethod.upi:
        return Icons.phone_android;
      case PaymentMethod.other:
        return Icons.payment;
    }
  }

  String _getPaymentMethodLabel(PaymentMethod method) {
    if (method == PaymentMethod.other && _customPaymentMethod != null) {
      return _customPaymentMethod!;
    }
    switch (method) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.online:
        return 'Online';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.other:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final settingsService = Provider.of<SettingsService>(context);

    final List<String> categories = [
      ..._defaultMainCategories,
      ...settingsService.customCategories,
    ];
    final List<String> customPaymentMethods =
        settingsService.customPaymentMethods;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.transaction == null ? 'New Transaction' : 'Edit Transaction',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Transaction Type Selector
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.light
                      ? const Color(0xFFF1F4F2)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTypeButton(
                        'Expense',
                        TransactionType.expense,
                        const Color(0xFFD32F2F),
                        Icons.arrow_downward_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTypeButton(
                        'Income',
                        TransactionType.income,
                        const Color(0xFF00796B),
                        Icons.arrow_upward_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'Transaction Details',
                style: textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                initialValue: _title,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'What did you spend on?',
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                style: const TextStyle(fontWeight: FontWeight.w600),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Please enter a title.'
                    : null,
                onSaved: (value) => _title = value!,
              ),
              const SizedBox(height: 20),

              TextFormField(
                initialValue: _amount == 0.0 ? '' : _amount.toString(),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  hintText: '0.00',
                  prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
                  suffixText: settingsService.currencySymbol,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Please enter an amount.';
                  if (double.tryParse(value) == null)
                    return 'Please enter a valid number.';
                  if (double.parse(value) <= 0)
                    return 'Please enter a number greater than zero.';
                  return null;
                },
                onSaved: (value) => _amount = double.parse(value!),
              ),
              const SizedBox(height: 32),

              Text(
                'Classification & Payment',
                style: textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: categories.contains(_category) ? _category : null,
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: const Icon(Icons.category_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                items: [
                  ...categories.map(
                    (String value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  ),
                  const DropdownMenuItem(
                    value: 'ADD_NEW',
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          color: Colors.blue,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Add New Category',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (String? newValue) {
                  if (newValue == 'ADD_NEW') {
                    _showAddNewDialog('Category', (val) async {
                      await settingsService.addCustomCategory(val);
                      setState(() => _category = val);
                    });
                  } else if (newValue != null) {
                    setState(() => _category = newValue);
                  }
                },
                validator: (value) =>
                    value == null ? 'Please select a category' : null,
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<dynamic>(
                initialValue: _paymentMethod == PaymentMethod.other
                    ? _customPaymentMethod
                    : _paymentMethod,
                decoration: InputDecoration(
                  labelText: 'Payment Method',
                  prefixIcon: const Icon(Icons.payments_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                items: [
                  ...PaymentMethod.values
                      .where((m) => m != PaymentMethod.other)
                      .map((PaymentMethod method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Row(
                            children: [
                              Icon(
                                _getPaymentMethodIcon(method),
                                size: 18,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 12),
                              Text(_getPaymentMethodLabel(method)),
                            ],
                          ),
                        );
                      }),
                  ...customPaymentMethods.map(
                    (String method) => DropdownMenuItem(
                      value: method,
                      child: Row(
                        children: [
                          Icon(
                            Icons.payment_rounded,
                            size: 18,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 12),
                          Text(method),
                        ],
                      ),
                    ),
                  ),
                  const DropdownMenuItem(
                    value: 'ADD_NEW',
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          color: Colors.blue,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Add New Method',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (dynamic newValue) {
                  if (newValue == 'ADD_NEW') {
                    _showAddNewDialog('Payment Method', (val) async {
                      await settingsService.addCustomPaymentMethod(val);
                      setState(() {
                        _paymentMethod = PaymentMethod.other;
                        _customPaymentMethod = val;
                      });
                    });
                  } else if (newValue is PaymentMethod) {
                    setState(() {
                      _paymentMethod = newValue;
                      _customPaymentMethod = null;
                    });
                  } else if (newValue is String) {
                    setState(() {
                      _paymentMethod = PaymentMethod.other;
                      _customPaymentMethod = newValue;
                    });
                  }
                },
                validator: (value) =>
                    value == null ? 'Please select a payment method' : null,
              ),
              const SizedBox(height: 32),

              // Date Picker Button
              InkWell(
                onTap: _presentDatePicker,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.light
                        ? const Color(0xFFF1F4F2)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transaction Date',
                            style: textTheme.labelSmall?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.7),
                            ),
                          ),
                          Text(
                            DateFormat('EEEE, MMMM d, yyyy').format(_date),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 48),

              ElevatedButton(
                onPressed: _submitData,
                child: Text(
                  widget.transaction == null
                      ? 'Add Transaction'
                      : 'Save Changes',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(
    String label,
    TransactionType type,
    Color activeColor,
    IconData icon,
  ) {
    final isSelected = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

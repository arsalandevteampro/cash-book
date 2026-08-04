import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../services/settings_service.dart';
import '../core/constants.dart';

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

  // Removed hardcoded list, using AppConstants.defaultCategories

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

  Future<void> _showEditDialog(String title, String initialValue, Function(String) onUpdate) async {
    final controller = TextEditingController(text: initialValue);
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $title'),
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
                onUpdate(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmDialog(String title, String name, VoidCallback onDelete) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $title'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              onDelete();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
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

    final List<String> categories = {
      ...AppConstants.defaultCategories,
      ...settingsService.customCategories,
      ...Provider.of<TransactionService>(context, listen: false).transactions.map((tx) => tx.category),
    }.toList();
    final List<String> customPaymentMethods =
        settingsService.customPaymentMethods;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          widget.transaction == null ? 'New Transaction' : 'Edit Transaction',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Theme.of(context).brightness == Brightness.light 
                ? const Color(0xFF006D5B)
                : const Color(0xFF00D084),
            fontSize: 20,
          ),
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
                        const Color(0xFFFF5F5F), // Rose-red
                        Icons.arrow_downward_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTypeButton(
                        'Income',
                        TransactionType.income,
                        const Color(0xFF00D084), // Emerald
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
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'What did you spend on?',
                  prefixIcon: Icon(Icons.edit_note_rounded),
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
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
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
                isExpanded: true,
                initialValue: categories.contains(_category) ? _category : null,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_rounded),
                ),
                items: [
                  ...categories.map(
                    (String value) => DropdownMenuItem(
                      value: value,
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              value,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (settingsService.customCategories.contains(value))
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 100,
                                maxWidth: 150,
                              ),
                              onSelected: (action) {
                                if (action == 'edit') {
                                  _showEditDialog('Category', value, (newVal) async {
                                    await settingsService.updateCustomCategory(value, newVal);
                                    setState(() => _category = newVal);
                                  });
                                } else if (action == 'delete') {
                                  _showDeleteConfirmDialog('Category', value, () async {
                                    await settingsService.deleteCustomCategory(value);
                                    if (_category == value) {
                                      setState(() => _category = 'General');
                                    }
                                  });
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 18, color: Colors.orange),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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
                isExpanded: true,
                initialValue: _paymentMethod == PaymentMethod.other
                    ? _customPaymentMethod
                    : _paymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  prefixIcon: Icon(Icons.payments_rounded),
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
                          Flexible(
                            child: Text(
                              method,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 100,
                              maxWidth: 150,
                            ),
                            onSelected: (action) {
                              if (action == 'edit') {
                                _showEditDialog('Payment Method', method, (newVal) async {
                                  await settingsService.updateCustomPaymentMethod(method, newVal);
                                  setState(() {
                                    _paymentMethod = PaymentMethod.other;
                                    _customPaymentMethod = newVal;
                                  });
                                });
                              } else if (action == 'delete') {
                                _showDeleteConfirmDialog('Payment Method', method, () async {
                                  await settingsService.deleteCustomPaymentMethod(method);
                                  if (_customPaymentMethod == method) {
                                    setState(() {
                                      _paymentMethod = PaymentMethod.cash;
                                      _customPaymentMethod = null;
                                    });
                                  }
                                });
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 18, color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, size: 18, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete'),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
                        ? Colors.white
                        : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.light
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF334155),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
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
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
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
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

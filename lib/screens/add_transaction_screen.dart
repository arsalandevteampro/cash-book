import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../services/transaction_service.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _title = widget.transaction!.title;
      _amount = widget.transaction!.amount;
      _date = widget.transaction!.date;
      _type = widget.transaction!.type;
      _paymentMethod = widget.transaction!.paymentMethod;
    } else {
      _title = '';
      _amount = 0.0;
      _date = DateTime.now();
      _type = TransactionType.expense;
      _paymentMethod = PaymentMethod.cash;
    }
  }

  void _submitData() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final transactionService = Provider.of<TransactionService>(context, listen: false);
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        if (widget.transaction == null) {
          await transactionService.addTransaction(
            _title,
            _amount,
            _type, 
            _date,
            _paymentMethod,
          );
        } else {
          final updatedTransaction = Transaction(
            id: widget.transaction!.id,
            title: _title,
            amount: _amount,
            date: _date,
            type: _type,
            paymentMethod: _paymentMethod,
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
              content: Text('Error: ${transactionService.error ?? e.toString()}'),
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
        return Icons.more_horiz;
    }
  }

  String _getPaymentMethodLabel(PaymentMethod method) {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction == null ? 'Add Transaction' : 'Edit Transaction'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                initialValue: _title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title.';
                  }
                  return null;
                },
                onSaved: (value) {
                  _title = value!;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _amount == 0.0 ? '' : _amount.toString(),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(Icons.monetization_on_outlined),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount.';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number.';
                  }
                  if (double.parse(value) <= 0) {
                    return 'Please enter a number greater than zero.';
                  }
                  return null;
                },
                onSaved: (value) {
                  _amount = double.parse(value!);
                },
              ),
              const SizedBox(height: 24),
              Text('Transaction Type', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<TransactionType>(
                segments: const <ButtonSegment<TransactionType>>[
                  ButtonSegment(
                      value: TransactionType.expense,
                      label: Text('Expense'),
                      icon: Icon(Icons.arrow_downward)),
                  ButtonSegment(
                      value: TransactionType.income,
                      label: Text('Income'),
                      icon: Icon(Icons.arrow_upward)),
                ],
                selected: {_type},
                onSelectionChanged: (Set<TransactionType> newSelection) {
                  setState(() {
                    _type = newSelection.first;
                  });
                },
                style: SegmentedButton.styleFrom(
                  fixedSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 24),
              Text('Payment Method', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<PaymentMethod>(
                value: _paymentMethod,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.payment),
                  border: OutlineInputBorder(),
                ),
                items: PaymentMethod.values.map((PaymentMethod method) {
                  return DropdownMenuItem<PaymentMethod>(
                    value: method,
                    child: Row(
                      children: [
                        Icon(_getPaymentMethodIcon(method), size: 20),
                        const SizedBox(width: 8),
                        Text(_getPaymentMethodLabel(method)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (PaymentMethod? newValue) {
                  setState(() {
                    _paymentMethod = newValue!;
                  });
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Date: ${DateFormat.yMd().format(_date)}',
                      style: textTheme.bodyLarge,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Choose Date'),
                    onPressed: _presentDatePicker,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: Text(widget.transaction == null ? 'Add Transaction' : 'Save Changes'),
                onPressed: _submitData,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

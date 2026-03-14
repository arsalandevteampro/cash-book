import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/goals_service.dart';
import '../services/settings_service.dart';

class GoalsFormScreen extends StatefulWidget {
  const GoalsFormScreen({super.key});

  @override
  State<GoalsFormScreen> createState() => _GoalsFormScreenState();
}

class _GoalsFormScreenState extends State<GoalsFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _incomeController = TextEditingController();
  final _expenseController = TextEditingController();
  final _savingsController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentGoals();
  }

  void _loadCurrentGoals() {
    final goalsService = Provider.of<GoalsService>(context, listen: false);
    final goals = goalsService.goals;
    
    _incomeController.text = goals.monthlyIncomeTarget.toStringAsFixed(0);
    _expenseController.text = goals.monthlyExpenseLimit.toStringAsFixed(0);
    _savingsController.text = goals.savingsTarget.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _incomeController.dispose();
    _expenseController.dispose();
    _savingsController.dispose();
    super.dispose();
  }

  Future<void> _saveGoals() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final goalsService = Provider.of<GoalsService>(context, listen: false);
      
      await goalsService.updateGoals(
        monthlyIncomeTarget: double.parse(_incomeController.text),
        monthlyExpenseLimit: double.parse(_expenseController.text),
        savingsTarget: double.parse(_savingsController.text),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Financial goals updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating goals: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context);
    final currencySymbol = settingsService.currencySymbol;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Financial Goals'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set Your Financial Targets',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Define your monthly income target, expense limit, and savings goal to track your financial progress.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Monthly Income Target
              _buildGoalCard(
                title: 'Monthly Income Target',
                icon: Icons.trending_up,
                color: Colors.green,
                controller: _incomeController,
                currencySymbol: currencySymbol,
                description: 'Set your target monthly income',
              ),
              
              const SizedBox(height: 16),
              
              // Monthly Expense Limit
              _buildGoalCard(
                title: 'Monthly Expense Limit',
                icon: Icons.trending_down,
                color: Colors.red,
                controller: _expenseController,
                currencySymbol: currencySymbol,
                description: 'Set your maximum monthly spending limit',
              ),
              
              const SizedBox(height: 16),
              
              // Savings Target
              _buildGoalCard(
                title: 'Monthly Savings Target',
                icon: Icons.account_balance_wallet,
                color: Colors.blue,
                controller: _savingsController,
                currencySymbol: currencySymbol,
                description: 'Set your target monthly savings amount',
              ),
              
              const SizedBox(height: 32),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveGoals,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save Goals',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalCard({
    required String title,
    required IconData icon,
    required Color color,
    required TextEditingController controller,
    required String currencySymbol,
    required String description,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '$currencySymbol ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: color, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}

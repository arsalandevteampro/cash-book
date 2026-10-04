import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/follow_up.dart';
import '../services/follow_up_service.dart';
import '../services/settings_service.dart';
import '../services/transaction_service.dart';
import '../services/connectivity_helper.dart';
import '../ads/follow_up_interstitial_ad_manager.dart';

class AddFollowUpScreen extends StatefulWidget {
  final FollowUp? followUpToEdit;
  final FollowUp? copyFrom;

  const AddFollowUpScreen({
    super.key,
    this.followUpToEdit,
    this.copyFrom,
  });

  @override
  State<AddFollowUpScreen> createState() => _AddFollowUpScreenState();
}

class _AddFollowUpScreenState extends State<AddFollowUpScreen> {
  final _formKey = GlobalKey<FormState>();

  late FollowUpType _type;
  late TextEditingController _nameController;
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _phoneController;
  late TextEditingController _noteController;

  late DateTime _dueDate;
  late TimeOfDay _dueTime;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Preload Follow-up Interstitial Ad while user fills the form
    FollowUpInterstitialAdManager.instance.preloadAd();

    final item = widget.followUpToEdit ?? widget.copyFrom;

    _type = item?.type ?? FollowUpType.toReceive;
    _nameController = TextEditingController(text: item?.contactName ?? '');
    _titleController = TextEditingController(text: item?.title ?? '');
    _amountController = TextEditingController(
      text: item != null ? item.amount.toStringAsFixed(0) : '',
    );
    _phoneController = TextEditingController(text: item?.phoneNumber ?? '');
    _noteController = TextEditingController(text: item?.note ?? '');

    final initialDate = widget.copyFrom != null
        ? DateTime.now().add(const Duration(hours: 1))
        : (item?.dueDate ?? DateTime.now().add(const Duration(hours: 1)));
    _dueDate = DateTime(initialDate.year, initialDate.month, initialDate.day);
    _dueTime = TimeOfDay(hour: initialDate.hour, minute: initialDate.minute);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _amountController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate.isBefore(now) ? now : _dueDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF006D5B),
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF006D5B),
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dueTime = picked);
    }
  }

  void _setQuickDate(int daysFromNow) {
    final now = DateTime.now();
    final target = now.add(Duration(days: daysFromNow));
    setState(() {
      _dueDate = DateTime(target.year, target.month, target.day);
    });
  }

  void _addQuickAmount(double amountToAdd) {
    final current = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final total = current + amountToAdd;
    setState(() {
      _amountController.text = total.toStringAsFixed(0);
    });
  }

  Future<void> _saveFollowUp() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount greater than 0.')),
      );
      return;
    }

    final followUpService = context.read<FollowUpService>();
    setState(() => _isSaving = true);

    // Verify active internet connection (required specifically for follow-ups create/edit)
    final hasInternet = await ConnectivityHelper.hasInternetConnection();
    if (!mounted) return;
    if (!hasInternet) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Internet connection is required to create or edit follow-ups.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFFD32F2F),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final finalDateTime = DateTime(
      _dueDate.year,
      _dueDate.month,
      _dueDate.day,
      _dueTime.hour,
      _dueTime.minute,
    );

    try {
      final defaultTitle = _type == FollowUpType.toReceive ? 'Payment Due' : 'Bill/Payment';
      final cleanTitle = _titleController.text.trim().isEmpty ? defaultTitle : _titleController.text.trim();
      final cleanPhone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();
      final cleanNote = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();

      if (widget.followUpToEdit != null) {
        final updated = widget.followUpToEdit!.copyWith(
          title: cleanTitle,
          contactName: _nameController.text.trim(),
          phoneNumber: cleanPhone,
          amount: amount,
          dueDate: finalDateTime,
          type: _type,
          note: cleanNote,
        );
        await followUpService.updateFollowUp(updated);
      } else {
        await followUpService.addFollowUp(
          title: cleanTitle,
          contactName: _nameController.text.trim(),
          phoneNumber: cleanPhone,
          amount: amount,
          dueDate: finalDateTime,
          type: _type,
          note: cleanNote,
        );
      }

      if (mounted) {
        // Show Follow-up Interstitial Ad then return to list
        await FollowUpInterstitialAdManager.instance.showAdThen(
          onComplete: () {
            if (mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    widget.followUpToEdit != null
                        ? 'Follow-up updated successfully!'
                        : (widget.copyFrom != null
                            ? 'Follow-up copied & scheduled as new!'
                            : 'Follow-up scheduled with notification reminder!'),
                  ),
                  backgroundColor: const Color(0xFF006D5B),
                ),
              );
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save follow-up: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencySymbol = context.watch<SettingsService>().currencySymbol;
    final recentPartyNames = context.watch<TransactionService>().recentTitles;

    final isToReceive = _type == FollowUpType.toReceive;
    final primaryColor = isToReceive ? const Color(0xFF006D5B) : const Color(0xFFFF5F5F);
    final accentColor = isToReceive ? const Color(0xFF00D084) : const Color(0xFFFF5F5F);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.followUpToEdit != null
              ? 'Edit Follow-up'
              : (widget.copyFrom != null ? 'Copy Follow-up' : 'Add Follow-up'),
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Type Toggle Selector (Lena Hai vs Dena Hai)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _type = FollowUpType.toReceive),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: isToReceive ? const Color(0xFF006D5B) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isToReceive
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF006D5B).withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.arrow_downward_rounded,
                                size: 17,
                                color: isToReceive ? Colors.white : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'To Receive',
                                style: TextStyle(
                                  color: isToReceive ? Colors.white : Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _type = FollowUpType.toPay),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: !isToReceive ? const Color(0xFFFF5F5F) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: !isToReceive
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFF5F5F).withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.arrow_upward_rounded,
                                size: 17,
                                color: !isToReceive ? Colors.white : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'To Pay',
                                style: TextStyle(
                                  color: !isToReceive ? Colors.white : Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 2. Amount Input Card
              Text('Amount ($currencySymbol) *', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Text(
                      currencySymbol,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter the amount';
                  }
                  final num = double.tryParse(val.trim());
                  if (num == null || num <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),

              // Quick Amount Chips
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildAmountChip('+500', 500),
                    const SizedBox(width: 8),
                    _buildAmountChip('+1,000', 1000),
                    const SizedBox(width: 8),
                    _buildAmountChip('+2,000', 2000),
                    const SizedBox(width: 8),
                    _buildAmountChip('+5,000', 5000),
                    const SizedBox(width: 8),
                    _buildAmountChip('+10,000', 10000),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 3. Person / Party Name with Auto-suggestions
              Text('Person / Party Name *', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              RawAutocomplete<String>(
                textEditingController: _nameController,
                focusNode: FocusNode(),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return recentPartyNames.where((String option) {
                    return option
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase());
                  });
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'e.g. Ali Raza, Supplier, Electric Dept',
                      prefixIcon: Icon(Icons.person_rounded, color: primaryColor),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                        ),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter a contact/person name';
                      }
                      return null;
                    },
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      borderRadius: BorderRadius.circular(12),
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              leading: const Icon(Icons.history_rounded, size: 18),
                              title: Text(option),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 18),

              // 4. Due Date & Time Section
              Text('Due Date & Time (Reminder Alarm) *', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),

              // Quick Date Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickChip('Today', 0),
                    const SizedBox(width: 8),
                    _buildQuickChip('Tomorrow', 1),
                    const SizedBox(width: 8),
                    _buildQuickChip('In 3 Days', 3),
                    const SizedBox(width: 8),
                    _buildQuickChip('Next Week', 7),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, color: primaryColor, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                DateFormat('dd MMM yyyy').format(_dueDate),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: _pickTime,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time_rounded, color: primaryColor, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _dueTime.format(context),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 5. Phone Number Field (For WhatsApp & Call)
              Text('Phone Number (Optional)', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Used for 1-Tap WhatsApp & Call reminders',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '03001234567',
                  prefixIcon: Icon(Icons.phone_rounded, color: primaryColor),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 6. Title / Purpose Field
              Text('Purpose / Remarks (Optional)', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: isToReceive
                      ? 'e.g. Laptop payment balance, Pending invoice'
                      : 'e.g. Shop rent, Goods supply, Bill payment',
                  prefixIcon: Icon(Icons.label_outline_rounded, color: primaryColor),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 7. Extra Note
              Text('Extra Notes (Optional)', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Any specific conditions or notes...',
                  prefixIcon: Icon(Icons.notes_rounded, color: primaryColor),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Sticky Bottom Action Button with SafeArea protection
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveFollowUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006D5B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 3,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.followUpToEdit != null
                              ? Icons.check_rounded
                              : Icons.notifications_active_rounded,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.followUpToEdit != null
                              ? 'Update Follow-up'
                              : 'Schedule Follow-up',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, int days) {
    final now = DateTime.now();
    final target = now.add(Duration(days: days));
    final isSelected = _dueDate.year == target.year &&
        _dueDate.month == target.month &&
        _dueDate.day == target.day;

    return ActionChip(
      label: Text(label),
      onPressed: () => _setQuickDate(days),
      backgroundColor: isSelected
          ? const Color(0xFF006D5B).withValues(alpha: 0.15)
          : Theme.of(context).cardColor,
      side: BorderSide(
        color: isSelected ? const Color(0xFF006D5B) : Colors.grey.shade300,
      ),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF006D5B) : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
    );
  }

  Widget _buildAmountChip(String label, double amount) {
    return ActionChip(
      label: Text(label),
      onPressed: () => _addQuickAmount(amount),
      backgroundColor: Theme.of(context).cardColor,
      side: BorderSide(color: Colors.grey.shade300),
      labelStyle: TextStyle(
        color: Colors.grey.shade700,
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
    );
  }
}

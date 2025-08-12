import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/accounting_models.dart';
import '../models/vat_models.dart';
import '../services/database_service.dart';
import '../services/vat_service.dart';
import '../context/simple_company_context.dart';
import '../utils/currency_utils.dart';
import '../widgets/gross_vat_calculator_widget.dart';

class EditInvoiceDialog extends StatefulWidget {
  final Invoice invoice;

  const EditInvoiceDialog({super.key, required this.invoice});

  @override
  State<EditInvoiceDialog> createState() => _EditInvoiceDialogState();
}

class _EditInvoiceDialogState extends State<EditInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _invoiceNumberController;
  late final TextEditingController _clientNameController;
  late final TextEditingController _grossAmountController;
  late final TextEditingController _netAmountController;
  late final TextEditingController _descriptionController;

  late DateTime _selectedDate;
  bool _isUpdating = false;
  String _selectedStatus = 'pending'; // Add status field

  // VAT-related fields
  VATRate? _selectedVATRate;
  VATCalculation? _vatCalculation;
  List<VATRate> _vatRates = [];
  bool _isLoadingVATRates = true;

  @override
  void initState() {
    super.initState();
    print('🧾 [EditInvoiceDialog] === INITIALIZING EDIT DIALOG ===');
    print('🧾 [EditInvoiceDialog] Received invoice data:');
    print('🧾 [EditInvoiceDialog] - ID: ${widget.invoice.id}');
    print(
        '🧾 [EditInvoiceDialog] - Invoice Number: ${widget.invoice.invoiceNumber}');
    print('🧾 [EditInvoiceDialog] - Client: ${widget.invoice.clientName}');
    print('🧾 [EditInvoiceDialog] - Amount: ${widget.invoice.amount}');
    print(
        '🧾 [EditInvoiceDialog] - Description: ${widget.invoice.description}');
    print('🧾 [EditInvoiceDialog] - Date: ${widget.invoice.date}');
    print('🧾 [EditInvoiceDialog] - Due Date: ${widget.invoice.dueDate}');
    print('🧾 [EditInvoiceDialog] - Status: ${widget.invoice.status}');
    print('🧾 [EditInvoiceDialog] - Created At: ${widget.invoice.createdAt}');
    print('🧾 [EditInvoiceDialog] - VAT Rate ID: ${widget.invoice.vatRateId}');
    print('🧾 [EditInvoiceDialog] - Net Amount: ${widget.invoice.netAmount}');
    print('🧾 [EditInvoiceDialog] - VAT Amount: ${widget.invoice.vatAmount}');
    print(
        '🧾 [EditInvoiceDialog] - Gross Amount: ${widget.invoice.grossAmount}');

    _initializeCompanyContext();
    _loadVATRates();
    _initializeControllers();

    print('🧾 [EditInvoiceDialog] === EDIT DIALOG INITIALIZED ===');
  }

  Future<void> _loadVATRates() async {
    try {
      final rates =
          await VATService.getVATRates(country: 'Ireland', activeOnly: true);
      setState(() {
        _vatRates = rates;
        _isLoadingVATRates = false;

        // Load the actual VAT rate from the invoice data
        if (widget.invoice.vatRateId != null) {
          print(
              '🧾 [EditInvoiceDialog] Looking for VAT rate ID: ${widget.invoice.vatRateId}');
          print('🧾 [EditInvoiceDialog] Available VAT rates:');
          for (var rate in rates) {
            print(
                '🧾 [EditInvoiceDialog] - ID: ${rate.id}, Name: ${rate.rateName}, Rate: ${rate.ratePercentage}%');
          }

          _selectedVATRate = rates.firstWhere(
            (rate) => rate.id == widget.invoice.vatRateId,
            orElse: () {
              print(
                  '🧾 [EditInvoiceDialog] ❌ VAT rate ID ${widget.invoice.vatRateId} not found in available rates!');
              return rates.isNotEmpty ? rates.first : rates.first;
            },
          );
          print(
              '🧾 [EditInvoiceDialog] ✅ Loaded VAT rate from invoice: ${_selectedVATRate?.rateName} (${_selectedVATRate?.ratePercentage}%) - ID: ${widget.invoice.vatRateId}');
        } else {
          // If no VAT rate in invoice, don't select any (let user choose)
          _selectedVATRate = null;
          print(
              '🧾 [EditInvoiceDialog] No VAT rate in invoice data, user must select one');
        }
      });

      // Trigger initial VAT calculation after rates are loaded
      if (_selectedVATRate != null) {
        _triggerVATCalculation();
        // Force immediate calculation to ensure VAT breakdown shows
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedVATRate != null) {
            _triggerVATCalculation();
          }
        });
      }

      // Initialize VAT calculation from existing invoice data if available
      if (widget.invoice.netAmount != null &&
          widget.invoice.vatAmount != null &&
          widget.invoice.grossAmount != null) {
        _vatCalculation = VATCalculation(
          grossAmount: widget.invoice.grossAmount!,
          netAmount: widget.invoice.netAmount!,
          vatAmount: widget.invoice.vatAmount!,
          vatRatePercentage: _selectedVATRate?.ratePercentage ?? 0.0,
          businessUsagePercentage: 100.0,
        );
        print(
            '🧾 [EditInvoiceDialog] Initialized VAT calculation from existing data: gross=€${widget.invoice.grossAmount}, net=€${widget.invoice.netAmount}, vat=€${widget.invoice.vatAmount}');
      }
    } catch (e) {
      setState(() => _isLoadingVATRates = false);
      print('Error loading VAT rates: $e');
    }
  }

  void _initializeControllers() {
    _invoiceNumberController =
        TextEditingController(text: widget.invoice.invoiceNumber);
    _clientNameController =
        TextEditingController(text: widget.invoice.clientName);
    // Use grossAmount if available, otherwise use the legacy amount field
    _grossAmountController = TextEditingController(
        text: (widget.invoice.grossAmount ?? widget.invoice.amount).toString());
    // Initialize net amount from existing invoice data
    _netAmountController = TextEditingController(
        text: (widget.invoice.netAmount ?? widget.invoice.amount).toString());
    _descriptionController =
        TextEditingController(text: widget.invoice.description);
    _selectedDate = widget.invoice.dueDate;

    // Initialize status with validation to ensure it matches dropdown options
    final validStatuses = ['draft', 'pending', 'paid', 'overdue', 'cancelled'];
    _selectedStatus = validStatuses.contains(widget.invoice.status)
        ? widget.invoice.status
        : 'pending'; // Default to pending if status is invalid

    print(
        '🧾 [EditInvoiceDialog] Status initialized: ${widget.invoice.status} -> $_selectedStatus');
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _grossAmountController.dispose();
    _netAmountController.dispose();
    _descriptionController.dispose();
    _clientNameController.dispose();
    super.dispose();
  }

  void _initializeCompanyContext() {
    print('🔍 [DEBUG] === COMPANY CONTEXT INITIALIZATION (EDIT INVOICE) ===');

    final selectedCompany = SimpleCompanyContext.selectedCompany;
    print('🔍 [DEBUG] SimpleCompanyContext.selectedCompany: $selectedCompany');
    print(
        '🔍 [DEBUG] SimpleCompanyContext.hasSelectedCompany: ${SimpleCompanyContext.hasSelectedCompany}');

    if (selectedCompany != null) {
      print(
          '🔍 [DEBUG] Company found - ID: ${selectedCompany.id}, Name: ${selectedCompany.name}, Demo: ${selectedCompany.isDemo}');

      final dbService = DatabaseService();
      dbService.setCompanyContext(
        selectedCompany.id.toString(),
        isDemoMode: selectedCompany.isDemo,
      );

      print('🔍 [DEBUG] DatabaseService context after setting:');
      print('🔍 [DEBUG] - currentCompanyId: ${dbService.currentCompanyId}');
      print('🔍 [DEBUG] - hasCompanyContext: ${dbService.hasCompanyContext}');
      print('🔍 [DEBUG] - isDemoMode: ${dbService.isDemoMode}');

      print('✅ [DEBUG] Company context successfully set!');
    } else {
      print('❌ [DEBUG] No company found in SimpleCompanyContext!');
    }

    print(
        '🔍 [DEBUG] === END COMPANY CONTEXT INITIALIZATION (EDIT INVOICE) ===');
  }

  String _getCurrencySymbol() {
    final selectedCompany = SimpleCompanyContext.selectedCompany;
    if (selectedCompany?.currency != null) {
      return CurrencyUtils.getCurrencySymbol(selectedCompany!.currency!);
    }
    return '\$'; // Default fallback
  }

  void _onVATCalculationChanged(VATCalculation? calculation) {
    setState(() {
      _vatCalculation = calculation;
      // Update net amount field when VAT calculation changes
      if (calculation != null) {
        _netAmountController.text = calculation.netAmount.toStringAsFixed(2);
      } else {
        _netAmountController.clear();
      }
    });
  }

  void _triggerVATCalculation() {
    // This will cause the GrossVATCalculatorWidget to recalculate
    // when grossAmount and selectedVATRate are both available
    final grossAmount = _getGrossAmount();
    if (grossAmount != null && _selectedVATRate != null) {
      print(
          '🧾 [EditInvoiceDialog] Triggering VAT calculation: gross=€$grossAmount, rate=${_selectedVATRate?.ratePercentage}%');
      print(
          '🧾 [EditInvoiceDialog] VAT Rate Details: ${_selectedVATRate?.rateName} (ID: ${_selectedVATRate?.id})');
      // The calculation will be triggered automatically by the widget
      // when it receives the updated grossAmount and selectedVATRate
    } else {
      print(
          '🧾 [EditInvoiceDialog] Cannot trigger VAT calculation: grossAmount=$grossAmount, vatRate=$_selectedVATRate');
    }
  }

  double? _getGrossAmount() {
    final text = _grossAmountController.text.trim();
    return text.isEmpty ? null : double.tryParse(text);
  }

  Future<void> _updateInvoice() async {
    if (!_formKey.currentState!.validate() || _isUpdating) {
      print('❌ [EditInvoiceDialog] Form validation failed or already updating');
      return;
    }

    // Additional validation for VAT rate
    if (_selectedVATRate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a VAT rate'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    print('🧾 [EditInvoiceDialog] === STARTING INVOICE UPDATE ===');
    print('🧾 [EditInvoiceDialog] Form values:');
    print('🧾 [EditInvoiceDialog] - Invoice ID: ${widget.invoice.id}');
    print(
        '🧾 [EditInvoiceDialog] - Invoice Number: ${_invoiceNumberController.text}');
    print(
        '🧾 [EditInvoiceDialog] - Client Name: ${_clientNameController.text}');
    print(
        '🧾 [EditInvoiceDialog] - Gross Amount: ${_grossAmountController.text}');
    print(
        '🧾 [EditInvoiceDialog] - Description: ${_descriptionController.text}');
    print('🧾 [EditInvoiceDialog] - Due Date: $_selectedDate');

    final dbService = DatabaseService();
    final preCheckCompany = SimpleCompanyContext.selectedCompany;

    print('🧾 [EditInvoiceDialog] Company context check:');
    print('🧾 [EditInvoiceDialog] - preCheckCompany: $preCheckCompany');
    print(
        '🧾 [EditInvoiceDialog] - dbService.hasCompanyContext: ${dbService.hasCompanyContext}');
    print(
        '🧾 [EditInvoiceDialog] - dbService.currentCompanyId: ${dbService.currentCompanyId}');

    if (preCheckCompany == null || !dbService.hasCompanyContext) {
      print(
          '🧾 [EditInvoiceDialog] Company context missing, attempting to set...');
      final selectedCompany = SimpleCompanyContext.selectedCompany;
      if (selectedCompany != null) {
        print(
            '🧾 [EditInvoiceDialog] Setting company context: ID=${selectedCompany.id}, Demo=${selectedCompany.isDemo}');
        dbService.setCompanyContext(
          selectedCompany.id.toString(),
          isDemoMode: selectedCompany.isDemo,
        );
        print(
            '🧾 [EditInvoiceDialog] Context set - hasContext: ${dbService.hasCompanyContext}');
      } else {
        print(
            '❌ [EditInvoiceDialog] No company available, showing error dialog');
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Company Context Error'),
              content: const Text(
                  'No company context set. Please select a company first.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close error dialog
                    Navigator.of(context).pop(); // Close edit dialog
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        setState(() {
          _isUpdating = false;
        });
        return;
      }
    } else {
      print('✅ [EditInvoiceDialog] Company context already set properly');
    }

    try {
      print('🧾 [EditInvoiceDialog] Creating updated invoice object...');
      print(
          '🧾 [EditInvoiceDialog] Original invoice date: ${widget.invoice.date}');
      print(
          '🧾 [EditInvoiceDialog] Original invoice createdAt: ${widget.invoice.createdAt}');

      // Validate gross amount before parsing
      final grossAmountText = _grossAmountController.text.trim();
      final parsedGrossAmount = double.tryParse(grossAmountText);
      if (parsedGrossAmount == null) {
        throw Exception('Invalid gross amount format: "$grossAmountText"');
      }

      // Calculate net amount from VAT calculation or fallback to gross amount
      final netAmount = _vatCalculation?.netAmount ?? parsedGrossAmount;

      // Ensure date is never null - use createdAt as fallback
      final invoiceDate = widget.invoice.date ?? widget.invoice.createdAt;
      print('🧾 [EditInvoiceDialog] Using invoice date: $invoiceDate');

      final updatedInvoice = Invoice(
        id: widget.invoice.id,
        invoiceNumber: _invoiceNumberController.text.trim(),
        clientName: _clientNameController.text.trim(),
        amount: parsedGrossAmount, // Use gross amount for legacy compatibility
        description: _descriptionController.text.trim(),
        date: invoiceDate, // Ensure date is never null
        dueDate: _selectedDate,
        status: _selectedStatus, // Use selected status
        createdAt: widget.invoice.createdAt, // Keep original creation date
        // VAT fields
        vatRateId: _selectedVATRate?.id,
        netAmount: _vatCalculation?.netAmount ?? netAmount,
        vatAmount: _vatCalculation?.vatAmount,
        grossAmount: _vatCalculation?.grossAmount ?? parsedGrossAmount,
      );

      print('🧾 [EditInvoiceDialog] Updated invoice object created:');
      print('🧾 [EditInvoiceDialog] - ID: ${updatedInvoice.id}');
      print(
          '🧾 [EditInvoiceDialog] - Invoice Number: ${updatedInvoice.invoiceNumber}');
      print('🧾 [EditInvoiceDialog] - Client: ${updatedInvoice.clientName}');
      print('🧾 [EditInvoiceDialog] - Amount: ${updatedInvoice.amount}');
      print('🧾 [EditInvoiceDialog] - Date: ${updatedInvoice.date}');
      print('🧾 [EditInvoiceDialog] - Due Date: ${updatedInvoice.dueDate}');
      print('🧾 [EditInvoiceDialog] - Status: ${updatedInvoice.status}');

      print('🧾 [EditInvoiceDialog] Calling updateInvoice...');
      await dbService.updateInvoice(updatedInvoice);

      print('✅ [EditInvoiceDialog] Invoice update completed successfully');

      if (mounted) {
        setState(() {
          _isUpdating = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        print(
            '🧾 [EditInvoiceDialog] Closing dialog and returning updated invoice');
        // Small delay to let the snackbar show
        await Future.delayed(const Duration(milliseconds: 300));
        Navigator.of(context).pop(updatedInvoice); // Return the updated invoice
      }
    } catch (e) {
      print('❌ [EditInvoiceDialog] Error in _updateInvoice: $e');
      print('❌ [EditInvoiceDialog] Error type: ${e.runtimeType}');
      print('❌ [EditInvoiceDialog] Stack trace: ${StackTrace.current}');

      if (mounted) {
        setState(() {
          _isUpdating = false;
        });

        await Future.delayed(const Duration(milliseconds: 100));

        if (mounted) {
          print('🧾 [EditInvoiceDialog] Showing error dialog to user');
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Invoice Update Error'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Failed to update invoice:'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      e.toString(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close error dialog
                    Navigator.of(context).pop(); // Close edit dialog
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: MediaQuery.of(context).size.width * 0.95,
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 12),
                  const Text(
                    'Edit Invoice',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // Invoice Number Field
                      TextFormField(
                        controller: _invoiceNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Invoice Number',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an invoice number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Client Name Field
                      TextFormField(
                        controller: _clientNameController,
                        decoration: const InputDecoration(
                          labelText: 'Client Name',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a client name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      // Amount and VAT Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Amount & VAT Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Responsive Layout for Amount and VAT
                            MediaQuery.of(context).size.width < 500
                                ? Column(
                                    children: [
                                      TextFormField(
                                        controller: _grossAmountController,
                                        decoration: InputDecoration(
                                          labelText: 'Gross Amount (inc VAT)',
                                          border: const OutlineInputBorder(),
                                          prefixText: _getCurrencySymbol(),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 16),
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                              RegExp(r'^\d*\.?\d{0,2}')),
                                        ],
                                        onChanged: (_) => setState(() {}),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter an amount';
                                          }
                                          if (double.tryParse(value) == null) {
                                            return 'Please enter a valid amount';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      _isLoadingVATRates
                                          ? const Center(
                                              child:
                                                  CircularProgressIndicator())
                                          : DropdownButtonFormField<VATRate>(
                                              value: _selectedVATRate,
                                              decoration: const InputDecoration(
                                                labelText: 'VAT Rate',
                                                border: OutlineInputBorder(),
                                                prefixIcon: Icon(Icons.percent),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 16),
                                                filled: true,
                                                fillColor: Colors.white,
                                              ),
                                              items: _vatRates
                                                  .map((rate) =>
                                                      DropdownMenuItem(
                                                        value: rate,
                                                        child: Text(
                                                            '${rate.rateName} (${rate.ratePercentage}%)'),
                                                      ))
                                                  .toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  _selectedVATRate = value;
                                                });
                                              },
                                              validator: (value) {
                                                if (value == null) {
                                                  return 'Please select a VAT rate';
                                                }
                                                return null;
                                              },
                                            ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _grossAmountController,
                                          decoration: InputDecoration(
                                            labelText: 'Gross Amount (inc VAT)',
                                            border: const OutlineInputBorder(),
                                            prefixText: _getCurrencySymbol(),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 16),
                                            filled: true,
                                            fillColor: Colors.white,
                                          ),
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(
                                                RegExp(r'^\d*\.?\d{0,2}')),
                                          ],
                                          onChanged: (_) => setState(() {}),
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Please enter an amount';
                                            }
                                            if (double.tryParse(value) ==
                                                null) {
                                              return 'Please enter a valid amount';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: _isLoadingVATRates
                                            ? const Center(
                                                child:
                                                    CircularProgressIndicator())
                                            : DropdownButtonFormField<VATRate>(
                                                value: _selectedVATRate,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'VAT Rate',
                                                  border: OutlineInputBorder(),
                                                  prefixIcon:
                                                      Icon(Icons.percent),
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                          horizontal: 11,
                                                          vertical: 16),
                                                  filled: true,
                                                  fillColor: Colors.white,
                                                ),
                                                items: _vatRates
                                                    .map((rate) =>
                                                        DropdownMenuItem(
                                                          value: rate,
                                                          child: Text(
                                                              '${rate.rateName} (${rate.ratePercentage}%)'),
                                                        ))
                                                    .toList(),
                                                onChanged: (value) {
                                                  setState(() {
                                                    _selectedVATRate = value;
                                                  });
                                                },
                                                validator: (value) {
                                                  if (value == null) {
                                                    return 'Please select a VAT rate';
                                                  }
                                                  return null;
                                                },
                                              ),
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Net Amount Field (Read-only, calculated from VAT)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextFormField(
                          controller: _netAmountController,
                          decoration: InputDecoration(
                            labelText: 'Net Amount (ex VAT)',
                            border: const OutlineInputBorder(),
                            prefixText: _getCurrencySymbol(),
                            helperText:
                                'Calculated automatically from gross amount',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          readOnly: true,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // VAT Calculator Widget
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: GrossVATCalculatorWidget(
                          grossAmount: _getGrossAmount(),
                          selectedVATRate: _selectedVATRate,
                          businessUsagePercentage:
                              100.0, // Invoices are always 100% business
                          onCalculationChanged: _onVATCalculationChanged,
                          isLoading: _isLoadingVATRates,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Description Section
                      const Text(
                        'Description & Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'Enter invoice description...',
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Status and Date Section
                      const Text(
                        'Status & Timeline',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.flag_outlined),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: 'draft',
                            child: Text('Draft'),
                          ),
                          const DropdownMenuItem<String>(
                            value: 'pending',
                            child: Text('Pending'),
                          ),
                          const DropdownMenuItem<String>(
                            value: 'paid',
                            child: Text('Paid'),
                          ),
                          const DropdownMenuItem<String>(
                            value: 'overdue',
                            child: Text('Overdue'),
                          ),
                          const DropdownMenuItem<String>(
                            value: 'cancelled',
                            child: Text('Cancelled'),
                          ),
                        ],
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedStatus = newValue;
                            });
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a status';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Due Date Selector
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Color(0xFF6B7280),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Due Date: ${_selectedDate.toLocal().toString().split(' ')[0]}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            ElevatedButton(
                              onPressed: _selectDate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B82F6),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                minimumSize: const Size(50, 28),
                              ),
                              child: const Text(
                                'Edit',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),

            // Footer with buttons
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      foregroundColor: const Color(0xFF6B7280),
                    ),
                    child: const Text(
                      'Cancel',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isUpdating ? null : _updateInvoice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isUpdating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Update Invoice',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

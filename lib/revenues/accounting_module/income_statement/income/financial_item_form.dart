import 'package:flutter/material.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'package:zitf_system/revenues/accounting_module/income_statement/income/financial_item_entry_form.dart';
import 'package:zitf_system/revenues/accounting_module/income_statement/income/financial_statements_display.dart';

class FinancialHome extends StatefulWidget {
  const FinancialHome({super.key});

  @override
  _FinancialHomeState createState() => _FinancialHomeState();
}

class _FinancialHomeState extends State<FinancialHome> {
  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => const FinancialStatementsDisplay()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Income Statement'),
      body: FinancialItemEntryForm(
        navigateToHistory: _navigateToHistory,
        initialData: {}, // Pass empty data for initial entry (no pre-fill)
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/syncConfigs/syncConfig.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class DomainConfigScreen extends StatefulWidget {
  const DomainConfigScreen({Key? key}) : super(key: key);

  @override
  _DomainConfigScreenState createState() => _DomainConfigScreenState();
}

class _DomainConfigScreenState extends State<DomainConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _domainNameController = TextEditingController();
  bool _areDomainsActive = false;

  @override
  void initState() {
    super.initState();
    _loadExistingConfig();
  }

  Future<void> _loadExistingConfig() async {
    final box = await Hive.openBox<DomainRecord>('domainBox');
    if (box.isNotEmpty) {
      // Assuming there's only one config record.
      final record = box.getAt(0);
      if (record != null) {
        _domainNameController.text = record.domainName ?? "";
        _areDomainsActive = record.areDomainsActive ?? false;
        setState(() {});
      }
    }
  }

  Future<void> _saveConfig() async {
    if (_formKey.currentState!.validate()) {
      List<String> modifiedFields = [];
      modifiedFields.add('id');
      modifiedFields.add('className');
      modifiedFields.add('classCode');
      modifiedFields.add('date');
      modifiedFields.add('termId');
      modifiedFields.add('terms');
      final box = await Hive.openBox<DomainRecord>('domainBox');
      final newRecord = DomainRecord(
        domainName: _domainNameController.text,
        areDomainsActive: _areDomainsActive,
        syncStatus: false, // Set as needed
        operationType: "update", // Or "create" based on your logic
        lastModified: DateTime.now(),
        modifiedFields: modifiedFields,
      );
      // Either add a new record or update the existing one.
      if (box.isEmpty) {
        await box.add(newRecord);
      } else {
        await box.putAt(0, newRecord);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Domain configuration saved.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CenteredFormContainer(
      title: 'Domain Configs',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _domainNameController,
              decoration: const InputDecoration(labelText: "Domain Name"),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please enter a domain name";
                }
                return null;
              },
            ),
            SwitchListTile(
              title: const Text("Are Domains Active?"),
              value: _areDomainsActive,
              onChanged: (value) {
                setState(() {
                  _areDomainsActive = value;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveConfig,
              child: const Text("Save Configuration"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _domainNameController.dispose();
    super.dispose();
  }
}

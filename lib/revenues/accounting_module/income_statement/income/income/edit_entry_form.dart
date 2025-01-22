import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For clipboard copying
import 'package:hive/hive.dart';

class EditEntryForm extends StatefulWidget {
  final List<Map<String, dynamic>> entry;

  const EditEntryForm({super.key, required this.entry});

  @override
  _EditEntryFormState createState() => _EditEntryFormState();
}

class _EditEntryFormState extends State<EditEntryForm> {
  final _financialBox = Hive.box('financial_box');
  List<Map<String, dynamic>> _entry = [];

  @override
  void initState() {
    super.initState();
    _entry = List.from(
        widget.entry); // Make a local copy of the entry data for editing
  }

  void _deleteEntry() {
    int entryIndex = _financialBox.values.toList().indexOf(widget.entry);
    if (entryIndex != -1) {
      _financialBox.deleteAt(entryIndex);
      Navigator.pop(context); // Go back to the previous screen
    }
  }

  void _printEntry() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Print Statement'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Statement of Income and Expenditure:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ..._entry.map((item) {
                  return Text(
                      'Description: ${item['description']}, Amount: \$${item['amount']}');
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Close dialog
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _shareEntry() {
    String content = 'Statement of Income and Expenditure\n';
    for (var item in _entry) {
      content +=
          'Description: ${item['description']}\nAmount: ${item['amount']}\n';
    }

    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Statement copied to clipboard!')));
  }

  void _saveEntry() {
    // Save edited entry to Hive
    int entryIndex = _financialBox.values.toList().indexOf(widget.entry);
    if (entryIndex != -1) {
      _financialBox.putAt(entryIndex, _entry);
      Navigator.pop(context); // Go back to the previous screen after saving
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Entry'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _deleteEntry,
          ),
          IconButton(
            icon: Icon(Icons.share),
            onPressed: _shareEntry,
          ),
          IconButton(
            icon: Icon(Icons.print),
            onPressed: _printEntry,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Timestamp: ${_entry.first['timestamp']}'),
            Expanded(
              child: ListView.builder(
                itemCount: _entry.length,
                itemBuilder: (context, index) {
                  var item = _entry[index];
                  return ListTile(
                    title: TextField(
                      decoration: InputDecoration(labelText: 'Description'),
                      controller:
                          TextEditingController(text: item['description']),
                      onChanged: (value) {
                        setState(() {
                          item['description'] = value;
                        });
                      },
                    ),
                    subtitle: TextField(
                      decoration: InputDecoration(labelText: 'Amount'),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(
                          text: item['amount'].toString()),
                      onChanged: (value) {
                        setState(() {
                          item['amount'] = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveEntry,
              child: Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}

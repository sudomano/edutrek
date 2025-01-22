import 'package:flutter/material.dart';

class MultiSelectChip extends StatefulWidget {
  final List<String> items;
  final List<String> initialSelectedItems;
  final Function(List<String>) onSelectionChanged;

  const MultiSelectChip({
    Key? key,
    required this.items,
    required this.initialSelectedItems,
    required this.onSelectionChanged,
  }) : super(key: key);

  @override
  _MultiSelectChipState createState() => _MultiSelectChipState();
}

class _MultiSelectChipState extends State<MultiSelectChip> {
  late List<String> selectedItems;

  @override
  void initState() {
    super.initState();
    selectedItems = widget.initialSelectedItems;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.0,
      children: widget.items.map((item) {
        final isSelected = selectedItems.contains(item);
        return ChoiceChip(
          label: Text(item),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (item == 'All') {
                selectedItems = selected ? ['All'] : [];
              } else {
                selectedItems.remove('All');
                if (selected) {
                  selectedItems.add(item);
                } else {
                  selectedItems.remove(item);
                }
              }
              widget.onSelectionChanged(selectedItems);
            });
          },
        );
      }).toList(),
    );
  }
}

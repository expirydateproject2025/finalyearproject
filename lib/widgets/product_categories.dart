import 'package:flutter/material.dart';

class StyledCategoryDropdown extends StatefulWidget {
  final Function(String) onCategorySelected;
  final String? selectedCategory;

  const StyledCategoryDropdown({
    Key? key,
    required this.onCategorySelected,
    this.selectedCategory,
  }) : super(key: key);

  @override
  State<StyledCategoryDropdown> createState() => _StyledCategoryDropdownState();
}

class _StyledCategoryDropdownState extends State<StyledCategoryDropdown> {
  final List<String> categories = [
    'cosmetic ',
    'Medicine',
    'Juice',
    'Dairy',
    'Grains',
    'Others',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white, // Border color matching the image
          width: 4,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.category,
            color: Colors.deepOrange,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: DropdownButton<String>(
              value: widget.selectedCategory,
              hint: const Text(
                'Category (Optional)',
                style: TextStyle(color: Colors.deepOrange),
              ),
              icon: const Icon(
                Icons.arrow_drop_down,
                color: Colors.deepOrange,

              ),
              underline: const SizedBox(), // Remove default underline
              dropdownColor: Colors.deepOrange.shade50,
              style: const TextStyle(color: Colors.deepOrange,
              fontSize: 18),
              items: categories.map<DropdownMenuItem<String>>((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  widget.onCategorySelected(newValue ?? '');
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

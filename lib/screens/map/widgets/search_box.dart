import 'package:flutter/material.dart';

class SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final bool hasValidLocation;

  const SearchBox({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hasValidLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search for a location...',
          border: InputBorder.none,
          icon: const Icon(Icons.search),
          suffixIcon: hasValidLocation
              ? Icon(Icons.check_circle, color: Colors.green[600])
              : null,
        ),
      ),
    );
  }
}

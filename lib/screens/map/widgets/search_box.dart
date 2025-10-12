import 'package:flutter/material.dart';

class SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final VoidCallback? onClear;
  final bool hasValidLocation;
  final bool isLoading;

  const SearchBox({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hasValidLocation,
    this.onClear,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: Colors.grey[600],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              decoration: const InputDecoration(
                hintText: 'Search for a place',
                hintStyle: TextStyle(
                  color: Colors.black38,
                  fontSize: 16,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.blue[600]),
                ),
              ),
            )
          else if (controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close, size: 20),
              color: Colors.grey[600],
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              onPressed: onClear,
            ),
          if (hasValidLocation && !isLoading)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.check_circle,
                color: Colors.green[600],
                size: 22,
              ),
            ),
        ],
      ),
    );
  }
}

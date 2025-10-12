import 'package:flutter/material.dart';

class MapControls extends StatelessWidget {
  final VoidCallback onMyLocation;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const MapControls({
    super.key,
    required this.onMyLocation,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // My Location button
        FloatingActionButton(
          mini: true,
          backgroundColor: Colors.white,
          heroTag: 'myLocation',
          onPressed: onMyLocation,
          child: const Icon(Icons.my_location, color: Colors.blue),
        ),
        const SizedBox(height: 8),
        // Zoom in button
        FloatingActionButton(
          mini: true,
          backgroundColor: Colors.white,
          heroTag: 'zoomIn',
          onPressed: onZoomIn,
          child: const Icon(Icons.add, color: Colors.blue),
        ),
        const SizedBox(height: 8),
        // Zoom out button
        FloatingActionButton(
          mini: true,
          backgroundColor: Colors.white,
          heroTag: 'zoomOut',
          onPressed: onZoomOut,
          child: const Icon(Icons.remove, color: Colors.blue),
        ),
      ],
    );
  }
}

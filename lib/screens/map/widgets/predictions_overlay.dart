import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../services/google_places_service.dart';
import '../location_type.dart';
import '../helpers/map_helpers.dart';

class PredictionsOverlay extends StatelessWidget {
  final bool showPredictions;
  final bool showingLocations;
  final List<PlacePrediction> predictions;
  final List<PlaceDetails> nearbyLocations;
  final LocationType selectedCategory;
  final bool isLoadingLocations;
  final LatLng? searchCenterLocation;
  final LatLng selectedLocation;
  final Function(PlacePrediction) onPredictionTapped;
  final Function(PlaceDetails) onLocationTapped;

  const PredictionsOverlay({
    super.key,
    required this.showPredictions,
    required this.showingLocations,
    required this.predictions,
    required this.nearbyLocations,
    required this.selectedCategory,
    required this.isLoadingLocations,
    required this.searchCenterLocation,
    required this.selectedLocation,
    required this.onPredictionTapped,
    required this.onLocationTapped,
  });

  @override
  Widget build(BuildContext context) {
    if (!showPredictions) return const SizedBox.shrink();

    // Show as bottom sheet for nearby locations, dropdown for predictions
    if (showingLocations) {
      return Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: _buildLocationsList(),
        ),
      );
    }

    // Dropdown for search predictions
    return Positioned(
      top: 80,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _buildLocationPredictionsList(),
        ),
      ),
    );
  }

  Widget _buildLocationsList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color.lerp(selectedCategory.color, Colors.white, 0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  selectedCategory.icon,
                  color: selectedCategory.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nearby ${selectedCategory.label}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (!isLoadingLocations)
                      Text(
                        '${nearbyLocations.length} places found',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              if (isLoadingLocations)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(selectedCategory.color),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Content
        if (isLoadingLocations)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (nearbyLocations.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.location_off, size: 56, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'No ${selectedCategory.label.toLowerCase()} found nearby',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try searching a different area',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
        else
          Flexible(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: nearbyLocations.length,
              itemBuilder: (context, i) {
                final location = nearbyLocations[i];
                final distance = calculateDistance(
                  searchCenterLocation ?? selectedLocation,
                  LatLng(
                    location.location!.latitude,
                    location.location!.longitude,
                  ),
                );

                final types = location.types ?? [];
                final icon = getIconForTypes(types);
                final color = getColorForTypes(types);

                return InkWell(
                  onTap: () => onLocationTapped(location),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Color.lerp(color, Colors.white, 0.85),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: color, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                location.displayName?.text ?? 'Location',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${distance.toStringAsFixed(0)}m away${location.formattedAddress != null ? " • ${location.formattedAddress}" : ""}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

   Widget _buildLocationPredictionsList() {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          shrinkWrap: true,
          itemCount: predictions.length,
          itemBuilder: (context, i) {
            final p = predictions[i];
            return InkWell(
              onTap: () => onPredictionTapped(p),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.grey[600],
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.structuredFormat?.mainText?.text ?? p.text?.text ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          if (p.structuredFormat?.secondaryText?.text != null &&
                              p.structuredFormat!.secondaryText!.text.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                p.structuredFormat!.secondaryText!.text,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_outward,
                      size: 18,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

}

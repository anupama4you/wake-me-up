import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart';
import '../location_type.dart';
import '../helpers/map_helpers.dart';

class PredictionsOverlay extends StatelessWidget {
  final bool showPredictions;
  final bool showingLocations;
  final List<AutocompletePrediction> predictions;
  final List<DetailsResult> nearbyLocations;
  final LocationType selectedCategory;
  final bool isLoadingLocations;
  final LatLng? searchCenterLocation;
  final LatLng selectedLocation;
  final Function(AutocompletePrediction) onPredictionTapped;
  final Function(DetailsResult) onLocationTapped;

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

    return Positioned(
      top: 130,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 350),
          child: showingLocations
              ? _buildLocationsList()
              : _buildLocationPredictionsList(),
        ),
      ),
    );
  }

  Widget _buildLocationsList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color.lerp(selectedCategory.color, Colors.white, 0.9),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              Icon(selectedCategory.icon, color: selectedCategory.color, size: 20),
              const SizedBox(width: 8),
              Text(
                'Nearby ${selectedCategory.label}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: selectedCategory.color,
                ),
              ),
              const Spacer(),
              if (isLoadingLocations)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(selectedCategory.color),
                  ),
                )
              else
                Text(
                  '${nearbyLocations.length} found',
                  style: TextStyle(
                    fontSize: 12,
                    color: selectedCategory.color,
                  ),
                ),
            ],
          ),
        ),
        if (isLoadingLocations)
          const Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          )
        else if (nearbyLocations.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(Icons.location_off, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No ${selectedCategory.label.toLowerCase()} found nearby',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          )
        else
          Flexible(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: nearbyLocations.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final location = nearbyLocations[i];
                final distance = calculateDistance(
                  searchCenterLocation ?? selectedLocation,
                  LatLng(
                    location.geometry!.location!.lat!,
                    location.geometry!.location!.lng!,
                  ),
                );

                final types = location.types ?? [];
                final icon = getIconForTypes(types);
                final color = getColorForTypes(types);

                return ListTile(
                  dense: true,
                  leading: Icon(icon, color: color),
                  title: Text(
                    location.name ?? 'Location',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '${distance.toStringAsFixed(0)}m away${location.vicinity != null ? " • ${location.vicinity}" : ""}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
                  onTap: () => onLocationTapped(location),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildLocationPredictionsList() {
    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: predictions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final p = predictions[i];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.location_on),
          title: Text(p.structuredFormatting?.mainText ?? p.description ?? ''),
          subtitle: Text(
            p.structuredFormatting?.secondaryText ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          onTap: () => onPredictionTapped(p),
        );
      },
    );
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for interacting with the new Google Places API
/// https://developers.google.com/maps/documentation/places/web-service/op-overview
class GooglePlacesService {
  final String apiKey;
  static const String _baseUrl = 'https://places.googleapis.com/v1';

  GooglePlacesService(this.apiKey);

  /// Autocomplete (New) - Returns place predictions based on input text
  /// https://developers.google.com/maps/documentation/places/web-service/place-autocomplete
  Future<AutocompleteResponse> autocomplete({
    required String input,
    String? sessionToken,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    String? languageCode = 'en',
    String? regionCode,
    List<String>? includedPrimaryTypes,
  }) async {
    final url = Uri.parse('$_baseUrl/places:autocomplete');

    final body = <String, dynamic>{
      'input': input,
      if (sessionToken != null) 'sessionToken': sessionToken,
      if (languageCode != null) 'languageCode': languageCode,
      if (regionCode != null) 'regionCode': regionCode,
      if (includedPrimaryTypes != null && includedPrimaryTypes.isNotEmpty)
        'includedPrimaryTypes': includedPrimaryTypes,
    };

    // Add location bias if coordinates provided
    if (latitude != null && longitude != null) {
      body['locationBias'] = {
        'circle': {
          'center': {
            'latitude': latitude,
            'longitude': longitude,
          },
          'radius': radiusMeters ?? 50000, // Default 50km
        }
      };
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': 'suggestions.placePrediction.placeId,suggestions.placePrediction.structuredFormat,suggestions.placePrediction.text',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return AutocompleteResponse.fromJson(data);
      } else {
        throw PlacesApiException(
          'Autocomplete failed: ${response.statusCode} - ${response.body}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is PlacesApiException) rethrow;
      throw PlacesApiException('Network error: $e', 0);
    }
  }

  /// Place Details (New) - Returns detailed information about a place
  /// https://developers.google.com/maps/documentation/places/web-service/place-details
  Future<PlaceDetails> placeDetails({
    required String placeId,
    String? sessionToken,
    String? languageCode = 'en',
  }) async {
    final url = Uri.parse('$_baseUrl/places/$placeId');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': 'id,displayName,formattedAddress,location,types,rating,userRatingCount,viewport',
          if (sessionToken != null) 'X-Goog-Session-Token': sessionToken,
          if (languageCode != null) 'X-Goog-Language-Code': languageCode,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PlaceDetails.fromJson(data);
      } else {
        throw PlacesApiException(
          'Place Details failed: ${response.statusCode} - ${response.body}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is PlacesApiException) rethrow;
      throw PlacesApiException('Network error: $e', 0);
    }
  }

  /// Nearby Search (New) - Search for places within a specified area
  /// https://developers.google.com/maps/documentation/places/web-service/nearby-search
  Future<NearbySearchResponse> nearbySearch({
    required double latitude,
    required double longitude,
    double radiusMeters = 1500,
    List<String>? includedTypes,
    int maxResultCount = 20,
    String? languageCode = 'en',
  }) async {
    final url = Uri.parse('$_baseUrl/places:searchNearby');

    final body = <String, dynamic>{
      'locationRestriction': {
        'circle': {
          'center': {
            'latitude': latitude,
            'longitude': longitude,
          },
          'radius': radiusMeters,
        }
      },
      'maxResultCount': maxResultCount,
      if (languageCode != null) 'languageCode': languageCode,
      if (includedTypes != null && includedTypes.isNotEmpty)
        'includedTypes': includedTypes,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.location,places.types,places.rating,places.userRatingCount',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return NearbySearchResponse.fromJson(data);
      } else {
        throw PlacesApiException(
          'Nearby Search failed: ${response.statusCode} - ${response.body}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is PlacesApiException) rethrow;
      throw PlacesApiException('Network error: $e', 0);
    }
  }
}

// Exception class for API errors
class PlacesApiException implements Exception {
  final String message;
  final int statusCode;

  PlacesApiException(this.message, this.statusCode);

  @override
  String toString() => 'PlacesApiException: $message (Status: $statusCode)';
}

// Models for the new API

class AutocompleteResponse {
  final List<AutocompleteSuggestion> suggestions;

  AutocompleteResponse({required this.suggestions});

  factory AutocompleteResponse.fromJson(Map<String, dynamic> json) {
    final suggestionsJson = json['suggestions'] as List<dynamic>? ?? [];
    return AutocompleteResponse(
      suggestions: suggestionsJson
          .map((s) => AutocompleteSuggestion.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AutocompleteSuggestion {
  final PlacePrediction? placePrediction;

  AutocompleteSuggestion({this.placePrediction});

  factory AutocompleteSuggestion.fromJson(Map<String, dynamic> json) {
    return AutocompleteSuggestion(
      placePrediction: json['placePrediction'] != null
          ? PlacePrediction.fromJson(json['placePrediction'] as Map<String, dynamic>)
          : null,
    );
  }
}

class PlacePrediction {
  final String placeId;
  final PlaceText? text;
  final StructuredFormat? structuredFormat;

  PlacePrediction({
    required this.placeId,
    this.text,
    this.structuredFormat,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      placeId: json['placeId'] as String,
      text: json['text'] != null
          ? PlaceText.fromJson(json['text'] as Map<String, dynamic>)
          : null,
      structuredFormat: json['structuredFormat'] != null
          ? StructuredFormat.fromJson(json['structuredFormat'] as Map<String, dynamic>)
          : null,
    );
  }
}

class PlaceText {
  final String text;

  PlaceText({required this.text});

  factory PlaceText.fromJson(Map<String, dynamic> json) {
    return PlaceText(
      text: json['text'] as String? ?? '',
    );
  }
}

class StructuredFormat {
  final PlaceText? mainText;
  final PlaceText? secondaryText;

  StructuredFormat({this.mainText, this.secondaryText});

  factory StructuredFormat.fromJson(Map<String, dynamic> json) {
    return StructuredFormat(
      mainText: json['mainText'] != null
          ? PlaceText.fromJson(json['mainText'] as Map<String, dynamic>)
          : null,
      secondaryText: json['secondaryText'] != null
          ? PlaceText.fromJson(json['secondaryText'] as Map<String, dynamic>)
          : null,
    );
  }
}

class PlaceDetails {
  final String id;
  final DisplayName? displayName;
  final String? formattedAddress;
  final LatLngLocation? location;
  final List<String>? types;
  final double? rating;
  final int? userRatingCount;

  PlaceDetails({
    required this.id,
    this.displayName,
    this.formattedAddress,
    this.location,
    this.types,
    this.rating,
    this.userRatingCount,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    return PlaceDetails(
      id: json['id'] as String,
      displayName: json['displayName'] != null
          ? DisplayName.fromJson(json['displayName'] as Map<String, dynamic>)
          : null,
      formattedAddress: json['formattedAddress'] as String?,
      location: json['location'] != null
          ? LatLngLocation.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      types: (json['types'] as List<dynamic>?)?.cast<String>(),
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingCount: json['userRatingCount'] as int?,
    );
  }
}

class DisplayName {
  final String text;
  final String? languageCode;

  DisplayName({required this.text, this.languageCode});

  factory DisplayName.fromJson(Map<String, dynamic> json) {
    return DisplayName(
      text: json['text'] as String? ?? '',
      languageCode: json['languageCode'] as String?,
    );
  }
}

class LatLngLocation {
  final double latitude;
  final double longitude;

  LatLngLocation({required this.latitude, required this.longitude});

  factory LatLngLocation.fromJson(Map<String, dynamic> json) {
    return LatLngLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class NearbySearchResponse {
  final List<PlaceDetails> places;

  NearbySearchResponse({required this.places});

  factory NearbySearchResponse.fromJson(Map<String, dynamic> json) {
    final placesJson = json['places'] as List<dynamic>? ?? [];
    return NearbySearchResponse(
      places: placesJson
          .map((p) => PlaceDetails.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

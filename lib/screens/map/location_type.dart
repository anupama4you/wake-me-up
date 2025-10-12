import 'package:flutter/material.dart';

/// Enum representing different types of locations that can be searched for
enum LocationType {
  all('', Icons.grid_view, 'All', Colors.blue),
  busStop('bus_station', Icons.directions_bus, 'Bus', Colors.orange),
  trainStation('train_station', Icons.train, 'Train', Colors.green),
  tramStop('light_rail_station', Icons.tram, 'Tram', Colors.purple),
  subway('subway_station', Icons.subway, 'Metro', Colors.red),
  transitStation('transit_station', Icons.commute, 'Transit', Colors.teal),
  airport('airport', Icons.local_airport, 'Airport', Colors.indigo),
  university('university', Icons.school, 'University', Colors.amber),
  hospital('hospital', Icons.local_hospital, 'Hospital', Colors.pink),
  shoppingMall('shopping_mall', Icons.shopping_bag, 'Mall', Colors.deepOrange),
  park('park', Icons.park, 'Park', Colors.lightGreen);

  final String googleType;
  final IconData icon;
  final String label;
  final Color color;

  const LocationType(this.googleType, this.icon, this.label, this.color);
}

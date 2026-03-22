import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleModel {
  final String id;
  final String plateNumber;
  final String type;
  final String? model;
  final bool isAvailable;
  final GeoPoint? currentLocation;
  final int totalTrips;
  final double totalKm;
  final String? assignedDriverId;

  VehicleModel({
    required this.id,
    required this.plateNumber,
    required this.type,
    this.model,
    this.isAvailable = true,
    this.currentLocation,
    this.totalTrips = 0,
    this.totalKm = 0.0,
    this.assignedDriverId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plateNumber': plateNumber,
      'type': type,
      'model': model,
      'isAvailable': isAvailable,
      'currentLocation': currentLocation,
      'totalTrips': totalTrips,
      'totalKm': totalKm,
      'assignedDriverId': assignedDriverId,
    };
  }

  factory VehicleModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return VehicleModel(
      id: id ?? map['id'] ?? '',
      plateNumber: map['plateNumber'] ?? '',
      type: map['type'] ?? '',
      model: map['model'],
      isAvailable: map['isAvailable'] ?? true,
      currentLocation: map['currentLocation'],
      totalTrips: map['totalTrips'] ?? 0,
      totalKm: (map['totalKm'] ?? 0.0).toDouble(),
      assignedDriverId: map['assignedDriverId'],
    );
  }

  VehicleModel copyWith({
    String? id,
    String? plateNumber,
    String? type,
    String? model,
    bool? isAvailable,
    GeoPoint? currentLocation,
    int? totalTrips,
    double? totalKm,
    String? assignedDriverId,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      plateNumber: plateNumber ?? this.plateNumber,
      type: type ?? this.type,
      model: model ?? this.model,
      isAvailable: isAvailable ?? this.isAvailable,
      currentLocation: currentLocation ?? this.currentLocation,
      totalTrips: totalTrips ?? this.totalTrips,
      totalKm: totalKm ?? this.totalKm,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
    );
  }
}

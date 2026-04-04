import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleModel {
  final String id;
  final String plateNumber;
  final String type;
  final String? model;
  final String? nickname;
  final bool isAvailable;
  final GeoPoint? currentLocation;
  final double heading;
  final int totalTrips;
  final double totalKm;
  final String? assignedDriverId;
  final String? imageUrl;

  VehicleModel({
    required this.id,
    required this.plateNumber,
    required this.type,
    this.model,
    this.nickname,
    this.isAvailable = true,
    this.currentLocation,
    this.heading = 0.0,
    this.totalTrips = 0,
    this.totalKm = 0.0,
    this.assignedDriverId,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plateNumber': plateNumber,
      'type': type,
      'model': model,
      'nickname': nickname,
      'isAvailable': isAvailable,
      'currentLocation': currentLocation,
      'heading': heading,
      'totalTrips': totalTrips,
      'totalKm': totalKm,
      'assignedDriverId': assignedDriverId,
      'imageUrl': imageUrl,
    };
  }

  factory VehicleModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return VehicleModel(
      id: id ?? map['id'] ?? '',
      plateNumber: map['plateNumber'] ?? '',
      type: map['type'] ?? '',
      model: map['model'],
      nickname: map['nickname'],
      isAvailable: map['isAvailable'] ?? true,
      currentLocation: map['currentLocation'],
      heading: (map['heading'] ?? 0.0).toDouble(),
      totalTrips: map['totalTrips'] ?? 0,
      totalKm: (map['totalKm'] ?? 0.0).toDouble(),
      assignedDriverId: map['assignedDriverId'],
      imageUrl: map['imageUrl'],
    );
  }

  VehicleModel copyWith({
    String? id,
    String? plateNumber,
    String? type,
    String? model,
    String? nickname,
    bool? isAvailable,
    GeoPoint? currentLocation,
    double? heading,
    int? totalTrips,
    double? totalKm,
    String? assignedDriverId,
    String? imageUrl,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      plateNumber: plateNumber ?? this.plateNumber,
      type: type ?? this.type,
      model: model ?? this.model,
      nickname: nickname ?? this.nickname,
      isAvailable: isAvailable ?? this.isAvailable,
      currentLocation: currentLocation ?? this.currentLocation,
      heading: heading ?? this.heading,
      totalTrips: totalTrips ?? this.totalTrips,
      totalKm: totalKm ?? this.totalKm,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}


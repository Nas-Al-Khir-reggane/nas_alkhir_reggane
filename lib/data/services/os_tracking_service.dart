import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

class OSTrackingService extends GetxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _positionStreamSubscription;
  String? _activeVehicleId;

  Future<void> startTracking(String vehicleId) async {
    _activeVehicleId = vehicleId;
    
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _updateFirestore(position);
    });
  }

  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _activeVehicleId = null;
  }

  Future<void> _updateFirestore(Position position) async {
    if (_activeVehicleId == null) return;

    try {
      await _firestore.collection('vehicles').doc(_activeVehicleId).update({
        'currentLocation': GeoPoint(position.latitude, position.longitude),
        'heading': position.heading,
        'lastUpdate': FieldValue.serverTimestamp(),
        'isAvailable': false, // السيارة مشغولة أثناء التتبع
      });
    } catch (e) {
      Get.log('Error updating vehicle location: $e');
    }
  }

  @override
  void onClose() {
    stopTracking();
    super.onClose();
  }
}

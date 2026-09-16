import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

enum LocationCaptureIssue {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unavailable,
}

class LocationCaptureResult {
  const LocationCaptureResult({
    this.point,
    this.accuracy,
    this.isReducedAccuracy = false,
    this.issue,
  });

  final GeoPoint? point;
  final double? accuracy;
  final bool isReducedAccuracy;
  final LocationCaptureIssue? issue;

  bool get isSuccess => point != null;
}

class LocationService {
  const LocationService._();

  static Future<LocationCaptureResult> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return const LocationCaptureResult(
          issue: LocationCaptureIssue.serviceDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const LocationCaptureResult(
          issue: LocationCaptureIssue.permissionDenied,
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationCaptureResult(
          issue: LocationCaptureIssue.permissionDeniedForever,
        );
      }

      final accuracyStatus = await Geolocator.getLocationAccuracy();

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );

      return LocationCaptureResult(
        point: GeoPoint(
          position.latitude,
          position.longitude,
        ),
        accuracy: position.accuracy > 0
            ? position.accuracy
            : null,
        isReducedAccuracy:
            accuracyStatus == LocationAccuracyStatus.reduced,
      );
    } on TimeoutException {
      return const LocationCaptureResult(
        issue: LocationCaptureIssue.timeout,
      );
    } catch (_) {
      return const LocationCaptureResult(
        issue: LocationCaptureIssue.unavailable,
      );
    }
  }

  static Future<bool> openLocationSettings() =>
      Geolocator.openLocationSettings();

  static Future<bool> openAppSettings() =>
      Geolocator.openAppSettings();
}
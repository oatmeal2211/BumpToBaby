import 'package:geolocator/geolocator.dart';
import '../models/clinic.dart';
import '../data/clinic_list.dart';

class ClinicService {
  Clinic? findNearestClinic(Position userPosition) {
    Clinic? nearest;
    double shortestDistance = double.infinity;

    for (var clinic in clinics) {
      double distance = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        clinic.latitude,
        clinic.longitude,
      );

      if (distance < shortestDistance) {
        shortestDistance = distance;
        nearest = clinic;
      }
    }

    return nearest;
  }
}

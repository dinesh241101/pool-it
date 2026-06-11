import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/ride_model.dart';
import '../models/booking_model.dart';
import '../models/vehicle_model.dart';
import '../core/storage/local_storage_service.dart';
import '../core/constants/app_constants.dart';

class RideProvider extends ChangeNotifier {
  List<RideModel> _rides = [];
  List<BookingModel> _bookings = [];
  List<VehicleModel> _vehicles = [];
  List<RideModel> _searchResults = [];
  bool _isLoading = false;
  final _uuid = const Uuid();

  List<RideModel> get rides => _rides;
  List<BookingModel> get bookings => _bookings;
  List<VehicleModel> get vehicles => _vehicles;
  List<RideModel> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  List<RideModel> get activeRides =>
      _rides.where((r) => r.status == 'active').toList();

  Future<void> init() async {
    final storage = await LocalStorageService.getInstance();
    final ridesList = storage.getList(AppConstants.storageKeyRides);
    final bookingsList = storage.getList(AppConstants.storageKeyBookings);
    final vehiclesList = storage.getList(AppConstants.storageKeyVehicles);

    _rides = ridesList
        .map((e) => RideModel.fromJson(e as Map<String, dynamic>))
        .toList();
    _bookings = bookingsList
        .map((e) => BookingModel.fromJson(e as Map<String, dynamic>))
        .toList();
    _vehicles = vehiclesList
        .map((e) => VehicleModel.fromJson(e as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    final storage = await LocalStorageService.getInstance();
    await storage.saveList(
        AppConstants.storageKeyRides, _rides.map((r) => r.toJson()).toList());
    await storage.saveList(AppConstants.storageKeyBookings,
        _bookings.map((b) => b.toJson()).toList());
    await storage.saveList(AppConstants.storageKeyVehicles,
        _vehicles.map((v) => v.toJson()).toList());
  }

  Future<void> addVehicle(VehicleModel vehicle) async {
    _vehicles.add(vehicle);
    await _saveToStorage();
    notifyListeners();
  }

  Future<void> createRide(RideModel ride) async {
    _rides.add(ride);
    await _saveToStorage();
    notifyListeners();
  }

  void searchRides({
    required String source,
    required String destination,
    DateTime? date,
  }) {
    _searchResults = _rides.where((ride) {
      if (ride.status != 'active') return false;
      final sourceMatch =
          ride.source.toLowerCase().contains(source.toLowerCase());
      final destMatch = ride.destination
          .toLowerCase()
          .contains(destination.toLowerCase());
      final dateMatch = date == null ||
          (ride.dateTime.year == date.year &&
              ride.dateTime.month == date.month &&
              ride.dateTime.day == date.day);
      return sourceMatch && destMatch && dateMatch;
    }).toList();
    notifyListeners();
  }

  Future<BookingModel?> bookRide({
    required String rideId,
    required String riderId,
    required String riderName,
    required int seats,
  }) async {
    final rideIndex = _rides.indexWhere((r) => r.id == rideId);
    if (rideIndex == -1) return null;
    final ride = _rides[rideIndex];
    if (ride.availableSeats < seats) return null;

    final otp = _generateOtp();
    final booking = BookingModel(
      id: _uuid.v4(),
      rideId: rideId,
      riderId: riderId,
      riderName: riderName,
      seatsBooked: seats,
      totalFare: ride.farePerSeat * seats,
      otp: otp,
      otpExpiry: DateTime.now().add(const Duration(minutes: 10)),
    );

    _bookings.add(booking);
    _rides[rideIndex] = ride.copyWith(
      availableSeats: ride.availableSeats - seats,
    );
    await _saveToStorage();
    notifyListeners();
    return booking;
  }

  Future<bool> verifyOtp(String bookingId, String otp) async {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index == -1) return false;

    final booking = _bookings[index];
    if (booking.otpAttempts >= 3) return false;
    if (DateTime.now().isAfter(booking.otpExpiry)) return false;

    if (booking.otp == otp) {
      _bookings[index] = booking.copyWith(
        status: 'started',
        otpAttempts: booking.otpAttempts + 1,
      );
      await _saveToStorage();
      notifyListeners();
      return true;
    } else {
      _bookings[index] = booking.copyWith(
        otpAttempts: booking.otpAttempts + 1,
      );
      await _saveToStorage();
      notifyListeners();
      return false;
    }
  }

  Future<void> completeRide(String rideId) async {
    final rideIndex = _rides.indexWhere((r) => r.id == rideId);
    if (rideIndex == -1) return;
    _rides[rideIndex] = _rides[rideIndex].copyWith(status: 'completed');
    final relatedBookings = _bookings
        .where((b) => b.rideId == rideId && b.status == 'started')
        .toList();
    for (final b in relatedBookings) {
      final bIndex = _bookings.indexWhere((b2) => b2.id == b.id);
      if (bIndex != -1) {
        _bookings[bIndex] = _bookings[bIndex].copyWith(status: 'completed');
      }
    }
    await _saveToStorage();
    notifyListeners();
  }

  String _generateOtp() {
    final rng = _uuid.hashCode.abs();
    return ((rng % 900000) + 100000).toString();
  }
}

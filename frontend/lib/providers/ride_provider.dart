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

  List<RideModel> get upcomingRides =>
      _rides.where((r) => r.status == 'active' || r.status == 'started').toList();

  List<RideModel> get completedRides =>
      _rides.where((r) => r.status == 'completed').toList();

  List<BookingModel> getUserBookings(String userId) =>
      _bookings.where((b) => b.riderId == userId).toList();

  List<BookingModel> getCompletedBookings(String userId) =>
      _bookings.where((b) => b.riderId == userId && b.status == 'completed').toList();

  List<BookingModel> getUpcomingBookings(String userId) =>
      _bookings.where((b) => b.riderId == userId && b.status != 'completed').toList();

  RideModel? getRideById(String rideId) {
    try {
      return _rides.firstWhere((r) => r.id == rideId);
    } catch (_) {
      return null;
    }
  }

  List<RideModel> getUserRides(String userId) =>
      _rides.where((r) => r.driverId == userId).toList();

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

  Future<void> seedDummyData(String userId, String userName) async {
    if (_rides.isNotEmpty) return;

    final now = DateTime.now();

    final dummyRides = [
      RideModel(
        id: _uuid.v4(),
        driverId: 'driver_rajesh',
        driverName: 'Rajesh Kumar',
        vehicleId: '',
        vehicleInfo: 'Toyota Camry (White)',
        source: 'MG Road, Bangalore',
        destination: 'Electronic City, Bangalore',
        intermediateStops: ['Koramangala', 'HSR Layout', 'Silk Board'],
        dateTime: now.add(const Duration(hours: 2)),
        availableSeats: 3,
        totalSeats: 4,
        farePerSeat: 80,
        status: 'active',
      ),
      RideModel(
        id: _uuid.v4(),
        driverId: 'driver_priya',
        driverName: 'Priya Sharma',
        vehicleId: '',
        vehicleInfo: 'Honda City (Silver)',
        source: 'Indiranagar, Bangalore',
        destination: 'Whitefield, Bangalore',
        intermediateStops: ['Domlur', 'Marathahalli', 'Brookefield'],
        dateTime: now.add(const Duration(hours: 3)),
        availableSeats: 2,
        totalSeats: 4,
        farePerSeat: 60,
        status: 'active',
      ),
      RideModel(
        id: _uuid.v4(),
        driverId: 'driver_amit',
        driverName: 'Amit Singh',
        vehicleId: '',
        vehicleInfo: 'Swift Dzire (Blue)',
        source: 'Jayanagar, Bangalore',
        destination: 'Majestic, Bangalore',
        intermediateStops: ['Lalbagh', 'City Market'],
        dateTime: now.add(const Duration(hours: 4)),
        availableSeats: 1,
        totalSeats: 3,
        farePerSeat: 50,
        status: 'active',
      ),
      RideModel(
        id: _uuid.v4(),
        driverId: 'driver_neha',
        driverName: 'Neha Patel',
        vehicleId: '',
        vehicleInfo: 'Hyundai i20 (Red)',
        source: 'Whitefield, Bangalore',
        destination: 'Koramangala, Bangalore',
        intermediateStops: ['Marathahalli', 'Bellandur', 'HSR Layout'],
        dateTime: now.add(const Duration(hours: 5)),
        availableSeats: 2,
        totalSeats: 4,
        farePerSeat: 70,
        status: 'active',
      ),
      RideModel(
        id: _uuid.v4(),
        driverId: 'driver_vikram',
        driverName: 'Vikram Reddy',
        vehicleId: '',
        vehicleInfo: 'Mahindra XUV700 (Black)',
        source: 'Hebbal, Bangalore',
        destination: 'JP Nagar, Bangalore',
        intermediateStops: ['Yeshwanthpur', 'Mysore Road', 'Banashankari'],
        dateTime: now.add(const Duration(hours: 6)),
        availableSeats: 4,
        totalSeats: 6,
        farePerSeat: 45,
        status: 'active',
      ),
    ];

    _rides.addAll(dummyRides);

    final pastRide = RideModel(
      id: _uuid.v4(),
      driverId: 'driver_completed',
      driverName: 'Sneha Gupta',
      vehicleId: '',
      vehicleInfo: 'Maruti Suzuki (White)',
      source: 'BTM Layout, Bangalore',
      destination: 'Manyata Tech Park, Bangalore',
      intermediateStops: ['Silk Board', 'Hebbal'],
      dateTime: now.subtract(const Duration(days: 1)),
      availableSeats: 0,
      totalSeats: 3,
      farePerSeat: 55,
      status: 'completed',
    );
    _rides.add(pastRide);

    final pastBooking = BookingModel(
      id: _uuid.v4(),
      rideId: pastRide.id,
      riderId: userId,
      riderName: userName,
      seatsBooked: 1,
      totalFare: 55,
      status: 'completed',
      otp: '998877',
    );
    _bookings.add(pastBooking);

    final pastRide2 = RideModel(
      id: _uuid.v4(),
      driverId: 'driver_completed2',
      driverName: 'Rahul Verma',
      vehicleId: '',
      vehicleInfo: 'Tata Nexon (Blue)',
      source: 'Koramangala, Bangalore',
      destination: 'Electronic City, Bangalore',
      intermediateStops: ['HSR Layout', 'Silk Board'],
      dateTime: now.subtract(const Duration(days: 2)),
      availableSeats: 0,
      totalSeats: 4,
      farePerSeat: 65,
      status: 'completed',
    );
    _rides.add(pastRide2);

    final pastBooking2 = BookingModel(
      id: _uuid.v4(),
      rideId: pastRide2.id,
      riderId: userId,
      riderName: userName,
      seatsBooked: 2,
      totalFare: 130,
      status: 'completed',
      otp: '556677',
    );
    _bookings.add(pastBooking2);

    await _saveToStorage();
    notifyListeners();
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

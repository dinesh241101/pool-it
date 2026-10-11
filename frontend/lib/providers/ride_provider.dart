import 'package:flutter/material.dart';
import '../models/ride_model.dart';
import '../models/booking_model.dart';
import '../models/vehicle_model.dart';
import '../core/services/supabase_service.dart';
import '../core/services/cache_service.dart';

class RideProvider extends ChangeNotifier {
  List<RideModel> _rides = [];
  List<BookingModel> _bookings = [];
  List<BookingModel> _bookingRequests = [];
  List<VehicleModel> _vehicles = [];
  List<RideModel> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _error;

  List<RideModel> get rides => _rides;
  List<BookingModel> get bookings => _bookings;
  List<BookingModel> get bookingRequests => _bookingRequests;
  List<VehicleModel> get vehicles => _vehicles;
  List<RideModel> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get error => _error;

  List<RideModel> get completedRides => _rides.where((r) => r.status == 'completed').toList();

  RideModel? getRideById(String rideId) {
    for (final r in _rides) {
      if (r.id == rideId) return r;
    }
    for (final r in _searchResults) {
      if (r.id == rideId) return r;
    }
    return null;
  }

  List<RideModel> getUserRides(String userId) => _rides.where((r) => r.driverId == userId).toList();

  List<BookingModel> getUserBookings(String userId) => _bookings.where((b) => b.riderId == userId).toList();

  List<BookingModel> getUpcomingBookings(String userId) =>
      _bookings.where((b) => b.riderId == userId && b.status != 'completed').toList();

  List<BookingModel> getCompletedBookings(String userId) =>
      _bookings.where((b) => b.riderId == userId && b.status == 'completed').toList();

  List<BookingModel> getRequestsForRide(String rideId) => _bookingRequests.where((b) => b.rideId == rideId).toList();

  // =====================================================================
  // init: hydrate from cache first (no network unless stale)
  // =====================================================================

  Future<void> init({String? userId}) async {
    final cache = await CacheService.getInstance();

    if (userId != null) {
      final cachedRides = cache.readIfFresh('rides:mine:$userId');
      if (cachedRides is List) {
        _rides = _decodeRides(cachedRides);
      }
      final cachedBookings = cache.readIfFresh('bookings:passenger:$userId');
      if (cachedBookings is List) {
        _bookings = _decodeBookings(cachedBookings);
        await _syncBookedRides(_bookings);
      }
      final cachedVehicles = cache.readIfFresh('vehicles:$userId');
      if (cachedVehicles is List) {
        _vehicles = _decodeVehicles(cachedVehicles);
      }
    }
    notifyListeners();

    if (userId != null) {
      await fetchMyRides(userId);
      await fetchPassengerBookings(userId);
      await fetchVehicles(userId);
    }
  }

  Future<void> fetchMyRides(String userId, {bool forceRefresh = false}) async {
    final cache = await CacheService.getInstance();
    final key = 'rides:mine:$userId';

    if (!forceRefresh) {
      final cached = cache.readIfFresh(key);
      if (cached is List) {
        _rides = _decodeRides(cached);
        notifyListeners();
        return;
      }
    }

    try {
      final rides = await SupabaseService.fetchMyRides(userId);
      _rides = rides;
      _error = null;
      await cache.put(key, _encodeRides(rides));
    } catch (e) {
      _error = e.toString();
      debugPrint('fetchMyRides error: $e');
    }
    notifyListeners();
  }

  Future<void> fetchPassengerBookings(String userId, {bool forceRefresh = false}) async {
    final cache = await CacheService.getInstance();
    final key = 'bookings:passenger:$userId';

    if (!forceRefresh) {
      final cached = cache.readIfFresh(key);
      if (cached is List) {
        _bookings = _decodeBookings(cached);
        notifyListeners();
        return;
      }
    }

    try {
      final bookings = await SupabaseService.fetchPassengerBookings(userId);
      _bookings = bookings;
      await _syncBookedRides(bookings);
      _error = null;
      await cache.put(key, _encodeBookings(bookings));
    } catch (e) {
      _error = e.toString();
      debugPrint('fetchPassengerBookings error: $e');
    }
    notifyListeners();
  }

  Future<void> searchRides({
    required String source,
    required String destination,
    required String currentUserId,
    DateTime? date,
  }) async {
    _isSearching = true;
    notifyListeners();

    final cache = await CacheService.getInstance();
    final dateKey = date?.toIso8601String().split('T').first ?? 'any';
    final key = 'rides:search:$currentUserId|$source|$destination|$dateKey';

    final cached = cache.readIfFresh(key);
    if (cached is List) {
      _searchResults = _decodeRides(cached);
      _error = null;
      _isSearching = false;
      notifyListeners();
      return;
    }

    try {
      final rides = await SupabaseService.searchRides(
        source: source,
        destination: destination,
        excludeUserId: currentUserId,
        date: date,
      );
      _searchResults = rides;
      _error = null;
      await cache.put(key, _encodeRides(rides), ttl: const Duration(minutes: 2));
    } catch (e) {
      _error = e.toString();
      debugPrint('searchRides error: $e');
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<RideModel?> createRide({
    required String driverId,
    required String driverName,
    required String source,
    required String destination,
    required DateTime dateTime,
    required int seats,
    String? vehicleId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final ride = await SupabaseService.createRide(
        driverId: driverId,
        driverName: driverName,
        source: source,
        destination: destination,
        dateTime: dateTime,
        seats: seats,
        vehicleId: vehicleId,
      );
      _rides.insert(0, ride);
      final cache = await CacheService.getInstance();
      await cache.removePrefix('rides:search:');
      await cache.remove('rides:mine:$driverId');
      return ride;
    } catch (e) {
      _error = e.toString();
      debugPrint('createRide error: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<BookingModel?> requestBooking({
    required String rideId,
    required String passengerId,
    required String passengerName,
    required int seats,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final booking = await SupabaseService.requestBooking(
        rideId: rideId,
        passengerId: passengerId,
        passengerName: passengerName,
        seats: seats,
      );
      _bookings.insert(0, booking);
      final cache = await CacheService.getInstance();
      await cache.remove('bookings:passenger:$passengerId');
      _error = null;
      return booking;
    } catch (e) {
      _error = e.toString();
      debugPrint('requestBooking error: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchBookingRequests(String rideId) async {
    final cache = await CacheService.getInstance();
    final key = 'bookings:ride:$rideId';

    final cached = cache.readIfFresh(key);
    if (cached is List) {
      _bookingRequests = _decodeBookings(cached);
      notifyListeners();
      return;
    }

    try {
      final requests = await SupabaseService.fetchBookingRequests(rideId);
      _bookingRequests = requests;
      _error = null;
      await cache.put(key, _encodeBookings(requests));
    } catch (e) {
      _error = e.toString();
      debugPrint('fetchBookingRequests error: $e');
    }
    notifyListeners();
  }

  Future<bool> approveBooking({
    required String rideId,
    required String bookingId,
    required String currentUserId,
  }) async {
    try {
      await SupabaseService.approveBooking(bookingId);
      final cache = await CacheService.getInstance();
      await cache.remove('bookings:ride:$rideId');
      await cache.remove('rides:mine:$currentUserId');
      await fetchBookingRequests(rideId);
      await fetchMyRides(currentUserId, forceRefresh: true);
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('approveBooking error: $e');
      return false;
    }
  }

  Future<bool> rejectBooking({required String rideId, required String bookingId}) async {
    try {
      await SupabaseService.rejectBooking(bookingId);
      final cache = await CacheService.getInstance();
      await cache.remove('bookings:ride:$rideId');
      await fetchBookingRequests(rideId);
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('rejectBooking error: $e');
      return false;
    }
  }

  Future<bool> cancelBooking({required String bookingId, required String rideId, required String currentUserId}) async {
    try {
      await SupabaseService.cancelBooking(bookingId);
      _bookings = _bookings.map((b) => b.id == bookingId ? b.copyWith(status: 'cancelled') : b).toList();
      final cache = await CacheService.getInstance();
      await cache.remove('bookings:ride:$rideId');
      await cache.remove('bookings:passenger:$currentUserId');
      await cache.remove('rides:mine:$currentUserId');
      await fetchPassengerBookings(currentUserId, forceRefresh: true);
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('cancelBooking error: $e');
      return false;
    }
  }

  // =====================================================================
  // booked rides (passenger view needs the ride rows they don't drive)
  // =====================================================================

  Future<void> _syncBookedRides(List<BookingModel> bookings) async {
    final rideIds = bookings.map((b) => b.rideId).toSet();
    final missing = rideIds.where((id) => getRideById(id) == null).toList();
    if (missing.isEmpty) return;

    try {
      final rides = await SupabaseService.fetchRidesByIds(missing);
      for (final ride in rides) {
        final idx = _rides.indexWhere((r) => r.id == ride.id);
        if (idx >= 0) {
          _rides[idx] = ride;
        } else {
          _rides.add(ride);
        }
      }
    } catch (e) {
      debugPrint('_syncBookedRides error: $e');
    }
  }

  // =====================================================================
  // vehicles
  // =====================================================================

  Future<void> fetchVehicles(String userId, {bool forceRefresh = false}) async {
    final cache = await CacheService.getInstance();
    final key = 'vehicles:$userId';

    if (!forceRefresh) {
      final cached = cache.readIfFresh(key);
      if (cached is List) {
        _vehicles = _decodeVehicles(cached);
        notifyListeners();
        return;
      }
    }

    try {
      final vehicles = await SupabaseService.fetchVehicles(userId);
      _vehicles = vehicles;
      await cache.put(key, _encodeVehicles(vehicles));
      notifyListeners();
    } catch (e) {
      debugPrint('fetchVehicles error: $e');
    }
  }

  Future<VehicleModel?> addVehicle({
    required String driverId,
    required String make,
    required String model,
    required String year,
    required String color,
    required String registrationNumber,
    required int seats,
  }) async {
    try {
      final vehicle = await SupabaseService.addVehicle(
        driverId: driverId,
        make: make,
        model: model,
        year: year,
        color: color,
        registrationNumber: registrationNumber,
        seats: seats,
      );
      _vehicles.add(vehicle);
      final cache = await CacheService.getInstance();
      await cache.remove('vehicles:$driverId');
      notifyListeners();
      return vehicle;
    } catch (e) {
      _error = e.toString();
      debugPrint('addVehicle error: $e');
      return null;
    }
  }

  // =====================================================================
  // encode/decode
  // =====================================================================

  static List<RideModel> _decodeRides(dynamic data) {
    if (data is! List) return [];
    return data.map((e) => RideModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static List<dynamic> _encodeRides(List<RideModel> rides) => rides.map((r) => r.toJson()).toList();

  static List<BookingModel> _decodeBookings(dynamic data) {
    if (data is! List) return [];
    return data.map((e) => BookingModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static List<dynamic> _encodeBookings(List<BookingModel> bookings) => bookings.map((b) => b.toJson()).toList();

  static List<VehicleModel> _decodeVehicles(dynamic data) {
    if (data is! List) return [];
    return data.map((e) => VehicleModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static List<dynamic> _encodeVehicles(List<VehicleModel> vehicles) => vehicles.map((v) => v.toJson()).toList();
}

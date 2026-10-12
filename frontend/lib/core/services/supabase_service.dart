import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../models/ride_model.dart';
import '../../models/booking_model.dart';
import '../../models/vehicle_model.dart';
import '../../models/chat_message.dart';
import '../../models/user_model.dart';

/// Direct Supabase data access for the PoolIT schema.
///
/// DB rows (snake_case) are mapped into the app's model JSON shape here, so
/// the rest of the app keeps working with the existing models.
class SupabaseService {
  static final SupabaseClient _c = Supabase.instance.client;
  static RealtimeChannel? _chatChannel;
  static RealtimeChannel? _bookingsChannel;

  // =====================================================================
  // row -> model JSON mapping
  // =====================================================================

  static Map<String, dynamic> rideRowToJson(Map<String, dynamic> r) => {
    'id': r['id'],
    'driverId': r['driver_id'],
    'driverName': r['driver_name'] ?? '',
    'vehicleId': r['vehicle_id'] ?? '',
    'vehicleInfo': r['vehicle_info'] ?? '',
    'source': r['source_name'] ?? '',
    'destination': r['destination_name'] ?? '',
    'intermediateStops': <String>[],
    'dateTime': r['departure_at'],
    'availableSeats': r['available_seats'] ?? 0,
    'totalSeats': r['initial_seats'] ?? r['available_seats'] ?? 0,
    'farePerSeat': 0.0,
    'status': _mapRideStatus(r['status']),
    'petPolicy': r['pet_policy'] ?? 'not_allowed',
    'createdAt': r['created_at'],
  };

  static String _mapRideStatus(String? status) {
    switch (status) {
      case 'published':
        return 'active';
      case 'in_progress':
        return 'started';
      case 'completed':
        return 'completed';
      case 'cancelled':
        return 'cancelled';
      default:
        return status ?? 'active';
    }
  }

  static Map<String, dynamic> bookingRowToJson(Map<String, dynamic> r) => {
    'id': r['id'],
    'rideId': r['ride_id'],
    'riderId': r['passenger_id'],
    'riderName': r['passenger_name'] ?? '',
    'seatsBooked': r['seats_requested'] ?? 0,
    'totalFare': 0.0,
    'status': r['status'] ?? 'pending',
    'otp': '',
    'otpExpiry': r['created_at'],
    'otpAttempts': 0,
    'createdAt': r['created_at'],
  };

  static Map<String, dynamic> vehicleRowToJson(Map<String, dynamic> r) => {
    'id': r['id'],
    'userId': r['driver_id'],
    'make': r['make'] ?? '',
    'model': r['model'] ?? '',
    'year': r['year'] ?? '',
    'color': r['color'] ?? '',
    'licensePlate': r['registration_number'] ?? '',
    'seats': r['seats'] ?? 0,
    'createdAt': r['created_at'],
  };

  static Map<String, dynamic> chatRowToJson(Map<String, dynamic> r) => {
    'id': r['id'],
    'rideId': r['ride_id'],
    'senderId': r['sender_id'],
    'senderName': r['sender_name'] ?? '',
    'message': r['body'] ?? '',
    'timestamp': r['created_at'],
  };

  static Map<String, dynamic> profileRowToJson(Map<String, dynamic> r) => {
    'id': r['id'],
    'name': r['full_name'] ?? '',
    'phone': r['phone'] ?? '',
    'email': '',
    'profilePic': r['avatar_url'] ?? '',
    'emergencyContact': '',
    'isLicenseVerified': false,
    'isDriver': r['is_driver'] ?? false,
    'isAdmin': r['is_admin'] ?? false,
    'createdAt': r['created_at'],
  };

  // =====================================================================
  // rides
  // =====================================================================

  static Future<List<RideModel>> fetchMyRides(String driverId) async {
    final res = await _c.from('rides').select().eq('driver_id', driverId).order('departure_at');
    return _decodeRides(res);
  }

  static Future<List<RideModel>> searchRides({
    required String source,
    required String destination,
    required String excludeUserId,
    DateTime? date,
  }) async {
    var query = _c
        .from('rides')
        .select()
        .eq('status', 'published')
        .neq('driver_id', excludeUserId)
        .ilike('source_name', '%$source%')
        .ilike('destination_name', '%$destination%')
        .gt('available_seats', 0);

    final PostgrestTransformBuilder<PostgrestList> orderedQuery;
    if (date != null) {
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));
      orderedQuery = query
          .gte('departure_at', start.toUtc().toIso8601String())
          .lt('departure_at', end.toUtc().toIso8601String())
          .order('departure_at');
    } else {
      orderedQuery = query.order('departure_at');
    }

    final res = await orderedQuery;
    return _decodeRides(res);
  }

  static Future<RideModel> createRide({
    required String driverId,
    required String driverName,
    required String source,
    required String destination,
    required DateTime dateTime,
    required int seats,
    String? vehicleId,
  }) async {
    final res = await _c
        .from('rides')
        .insert({
          'driver_id': driverId,
          'driver_name': driverName,
          'source_name': source,
          'destination_name': destination,
          'departure_at': dateTime.toUtc().toIso8601String(),
          'available_seats': seats,
          'initial_seats': seats,
          'vehicle_id': vehicleId,
          'status': 'published',
        })
        .select()
        .single();
    return RideModel.fromJson(rideRowToJson(Map<String, dynamic>.from(res)));
  }

  static Future<List<RideModel>> fetchRidesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final res = await _c.from('rides').select().inFilter('id', ids);
    return _decodeRides(res);
  }

  static Future<void> updateRideStatus(String rideId, String status) async {
    await _c.from('rides').update({'status': status}).eq('id', rideId);
  }

  // =====================================================================
  // bookings
  // =====================================================================

  static Future<BookingModel> requestBooking({
    required String rideId,
    required String passengerId,
    required String passengerName,
    required int seats,
  }) async {
    final res = await _c
        .from('bookings')
        .insert({
          'ride_id': rideId,
          'passenger_id': passengerId,
          'passenger_name': passengerName,
          'seats_requested': seats,
          'status': 'pending',
        })
        .select()
        .single();
    return BookingModel.fromJson(bookingRowToJson(Map<String, dynamic>.from(res)));
  }

  static Future<List<BookingModel>> fetchBookingRequests(String rideId) async {
    final res = await _c
        .from('bookings')
        .select()
        .eq('ride_id', rideId)
        .inFilter('status', ['pending', 'confirmed'])
        .order('created_at');
    return _decodeBookings(res);
  }

  static Future<List<BookingModel>> fetchPassengerBookings(String passengerId) async {
    final res = await _c
        .from('bookings')
        .select()
        .eq('passenger_id', passengerId)
        .order('created_at', ascending: false);
    return _decodeBookings(res);
  }

  static Future<Map<String, dynamic>> approveBooking(String bookingId) async {
    final res = await _c.rpc('approve_booking', params: {'p_booking_id': bookingId});
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> rejectBooking(String bookingId) async {
    final res = await _c.rpc('reject_booking', params: {'p_booking_id': bookingId});
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    final res = await _c.rpc('cancel_booking', params: {'p_booking_id': bookingId});
    return Map<String, dynamic>.from(res as Map);
  }

  // =====================================================================
  // vehicles
  // =====================================================================

  static Future<List<VehicleModel>> fetchVehicles(String driverId) async {
    final res = await _c.from('vehicles').select().eq('driver_id', driverId).order('created_at');
    return _decodeVehicles(res);
  }

  static Future<VehicleModel> addVehicle({
    required String driverId,
    required String make,
    required String model,
    required String year,
    required String color,
    required String registrationNumber,
    required int seats,
  }) async {
    final res = await _c
        .from('vehicles')
        .insert({
          'driver_id': driverId,
          'make': make,
          'model': model,
          'year': year,
          'color': color,
          'registration_number': registrationNumber,
          'seats': seats,
        })
        .select()
        .single();
    return VehicleModel.fromJson(vehicleRowToJson(Map<String, dynamic>.from(res)));
  }

  // =====================================================================
  // profiles
  // =====================================================================

  static Future<UserModel?> fetchProfile(String userId) async {
    final res = await _c.from('profiles').select().eq('id', userId).maybeSingle();
    if (res == null) return null;
    return UserModel.fromJson(profileRowToJson(Map<String, dynamic>.from(res)));
  }

  static Future<void> updateProfileName(String userId, String name) async {
    await _c.from('profiles').update({'full_name': name}).eq('id', userId);
  }

  static Future<void> updateIsDriver(String userId, bool isDriver) async {
    await _c.from('profiles').update({'is_driver': isDriver}).eq('id', userId);
  }

  // =====================================================================
  // app config
  // =====================================================================

  static Future<Map<String, dynamic>?> fetchAppConfig() async {
    final res = await _c.from('app_config').select().eq('id', 1).maybeSingle();
    if (res == null) return null;
    return Map<String, dynamic>.from(res);
  }

  static Future<Map<String, dynamic>> updateAppConfig(String quizUrl) async {
    final res = await _c.rpc('update_app_config', params: {'p_quiz_url': quizUrl});
    return Map<String, dynamic>.from(res as Map);
  }

  // =====================================================================
  // chat (persisted + authorized realtime)
  // =====================================================================

  static Future<List<ChatMessage>> fetchChatMessages(String rideId) async {
    final res = await _c.from('chat_messages').select().eq('ride_id', rideId).order('created_at').limit(200);
    return _decodeChat(res);
  }

  static Future<void> sendChatMessage({
    required String rideId,
    required String senderId,
    required String senderName,
    required String body,
  }) async {
    await _c.from('chat_messages').insert({
      'ride_id': rideId,
      'sender_id': senderId,
      'sender_name': senderName,
      'body': body,
      'client_message_id': const Uuid().v4(),
    });
  }

  static void subscribeToChat(String rideId, {required void Function(ChatMessage message) onMessage}) {
    _chatChannel?.unsubscribe();
    _chatChannel = _c.channel('chat_$rideId');
    _chatChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'ride_id', value: rideId),
          callback: (payload) {
            final row = Map<String, dynamic>.from(payload.newRecord);
            onMessage(ChatMessage.fromJson(chatRowToJson(row)));
          },
        )
        .subscribe();
  }

  static void unsubscribeChat() {
    _chatChannel?.unsubscribe();
    _chatChannel = null;
  }

  /// Live updates for booking requests arriving on a driver's ride.
  static void subscribeToRideBookings(String rideId, {required void Function() onChanged}) {
    _bookingsChannel?.unsubscribe();
    _bookingsChannel = _c.channel('bookings_$rideId');
    _bookingsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'ride_id', value: rideId),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  static void unsubscribeRideBookings() {
    _bookingsChannel?.unsubscribe();
    _bookingsChannel = null;
  }

  // =====================================================================
  // decode helpers
  // =====================================================================

  static List<RideModel> _decodeRides(dynamic result) {
    if (result is! List) return [];
    return result.map((e) => RideModel.fromJson(rideRowToJson(Map<String, dynamic>.from(e)))).toList();
  }

  static List<BookingModel> _decodeBookings(dynamic result) {
    if (result is! List) return [];
    return result.map((e) => BookingModel.fromJson(bookingRowToJson(Map<String, dynamic>.from(e)))).toList();
  }

  static List<VehicleModel> _decodeVehicles(dynamic result) {
    if (result is! List) return [];
    return result.map((e) => VehicleModel.fromJson(vehicleRowToJson(Map<String, dynamic>.from(e)))).toList();
  }

  static List<ChatMessage> _decodeChat(dynamic result) {
    if (result is! List) return [];
    return result.map((e) => ChatMessage.fromJson(chatRowToJson(Map<String, dynamic>.from(e)))).toList();
  }
}

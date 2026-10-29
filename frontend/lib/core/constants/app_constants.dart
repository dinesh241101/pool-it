class AppConstants {
  static const String appName = 'Pool-It';

  static const String supabaseUrl = 'https://beiovshyiawmgprqnhrw.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_qQvfOfRy_G-J4WVEAQsIkg_8rVRNVg3';

  static const String googleServerClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const String googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static const bool dummyLoginEnabled = true;
  static const String dummyPhone = '9999999999';

  static const String storageKeyCurrentUser = 'poolit_current_user';
  static const String storageKeyUsers = 'poolit_users';
  static const String storageKeyRides = 'poolit_rides';
  static const String storageKeyBookings = 'poolit_bookings';
  static const String storageKeyVehicles = 'poolit_vehicles';
  static const String storageKeyChatMessages = 'poolit_chat_messages';
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ride_provider.dart';
import '../../models/ride_model.dart';
import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../chat/chat_screen.dart';

class RideDetailScreen extends StatefulWidget {
  final RideModel ride;
  const RideDetailScreen({super.key, required this.ride});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  int _seatsToBook = 1;
  bool _isBooking = false;

  Future<void> _bookRide() async {
    setState(() => _isBooking = true);
    final auth = context.read<AuthProvider>();
    final rideProv = context.read<RideProvider>();
    final user = auth.currentUser;

    if (user == null) return;

    final booking = await rideProv.bookRide(
      rideId: widget.ride.id,
      riderId: user.id,
      riderName: user.name,
      seats: _seatsToBook,
    );

    if (!mounted) return;
    setState(() => _isBooking = false);

    if (booking != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Booking Confirmed!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Ride: ${widget.ride.source} → ${widget.ride.destination}'),
              Text('Seats: $_seatsToBook'),
              Text('Total Fare: ₹${booking.totalFare}'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    const Text('Your Boarding OTP',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      booking.otp,
                      style: const TextStyle(
                        fontSize: 32,
                        letterSpacing: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Valid for 10 minutes',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough seats available.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    final auth = context.watch<AuthProvider>();
    final isGuest = auth.currentUser?.isGuest ?? false;
    final isDriver = ride.driverId == auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Details'),
        actions: [
          if (!isDriver)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Chat with driver',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      ride: ride,
                      chatPartnerName: ride.driverName,
                      chatPartnerId: ride.driverId,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          ride.driverName.isNotEmpty
                              ? ride.driverName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ride.driverName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 17)),
                          if (ride.vehicleInfo.isNotEmpty)
                            Text(ride.vehicleInfo,
                                style: TextStyle(
                                    color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    Text(
                      '₹${ride.farePerSeat}',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Route',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildRouteTimeline(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _InfoChip(
                        icon: Icons.event_seat,
                        label: '${ride.availableSeats} seats',
                        value: 'Available'),
                    _InfoChip(
                        icon: Icons.currency_rupee,
                        label: '₹${ride.farePerSeat}',
                        value: 'Per seat'),
                    _InfoChip(
                        icon: Icons.access_time,
                        label:
                            '${ride.dateTime.day}/${ride.dateTime.month} ${ride.dateTime.hour.toString().padLeft(2, '0')}:${ride.dateTime.minute.toString().padLeft(2, '0')}',
                        value: 'Departure'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (isGuest) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  icon: const Icon(Icons.login),
                  label: const Text(
                    'Sign in to Book',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ] else if (ride.availableSeats > 0 && !isDriver) ...[
              Text(
                'Book Seats',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Text('Number of seats: ',
                        style: TextStyle(fontSize: 15)),
                    IconButton(
                      onPressed: _seatsToBook > 1
                          ? () => setState(() => _seatsToBook--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$_seatsToBook',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      onPressed: _seatsToBook < ride.availableSeats
                          ? () => setState(() => _seatsToBook++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${ride.farePerSeat * _seatsToBook}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Text(
                          '${ride.farePerSeat} × $_seatsToBook',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isBooking ? null : _bookRide,
                  icon: _isBooking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.book_online),
                  label: Text(
                    _isBooking ? 'Booking...' : 'Book Seat',
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ] else if (ride.availableSeats == 0 && !isDriver) ...[
              Card(
                color: Colors.grey.shade50,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.event_busy,
                            size: 40, color: AppTheme.textSecondary),
                        SizedBox(height: 8),
                        Text('All seats are booked for this ride',
                            style: TextStyle(
                                fontSize: 15, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (isDriver) ...[
              Card(
                margin: EdgeInsets.zero,
                color: Colors.blue.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline,
                            size: 20, color: AppTheme.secondaryColor),
                        SizedBox(width: 8),
                        Text(
                          'You are the driver of this ride',
                          style: TextStyle(
                              fontSize: 15,
                              color: AppTheme.secondaryColor,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteTimeline() {
    final ride = widget.ride;
    final stops = [ride.source, ...ride.intermediateStops, ride.destination];
    final colors = [
      AppTheme.primaryColor,
      ...List.filled(ride.intermediateStops.length, AppTheme.accentColor),
      AppTheme.errorColor,
    ];

    return Column(
      children: List.generate(stops.length, (index) {
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors[index],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: colors[index].withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    if (index < stops.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: Colors.grey.shade300,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: EdgeInsets.only(
                  top: index == 0 ? 0 : 6,
                  bottom: index < stops.length - 1 ? 6 : 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stops[index],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: index == 0 || index == stops.length - 1
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: colors[index],
                      ),
                    ),
                    if (index == 0)
                      Text('Departure',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary)),
                    if (index == stops.length - 1)
                      Text('Arrival',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 22),
        ),
        const SizedBox(height: 6),
        Text(label,
            style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text(value,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}

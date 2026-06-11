import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ride_provider.dart';
import '../../models/ride_model.dart';
import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';

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
              Text('Ride: ${widget.ride.source} → ${widget.ride.destination}'),
              Text('Seats: $_seatsToBook'),
              Text('Total Fare: ₹${booking.totalFare}'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text('Your Boarding OTP',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      booking.otp,
                      style: TextStyle(
                        fontSize: 28,
                        letterSpacing: 8,
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

    return Scaffold(
      appBar: AppBar(title: const Text('Ride Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.primaryColor,
                          radius: 24,
                          child: Text(
                            ride.driverName.isNotEmpty
                                ? ride.driverName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ride.driverName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            if (ride.vehicleInfo.isNotEmpty)
                              Text(ride.vehicleInfo,
                                  style: TextStyle(
                                      color: AppTheme.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _RouteRow(
                        icon: Icons.trip_origin,
                        text: ride.source,
                        color: AppTheme.primaryColor),
                    ...ride.intermediateStops.map(
                      (stop) => _RouteRow(
                          icon: Icons.stop,
                          text: stop,
                          color: Colors.orange),
                    ),
                    _RouteRow(
                        icon: Icons.location_on,
                        text: ride.destination,
                        color: AppTheme.errorColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _InfoChip(
                        icon: Icons.event_seat,
                        label: '${ride.availableSeats} seats'),
                    _InfoChip(
                        icon: Icons.currency_rupee,
                        label: '₹${ride.farePerSeat}/seat'),
                    _InfoChip(
                        icon: Icons.access_time,
                        label:
                            '${ride.dateTime.day}/${ride.dateTime.month} ${ride.dateTime.hour}:${ride.dateTime.minute.toString().padLeft(2, '0')}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (isGuest) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  icon: const Icon(Icons.login),
                  label: const Text(
                    'Sign in to Book',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ] else if (ride.availableSeats > 0) ...[
              Text(
                'Book Seats',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Number of seats: '),
                  IconButton(
                    onPressed: _seatsToBook > 1
                        ? () => setState(() => _seatsToBook--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$_seatsToBook',
                      style: const TextStyle(fontSize: 20)),
                  IconButton(
                    onPressed: _seatsToBook < ride.availableSeats
                        ? () => setState(() => _seatsToBook++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  const Spacer(),
                  Text(
                    '₹${ride.farePerSeat * _seatsToBook}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
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
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ] else
              Card(
                color: Colors.grey.shade100,
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('All seats are booked for this ride',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _RouteRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ride_provider.dart';
import '../../models/ride_model.dart';
import '../../models/booking_model.dart';
import '../../core/theme/app_theme.dart';
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
  bool _isApproving = false;

  @override
  void initState() {
    super.initState();
    final rideProv = context.read<RideProvider>();
    final isDriver = widget.ride.driverId == context.read<AuthProvider>().currentUser?.id;
    if (isDriver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        rideProv.fetchBookingRequests(widget.ride.id);
      });
    }
  }

  Future<void> _requestBooking() async {
    setState(() => _isBooking = true);
    final auth = context.read<AuthProvider>();
    final rideProv = context.read<RideProvider>();
    final user = auth.currentUser;

    if (user == null) return;

    final booking = await rideProv.requestBooking(
      rideId: widget.ride.id,
      passengerId: user.id,
      passengerName: user.name,
      seats: _seatsToBook,
    );

    if (!mounted) return;
    setState(() => _isBooking = false);

    if (booking != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Booking Request Sent!'),
          content: Text(
            'Your request for ${widget.ride.source} → ${widget.ride.destination} has been sent to ${widget.ride.driverName}. You will be notified once it is approved.',
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(rideProv.error ?? 'Booking failed. Try again.')));
    }
  }

  Future<void> _approve(BookingModel booking) async {
    setState(() => _isApproving = true);
    final rideProv = context.read<RideProvider>();
    await rideProv.approveBooking(
      rideId: widget.ride.id,
      bookingId: booking.id,
      currentUserId: context.read<AuthProvider>().currentUser?.id ?? '',
    );
    if (mounted) setState(() => _isApproving = false);
  }

  Future<void> _reject(BookingModel booking) async {
    setState(() => _isApproving = true);
    final rideProv = context.read<RideProvider>();
    await rideProv.rejectBooking(rideId: widget.ride.id, bookingId: booking.id);
    if (mounted) setState(() => _isApproving = false);
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    final auth = context.watch<AuthProvider>();
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
                    builder: (_) =>
                        ChatScreen(ride: ride, chatPartnerName: ride.driverName, chatPartnerId: ride.driverId),
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
                        gradient: const LinearGradient(colors: [Color(0xFF43A047), Color(0xFF2E7D32)]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          ride.driverName.isNotEmpty ? ride.driverName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ride.driverName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                          if (ride.vehicleInfo.isNotEmpty)
                            Text(ride.vehicleInfo, style: TextStyle(color: AppTheme.textSecondary)),
                        ],
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
                    Text(
                      'Route',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
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
                    _InfoChip(icon: Icons.event_seat, label: '${ride.seats} seats', value: 'Available'),
                    _InfoChip(
                      icon: Icons.access_time,
                      label:
                          '${ride.dateTime.day}/${ride.dateTime.month} ${ride.dateTime.hour.toString().padLeft(2, '0')}:${ride.dateTime.minute.toString().padLeft(2, '0')}',
                      value: 'Departure',
                    ),
                    _InfoChip(icon: Icons.pets, label: ride.petPolicy, value: 'Pets'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (isDriver)
              _buildDriverSection()
            else if (ride.seats > 0) ...[
              Text(
                'Book Seats',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    const Text('Number of seats: ', style: TextStyle(fontSize: 15)),
                    IconButton(
                      onPressed: _seatsToBook > 1 ? () => setState(() => _seatsToBook--) : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text('$_seatsToBook', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      onPressed: _seatsToBook < ride.seats ? () => setState(() => _seatsToBook++) : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isBooking ? null : _requestBooking,
                  icon: _isBooking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.book_online),
                  label: Text(
                    _isBooking ? 'Sending request...' : 'Request Booking',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ] else ...[
              Card(
                color: Colors.grey.shade50,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.event_busy, size: 40, color: AppTheme.textSecondary),
                        SizedBox(height: 8),
                        Text(
                          'All seats are booked for this ride',
                          style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
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

  Widget _buildDriverSection() {
    final rideProv = context.watch<RideProvider>();
    final requests = rideProv.bookingRequests;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Booking Requests',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        Text('${widget.ride.seats} seats available', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 12),
        if (requests.isEmpty)
          Card(
            color: Colors.grey.shade50,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('No booking requests yet', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ),
          )
        else
          ...requests.map(
            (booking) => _BookingRequestCard(
              booking: booking,
              isApproving: _isApproving,
              onApprove: () => _approve(booking),
              onReject: () => _reject(booking),
            ),
          ),
      ],
    );
  }

  Widget _buildRouteTimeline() {
    final ride = widget.ride;
    final stops = [ride.source, ride.destination];
    final colors = [AppTheme.primaryColor, AppTheme.errorColor];

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
                    if (index < stops.length - 1) Expanded(child: Container(width: 2, color: Colors.grey.shade300)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 6, bottom: index < stops.length - 1 ? 6 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stops[index],
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors[index]),
                    ),
                    if (index == 0) Text('Departure', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    if (index == stops.length - 1)
                      Text('Arrival', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
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

class _BookingRequestCard extends StatelessWidget {
  final BookingModel booking;
  final bool isApproving;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _BookingRequestCard({
    required this.booking,
    required this.isApproving,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = booking.status == 'pending';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      booking.riderName.isNotEmpty ? booking.riderName[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.riderName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      Text(
                        '${booking.seatsBooked} seat${booking.seatsBooked > 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: booking.status),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isApproving ? null : onReject,
                      icon: const Icon(Icons.close, size: 18),
                      label: Text(isApproving ? '...' : 'Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isApproving ? null : onApprove,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(isApproving ? '...' : 'Approve'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bg, label) = switch (status) {
      'pending' => (const Color(0xFFB4530A), const Color(0xFFFFF3E0), 'Pending'),
      'confirmed' => (const Color(0xFF1B5E20), const Color(0xFFE8F5E9), 'Approved'),
      'rejected' => (const Color(0xFFB71C1C), const Color(0xFFFFEBEE), 'Rejected'),
      'cancelled' => (const Color(0xFF455A64), const Color(0xFFECEFF1), 'Cancelled'),
      'completed' => (const Color(0xFF004D40), const Color(0xFFE0F2F1), 'Completed'),
      _ => (AppTheme.textSecondary, Colors.grey.shade200, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoChip({required this.icon, required this.label, required this.value});

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
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}

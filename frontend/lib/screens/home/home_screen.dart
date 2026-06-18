import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ride_provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/ride_model.dart';
import '../../models/booking_model.dart';
import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../rides/create_ride_screen.dart';
import '../rides/search_ride_screen.dart';
import '../rides/ride_detail_screen.dart';
import '../chat/chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final auth = context.read<AuthProvider>();
    await auth.init();
    final rideProv = context.read<RideProvider>();
    await rideProv.init();
    final chatProv = context.read<ChatProvider>();
    await chatProv.init();
    if (auth.currentUser != null) {
      await rideProv.seedDummyData(
        auth.currentUser!.id,
        auth.currentUser!.name,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final rideProv = context.watch<RideProvider>();
    final user = auth.currentUser;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hello, ${user?.name ?? 'User'}!',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user?.isGuest == true
                                      ? 'Guest Mode'
                                      : user?.isDriver == true
                                          ? 'Driver Mode'
                                          : 'Rider Mode',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.swap_horiz,
                                        color: Colors.white),
                                    tooltip: user?.isDriver == true
                                        ? 'Switch to Rider'
                                        : 'Switch to Driver',
                                    onPressed: () => auth.toggleDriverMode(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.logout,
                                        color: Colors.white),
                                    onPressed: () => auth.logout(),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.search,
                      label: 'Find a Ride',
                      color: AppTheme.secondaryColor,
                      gradientColors: const [Color(0xFF1E88E5), Color(0xFF1565C0)],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SearchRideScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.add_circle_outline,
                      label: 'Offer a Ride',
                      color: AppTheme.primaryColor,
                      gradientColors: const [Color(0xFF43A047), Color(0xFF2E7D32)],
                      onTap: () {
                        if (auth.currentUser?.isGuest == true) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CreateRideScreen()),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text(
                'My Rides',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
              ),
            ),
          ),
          _buildRidesList(context, user, rideProv),
        ],
      ),
    );
  }

  Widget _buildRidesList(
      BuildContext context, dynamic user, RideProvider rideProv) {
    final userId = user?.id ?? '';
    final userRides = rideProv.getUserRides(userId);
    final userBookings = rideProv.getUserBookings(userId);

    final completedRideIds = rideProv.completedRides.map((r) => r.id).toSet();

    final upcomingItems = <_RideItem>[];
    final completedItems = <_RideItem>[];

    for (final ride in userRides) {
      final item = _RideItem(ride: ride, isDriver: true, booking: null);
      if (completedRideIds.contains(ride.id)) {
        completedItems.add(item);
      } else {
        upcomingItems.add(item);
      }
    }

    for (final booking in userBookings) {
      final ride = rideProv.getRideById(booking.rideId);
      if (ride != null) {
        final item = _RideItem(ride: ride, isDriver: false, booking: booking);
        if (booking.status == 'completed') {
          completedItems.add(item);
        } else {
          upcomingItems.add(item);
        }
      }
    }

    final totalItems = upcomingItems.length + completedItems.length;

    if (totalItems == 0) {
      return SliverToBoxAdapter(
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(Icons.directions_car,
                    size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Text(
                  'No rides yet',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Find or offer a ride to get started',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        if (upcomingItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Text(
                  'Upcoming (${upcomingItems.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          ...upcomingItems.map((item) => _RideCard(
                item: item,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RideDetailScreen(ride: item.ride),
                  ),
                ),
                onChat: () => _openChat(context, item),
              )),
        ],
        if (completedItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 18, color: AppTheme.successColor),
                const SizedBox(width: 6),
                Text(
                  'Completed (${completedItems.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          ...completedItems.map((item) => _RideCard(
                item: item,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RideDetailScreen(ride: item.ride),
                  ),
                ),
                onChat: () => _openChat(context, item),
              )),
          const SizedBox(height: 16),
        ],
      ]),
    );
  }

  void _openChat(BuildContext context, _RideItem item) {
    final ride = item.ride;
    final chatPartnerName = item.isDriver
        ? item.booking?.riderName ?? 'Passenger'
        : ride.driverName;
    final chatPartnerId = item.isDriver
        ? item.booking?.riderId ?? ''
        : ride.driverId;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          ride: ride,
          chatPartnerName: chatPartnerName,
          chatPartnerId: chatPartnerId,
        ),
      ),
    );
  }
}

class _RideItem {
  final RideModel ride;
  final bool isDriver;
  final BookingModel? booking;

  const _RideItem({
    required this.ride,
    required this.isDriver,
    this.booking,
  });
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              children: [
                Icon(icon, size: 36, color: Colors.white),
                const SizedBox(height: 10),
                Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final _RideItem item;
  final VoidCallback onTap;
  final VoidCallback onChat;

  const _RideCard({
    required this.item,
    required this.onTap,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final ride = item.ride;
    final isCompleted = ride.status == 'completed';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: isCompleted
                ? Border.all(color: Colors.green.shade100)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isCompleted
                              ? [Colors.grey.shade400, Colors.grey.shade500]
                              : [AppTheme.primaryColor, AppTheme.primaryDark],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
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
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.isDriver ? 'You (Driver)' : ride.driverName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          if (ride.vehicleInfo.isNotEmpty)
                            Text(ride.vehicleInfo,
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.green.shade50
                            : AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCompleted ? 'Completed' : 'Upcoming',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? AppTheme.successColor
                              : AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _RouteTimeline(ride: ride),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(ride.dateTime),
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    if (!item.isDriver && item.booking != null) ...[
                      const SizedBox(width: 16),
                      Icon(Icons.event_seat,
                          size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${item.booking!.seatsBooked} seat(s)',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.grey.shade100
                            : AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.chat_bubble_outline,
                          size: 20,
                          color: isCompleted
                              ? Colors.grey.shade600
                              : AppTheme.primaryColor,
                        ),
                        onPressed: onChat,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: isCompleted ? 'View Chat' : 'Chat',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return 'Today, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }
}

class _RouteTimeline extends StatelessWidget {
  final RideModel ride;

  const _RouteTimeline({required this.ride});

  @override
  Widget build(BuildContext context) {
    final stops = [ride.source, ...ride.intermediateStops, ride.destination];
    final stopColors = [
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
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: stopColors[index],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: stopColors[index].withValues(alpha: 0.3),
                            blurRadius: 4,
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
              const SizedBox(width: 10),
              Padding(
                padding: EdgeInsets.only(
                  top: index == 0 ? 0 : 4,
                  bottom: index < stops.length - 1 ? 4 : 0,
                ),
                child: Text(
                  stops[index],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        index == 0 || index == stops.length - 1
                            ? FontWeight.w600
                            : FontWeight.normal,
                    color: stopColors[index],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

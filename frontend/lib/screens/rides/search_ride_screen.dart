import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ride_provider.dart';
import '../../models/ride_model.dart';
import '../../core/theme/app_theme.dart';
import 'ride_detail_screen.dart';

class SearchRideScreen extends StatefulWidget {
  const SearchRideScreen({super.key});

  @override
  State<SearchRideScreen> createState() => _SearchRideScreenState();
}

class _SearchRideScreenState extends State<SearchRideScreen> {
  final _sourceController = TextEditingController();
  final _destController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void dispose() {
    _sourceController.dispose();
    _destController.dispose();
    super.dispose();
  }

  void _search() {
    if (_sourceController.text.isEmpty || _destController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter source and destination')));
      return;
    }
    context.read<RideProvider>().searchRides(
      source: _sourceController.text.trim(),
      destination: _destController.text.trim(),
      currentUserId: context.read<AuthProvider>().currentUser?.id ?? '',
      date: _selectedDate,
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  @override
  Widget build(BuildContext context) {
    final rideProv = context.watch<RideProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Find a Ride')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: _sourceController,
                    decoration: const InputDecoration(
                      labelText: 'From',
                      prefixIcon: Icon(Icons.trip_origin, color: AppTheme.primaryColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Icon(Icons.arrow_downward, size: 20, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _destController,
                    decoration: const InputDecoration(
                      labelText: 'To',
                      prefixIcon: Icon(Icons.location_on, color: AppTheme.errorColor),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                            _selectedDate != null
                                ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                : 'Date (Optional)',
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _search,
                          icon: const Icon(Icons.search, size: 20),
                          label: const Text('Search'),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton.icon(
                        onPressed: () => setState(() => _selectedDate = null),
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Clear Date Filter'),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (rideProv.searchResults.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  '${rideProv.searchResults.length} ride${rideProv.searchResults.length > 1 ? 's' : ''} found',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
              ),
              ...rideProv.searchResults.map(
                (ride) => _RideSearchCard(
                  ride: ride,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailScreen(ride: ride))),
                ),
              ),
            ] else if (rideProv.searchResults.isEmpty &&
                (_sourceController.text.isNotEmpty || _destController.text.isNotEmpty)) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.search_off, size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'No rides found',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try changing the route or date',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RideSearchCard extends StatelessWidget {
  final RideModel ride;
  final VoidCallback onTap;

  const _RideSearchCard({required this.ride, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF43A047), Color(0xFF2E7D32)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        ride.driverName.isNotEmpty ? ride.driverName[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ride.driverName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        if (ride.vehicleInfo.isNotEmpty)
                          Text(ride.vehicleInfo, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SearchRouteTimeline(ride: ride),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${ride.seats} seat${ride.seats > 1 ? 's' : ''} left',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.access_time, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${ride.dateTime.day}/${ride.dateTime.month} ${ride.dateTime.hour.toString().padLeft(2, '0')}:${ride.dateTime.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchRouteTimeline extends StatelessWidget {
  final RideModel ride;

  const _SearchRouteTimeline({required this.ride});

  @override
  Widget build(BuildContext context) {
    final stops = [ride.source, ride.destination];
    final stopColors = [AppTheme.primaryColor, AppTheme.errorColor];

    return Column(
      children: List.generate(stops.length, (index) {
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: stopColors[index],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: stopColors[index].withValues(alpha: 0.3), blurRadius: 4)],
                      ),
                    ),
                    if (index < stops.length - 1) Expanded(child: Container(width: 1.5, color: Colors.grey.shade300)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 4, bottom: index < stops.length - 1 ? 4 : 0),
                child: Text(
                  stops[index],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: index == 0 || index == stops.length - 1 ? FontWeight.w600 : FontWeight.normal,
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ride_provider.dart';
import '../../models/ride_model.dart';
import '../../models/vehicle_model.dart';
import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sourceController = TextEditingController();
  final _destController = TextEditingController();
  final _fareController = TextEditingController();
  final _stopsController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 2));
  TimeOfDay _selectedTime = TimeOfDay(
    hour: DateTime.now().hour + 2,
    minute: 0,
  );
  int _availableSeats = 3;
  int _totalSeats = 4;
  bool _showVehicleForm = false;
  final _uuid = const Uuid();

  @override
  void dispose() {
    _sourceController.dispose();
    _destController.dispose();
    _fareController.dispose();
    _stopsController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: _selectedTime);
    if (time != null) setState(() => _selectedTime = time);
  }

  Future<void> _publishRide() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final rideProv = context.read<RideProvider>();
    final user = auth.currentUser;

    if (user == null) return;

    String? vehicleId;
    if (_showVehicleForm) {
      vehicleId = _uuid.v4();
      final vehicle = VehicleModel(
        id: vehicleId,
        userId: user.id,
        make: _makeController.text.trim(),
        model: _modelController.text.trim(),
        year: _yearController.text.trim(),
        color: _colorController.text.trim(),
        licensePlate: _plateController.text.trim(),
        seats: _totalSeats,
      );
      rideProv.addVehicle(vehicle);
    }

    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final ride = RideModel(
      id: _uuid.v4(),
      driverId: user.id,
      driverName: user.name,
      vehicleId: vehicleId ?? '',
      vehicleInfo:
          _showVehicleForm ? '${_makeController.text} ${_modelController.text}' : '',
      source: _sourceController.text.trim(),
      destination: _destController.text.trim(),
      intermediateStops: _stopsController.text.isNotEmpty
          ? _stopsController.text.split(',').map((e) => e.trim()).toList()
          : [],
      dateTime: dateTime,
      availableSeats: _availableSeats,
      totalSeats: _totalSeats,
      farePerSeat: double.parse(_fareController.text.trim()),
    );

    rideProv.createRide(ride);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ride published successfully!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.currentUser?.isGuest == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Offer a Ride')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.route,
                              color: AppTheme.primaryColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Route Details',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _sourceController,
                      decoration: const InputDecoration(
                        labelText: 'Start Location',
                        prefixIcon:
                            Icon(Icons.trip_origin, color: AppTheme.primaryColor),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Source is required' : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Column(
                            children: List.generate(3, (i) => Container(
                              width: 3,
                              height: 3,
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              decoration: const BoxDecoration(
                                color: AppTheme.accentColor,
                                shape: BoxShape.circle,
                              ),
                            )),
                          ),
                          const SizedBox(width: 16),
                          Text('Intermediate checkpoints below',
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    TextFormField(
                      controller: _destController,
                      decoration: const InputDecoration(
                        labelText: 'Destination',
                        prefixIcon: Icon(Icons.location_on, color: AppTheme.errorColor),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Destination is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _stopsController,
                      decoration: const InputDecoration(
                        labelText: 'Route Checkpoints',
                        hintText: 'e.g. Koramangala, HSR Layout, Silk Board',
                        prefixIcon: Icon(Icons.flag_outlined,
                            color: AppTheme.accentColor),
                      ),
                    ),
                    if (_stopsController.text.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _RoutePreview(
                          source: _sourceController.text,
                          destination: _destController.text,
                          stops: _stopsController.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.schedule,
                              color: AppTheme.secondaryColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Schedule',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickTime,
                            icon: const Icon(Icons.access_time, size: 18),
                            label: Text(
                              _selectedTime.format(context),
                              style: const TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.event_seat,
                              color: AppTheme.accentColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Seats & Fare',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Available Seats',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13)),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      onPressed: _availableSeats > 1
                                          ? () => setState(
                                              () => _availableSeats--)
                                          : null,
                                      icon: const Icon(
                                          Icons.remove_circle_outline),
                                    ),
                                    Text('$_availableSeats',
                                        style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold)),
                                    IconButton(
                                      onPressed: _availableSeats < _totalSeats
                                          ? () => setState(
                                              () => _availableSeats++)
                                          : null,
                                      icon: const Icon(Icons.add_circle_outline),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _fareController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Fare per seat',
                              prefixText: '₹ ',
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? 'Fare is required'
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
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
                child: SwitchListTile(
                  title: const Text('Add Vehicle Details'),
                  subtitle: const Text('Optional but recommended'),
                  value: _showVehicleForm,
                  onChanged: (v) => setState(() => _showVehicleForm = v),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              if (_showVehicleForm) ...[
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
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _makeController,
                              decoration: const InputDecoration(
                                  labelText: 'Make (e.g. Toyota)'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _modelController,
                              decoration: const InputDecoration(
                                  labelText: 'Model (e.g. Camry)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _yearController,
                              decoration:
                                  const InputDecoration(labelText: 'Year'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _colorController,
                              decoration:
                                  const InputDecoration(labelText: 'Color'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _plateController,
                        decoration:
                            const InputDecoration(labelText: 'License Plate'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _publishRide,
                  icon: const Icon(Icons.publish),
                  label: const Text('Publish Ride',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutePreview extends StatelessWidget {
  final String source;
  final String destination;
  final List<String> stops;

  const _RoutePreview({
    required this.source,
    required this.destination,
    required this.stops,
  });

  @override
  Widget build(BuildContext context) {
    final allPoints = [source, ...stops, destination];
    final colors = [
      AppTheme.primaryColor,
      ...List.filled(stops.length, AppTheme.accentColor),
      AppTheme.errorColor,
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Route Preview:',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          ...List.generate(allPoints.length, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors[index],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(allPoints[index],
                      style: TextStyle(fontSize: 12, color: colors[index])),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

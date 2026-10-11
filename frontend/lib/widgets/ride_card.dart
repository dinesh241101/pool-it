import 'package:flutter/material.dart';
import '../models/ride_model.dart';
import '../core/theme/app_theme.dart';

class RideCard extends StatelessWidget {
  final RideModel ride;
  final VoidCallback? onTap;

  const RideCard({super.key, required this.ride, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryColor,
                    radius: 20,
                    child: Text(
                      ride.driverName.isNotEmpty ? ride.driverName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                  const Icon(Icons.pets, color: AppTheme.accentColor, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.trip_origin, size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(ride.source, style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.more_vert, size: 16, color: Colors.grey),
              ),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: AppTheme.errorColor),
                  const SizedBox(width: 8),
                  Text(ride.destination, style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.event_seat, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text('${ride.seats} seats available', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  const Spacer(),
                  const Icon(Icons.access_time, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${ride.dateTime.day}/${ride.dateTime.month} ${ride.dateTime.hour}:${ride.dateTime.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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

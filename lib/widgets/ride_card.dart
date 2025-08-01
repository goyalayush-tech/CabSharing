import 'package:flutter/material.dart';
import '../models/ride_group.dart';
import '../models/user_profile.dart';
import 'user_avatar.dart';

class RideCard extends StatelessWidget {
  final RideGroup ride;
  final UserProfile? leaderProfile;
  final VoidCallback? onTap;

  const RideCard({
    super.key,
    required this.ride,
    this.leaderProfile,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Route Information
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.my_location, color: Colors.green, size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                ride.pickupLocation,
                                style: Theme.of(context).textTheme.bodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.red, size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                ride.destination,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${ride.pricePerPerson.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('per person'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Time and Seats
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${ride.scheduledTime.day}/${ride.scheduledTime.month} at ${ride.scheduledTime.hour}:${ride.scheduledTime.minute.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Icon(Icons.airline_seat_recline_normal, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${ride.availableSeats}/${ride.totalSeats} seats',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Leader and Tags
              Row(
                children: [
                  if (leaderProfile != null) ...[
                    UserAvatarWidget(
                      imageUrl: leaderProfile!.profileImageUrl,
                      name: leaderProfile!.name,
                      radius: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            leaderProfile!.name,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                leaderProfile!.averageRating.toStringAsFixed(1),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (ride.femaleOnly) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.pink.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.woman, size: 12, color: Colors.pink.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'Female Only',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.pink.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
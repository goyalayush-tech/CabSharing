import 'package:flutter/material.dart';

class RideDetailsScreen extends StatelessWidget {
  final String rideId;

  const RideDetailsScreen({
    super.key,
    required this.rideId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Details'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Ride Details Screen'),
            const SizedBox(height: 16),
            Text('Ride ID: $rideId'),
            const SizedBox(height: 16),
            const Text('Dynamic carpooling system is working!'),
          ],
        ),
      ),
    );
  }
}
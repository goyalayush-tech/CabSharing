import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ride_group.dart';
import '../../models/user_profile.dart';
import '../../providers/ride_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/free_map_widget.dart';
import '../../services/notification_service.dart';
import '../../services/free_routing_service.dart';
import 'join_requests_screen.dart';

class RideDetailsScreen extends StatefulWidget {
  final String rideId;

  const RideDetailsScreen({
    super.key,
    required this.rideId,
  });

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  UserProfile? _leaderProfile;
  List<UserProfile> _memberProfiles = [];
  bool _isLoading = false;
  bool _hasRequested = false;
  List<LatLng>? _routePolyline;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final rideProvider = context.read<RideProvider>();
      final ride = await rideProvider.getRide(widget.rideId);
      
      if (ride != null && mounted) {
        await _loadUserProfiles(ride);
        await _loadRoute(ride);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load ride details: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserProfiles(RideGroup ride) async {
    if (!mounted) return;
    
    try {
      final userProvider = context.read<UserProvider>();
      
      // Load leader profile
      final leaderProfiles = await userProvider.searchUsers(ride.leaderId);
      if (leaderProfiles.isNotEmpty && mounted) {
        setState(() {
          _leaderProfile = leaderProfiles.first;
        });
      }

      // Load member profiles
      final memberProfiles = <UserProfile>[];
      for (final memberId in ride.memberIds) {
        final profiles = await userProvider.searchUsers(memberId);
        if (profiles.isNotEmpty) {
          memberProfiles.add(profiles.first);
        }
      }
      
      if (mounted) {
        setState(() {
          _memberProfiles = memberProfiles;
        });
      }

      // Check if current user has already requested to join
      final authProvider = context.read<AuthProvider>();
      final currentUserId = authProvider.user?.uid;
      if (currentUserId != null && mounted) {
        setState(() {
          _hasRequested = ride.joinRequests
              .any((request) => request.userId == currentUserId && request.status == 'pending');
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user profiles: $e')),
        );
      }
    }
  }

  Future<void> _loadRoute(RideGroup ride) async {
    if (!mounted) return;
    
    try {
      // Try to get the routing service from context
      final routingService = context.read<IFreeRoutingService>();
      final routeInfo = await routingService.calculateRoute(
        ride.pickupCoordinates,
        ride.destinationCoordinates,
      );
      
      if (mounted) {
        setState(() {
          _routePolyline = routeInfo.polylinePoints;
        });
      }
    } catch (e) {
      // Route loading failed, continue without route visualization
      debugPrint('Failed to load route: $e');
    }
  }

  Future<void> _requestToJoin(RideGroup ride) async {
    if (!mounted) return;
    
    final authProvider = context.read<AuthProvider>();
    final rideProvider = context.read<RideProvider>();
    final userProvider = context.read<UserProvider>();
    final notificationService = context.read<INotificationService>();
    final currentUser = authProvider.user;

    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await rideProvider.requestToJoin(ride.id, currentUser.uid);
      
      // Get current user's profile for notification
      final userProfiles = await userProvider.searchUsers(currentUser.uid);
      final userName = userProfiles.isNotEmpty ? userProfiles.first.name : 'Someone';
      
      // Send notification to ride leader
      await notificationService.sendJoinRequestNotification(
        ride.leaderId,
        ride.destination,
        userName,
      );
      
      if (mounted) {
        setState(() {
          _hasRequested = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Join request sent successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send join request: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _canJoinRide(RideGroup ride) {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.user;
    
    if (currentUser == null) return false;
    if (ride.leaderId == currentUser.uid) return false;
    if (ride.memberIds.contains(currentUser.uid)) return false;
    if (ride.availableSeats <= 0) return false;
    if (_hasRequested) return false;
    if (ride.status != RideStatus.created) return false;
    
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final rideProvider = context.read<RideProvider>();
    final currentUser = authProvider.user;

    return StreamBuilder<RideGroup?>(
      stream: rideProvider.getRideStream(widget.rideId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ride Details')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _loadInitialData(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final ride = snapshot.data;
        if (ride == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ride Details')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Ride not found'),
                ],
              ),
            ),
          );
        }

        // Update user profiles when ride data changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadUserProfiles(ride);
        });

        final isLeader = currentUser?.uid == ride.leaderId;
        final pendingRequestsCount = ride.joinRequests
            .where((request) => request.status == 'pending')
            .length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Ride Details'),
            actions: [
              if (isLeader && pendingRequestsCount > 0)
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => JoinRequestsScreen(ride: ride),
                      ),
                    );
                  },
                  icon: Stack(
                    children: [
                      const Icon(Icons.person_add),
                      if (pendingRequestsCount > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$pendingRequestsCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Route Information
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.my_location, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      ride.pickupLocation,
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      ride.destination,
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.schedule),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${ride.scheduledTime.day}/${ride.scheduledTime.month}/${ride.scheduledTime.year} at ${ride.scheduledTime.hour}:${ride.scheduledTime.minute.toString().padLeft(2, '0')}',
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Route Map
                      Card(
                        child: Container(
                          height: 200,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: FreeMapWidget(
                              initialLocation: ride.pickupCoordinates,
                              markers: [
                                MapMarkerData(
                                  coordinates: ride.pickupCoordinates,
                                  type: MapMarkerType.pickup,
                                  title: 'Pickup',
                                  subtitle: ride.pickupLocation,
                                ),
                                MapMarkerData(
                                  coordinates: ride.destinationCoordinates,
                                  type: MapMarkerType.destination,
                                  title: 'Destination',
                                  subtitle: ride.destination,
                                ),
                              ],
                              polylinePoints: _routePolyline,
                              allowLocationSelection: false,
                              showCurrentLocation: false,
                              showZoomControls: true,
                              initialZoom: 12.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Ride Information
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ride Information',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Available Seats'),
                                      Text(
                                        '${ride.availableSeats}/${ride.totalSeats}',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Price per Person'),
                                      Text(
                                        '\$${ride.pricePerPerson.toStringAsFixed(2)}',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: Theme.of(context).primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (ride.femaleOnly) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.pink.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.pink.shade200),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.woman, color: Colors.pink),
                                      SizedBox(width: 8),
                                      Text('Female Only Ride'),
                                    ],
                                  ),
                                ),
                              ],
                              if (ride.notes != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'Notes',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(ride.notes!),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Leader Information
                      if (_leaderProfile != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ride Leader',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    UserAvatar(
                                      imageUrl: _leaderProfile!.profileImageUrl,
                                      name: _leaderProfile!.name,
                                      radius: 30,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _leaderProfile!.name,
                                            style: Theme.of(context).textTheme.titleMedium,
                                          ),
                                          Row(
                                            children: [
                                              const Icon(Icons.star, color: Colors.amber, size: 16),
                                              const SizedBox(width: 4),
                                              Text('${_leaderProfile!.averageRating.toStringAsFixed(1)}'),
                                              const SizedBox(width: 8),
                                              Text('(${_leaderProfile!.totalRides} rides)'),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Members
                      if (_memberProfiles.isNotEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Members (${_memberProfiles.length})',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                ..._memberProfiles.map((member) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      UserAvatar(
                                        imageUrl: member.profileImageUrl,
                                        name: member.name,
                                        radius: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(member.name),
                                            Row(
                                              children: [
                                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                                const SizedBox(width: 4),
                                                Text(
                                                  member.averageRating.toStringAsFixed(1),
                                                  style: Theme.of(context).textTheme.bodySmall,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          ),
                        ),

                      // Join Requests (for leaders only)
                      if (isLeader && pendingRequestsCount > 0)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Pending Join Requests',
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$pendingRequestsCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => JoinRequestsScreen(ride: ride),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.person_add),
                                  label: const Text('Manage Requests'),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
          bottomNavigationBar: _canJoinRide(ride)
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _requestToJoin(ride),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Request to Join'),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
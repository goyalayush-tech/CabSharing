import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ride_group.dart';
import '../../models/user_profile.dart';
import '../../providers/ride_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/user_avatar.dart';
import '../../services/notification_service.dart';

class JoinRequestsScreen extends StatefulWidget {
  final RideGroup ride;

  const JoinRequestsScreen({
    super.key,
    required this.ride,
  });

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen> {
  List<JoinRequestWithProfile> _joinRequests = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadJoinRequests();
  }

  Future<void> _loadJoinRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = context.read<UserProvider>();
      final joinRequestsWithProfiles = <JoinRequestWithProfile>[];

      for (final request in widget.ride.joinRequests) {
        if (request.status == 'pending') {
          final profiles = await userProvider.searchUsers(request.userId);
          if (profiles.isNotEmpty) {
            joinRequestsWithProfiles.add(
              JoinRequestWithProfile(
                request: request,
                profile: profiles.first,
              ),
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _joinRequests = joinRequestsWithProfiles;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load join requests: $e')),
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

  Future<void> _approveRequest(JoinRequest request) async {
    final rideProvider = context.read<RideProvider>();
    
    setState(() {
      _isLoading = true;
    });

    try {
      await rideProvider.approveJoinRequest(widget.ride.id, request.userId);
      
      // Send notification to the user
      await _sendNotification(
        request.userId,
        'Join Request Approved',
        'Your request to join the ride to ${widget.ride.destination} has been approved!',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Join request approved successfully!')),
        );
        
        // Remove the approved request from the list
        setState(() {
          _joinRequests.removeWhere((jr) => jr.request.id == request.id);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve request: $e')),
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

  Future<void> _rejectRequest(JoinRequest request, String reason) async {
    final rideProvider = context.read<RideProvider>();
    
    setState(() {
      _isLoading = true;
    });

    try {
      await rideProvider.rejectJoinRequest(widget.ride.id, request.userId, reason);
      
      // Send notification to the user
      await _sendNotification(
        request.userId,
        'Join Request Declined',
        'Your request to join the ride to ${widget.ride.destination} has been declined.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Join request rejected successfully!')),
        );
        
        // Remove the rejected request from the list
        setState(() {
          _joinRequests.removeWhere((jr) => jr.request.id == request.id);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject request: $e')),
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

  Future<void> _sendNotification(String userId, String title, String body) async {
    try {
      // In a real implementation, you would send this through your backend
      // For now, we'll just log it
      debugPrint('Sending notification to $userId: $title - $body');
    } catch (e) {
      debugPrint('Failed to send notification: $e');
    }
  }

  void _showRejectDialog(JoinRequest request) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Join Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejecting this request:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Reason for rejection...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _rejectRequest(request, reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Requests'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _joinRequests.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No pending join requests',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _joinRequests.length,
                  itemBuilder: (context, index) {
                    final joinRequestWithProfile = _joinRequests[index];
                    final request = joinRequestWithProfile.request;
                    final profile = joinRequestWithProfile.profile;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                UserAvatar(
                                  imageUrl: profile.profileImageUrl,
                                  name: profile.name,
                                  radius: 30,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile.name,
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.star, color: Colors.amber, size: 16),
                                          const SizedBox(width: 4),
                                          Text(profile.averageRating.toStringAsFixed(1)),
                                          const SizedBox(width: 8),
                                          Text('(${profile.totalRides} rides)'),
                                        ],
                                      ),
                                      if (profile.isVerified) ...[
                                        const SizedBox(height: 4),
                                        const Row(
                                          children: [
                                            Icon(Icons.verified, color: Colors.blue, size: 16),
                                            SizedBox(width: 4),
                                            Text('Verified', style: TextStyle(color: Colors.blue)),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Bio: ${profile.bio}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              'Requested: ${_formatDateTime(request.createdAt)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _isLoading ? null : () => _showRejectDialog(request),
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    label: const Text('Reject'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoading ? null : () => _approveRequest(request),
                                    icon: const Icon(Icons.check),
                                    label: const Text('Approve'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}

class JoinRequestWithProfile {
  final JoinRequest request;
  final UserProfile profile;

  JoinRequestWithProfile({
    required this.request,
    required this.profile,
  });
}
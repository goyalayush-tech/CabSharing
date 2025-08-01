import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/user_avatar.dart';
import '../../core/errors/app_error.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    
    if (authProvider.user != null) {
      userProvider.loadUserProfile(authProvider.user!.uid);
    }
  }

  void _showErrorSnackBar(AppError error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_getErrorMessage(error)),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _loadProfile,
        ),
      ),
    );
  }

  String _getErrorMessage(AppError error) {
    switch (error.type) {
      case ErrorType.network:
        return 'Network error: ${error.message}';
      case ErrorType.auth:
        return 'Authentication error: ${error.message}';
      default:
        return 'Error: ${error.message}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          Consumer<UserProvider>(
            builder: (context, userProvider, child) {
              if (userProvider.hasProfile) {
                return IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _navigateToEditProfile(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          if (userProvider.error != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showErrorSnackBar(userProvider.error!);
              userProvider.clearError();
            });
          }

          if (userProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!userProvider.hasProfile) {
            return _buildCreateProfilePrompt();
          }

          return _buildProfileContent(userProvider);
        },
      ),
    );
  }

  Widget _buildCreateProfilePrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Complete Your Profile',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add your details to start connecting with other riders',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _navigateToEditProfile,
              icon: const Icon(Icons.edit),
              label: const Text('Create Profile'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(UserProvider userProvider) {
    final profile = userProvider.currentUserProfile!;
    
    return RefreshIndicator(
      onRefresh: () => userProvider.refreshProfile(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildProfileHeader(profile),
            const SizedBox(height: 24),
            _buildProfileStats(profile),
            const SizedBox(height: 24),
            _buildProfileDetails(profile),
            const SizedBox(height: 24),
            _buildRecentRatings(userProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            UserAvatar(
              imageUrl: profile.profileImageUrl,
              name: profile.name,
              radius: 50,
            ),
            const SizedBox(height: 16),
            Text(
              profile.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  profile.averageRating.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                if (profile.isVerified)
                  Icon(
                    Icons.verified,
                    color: Colors.blue,
                    size: 20,
                  ),
              ],
            ),
            if (profile.bio != null && profile.bio!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                profile.bio!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileStats(profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.directions_car,
              label: 'Rides',
              value: profile.totalRides.toString(),
            ),
            _buildStatItem(
              icon: Icons.star,
              label: 'Rating',
              value: profile.averageRating.toStringAsFixed(1),
            ),
            _buildStatItem(
              icon: Icons.calendar_today,
              label: 'Member Since',
              value: _formatMemberSince(profile.createdAt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileDetails(profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              icon: Icons.email,
              label: 'Email',
              value: profile.email,
            ),
            if (profile.phoneNumber != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.phone,
                label: 'Phone',
                value: profile.phoneNumber!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentRatings(UserProvider userProvider) {
    final ratings = userProvider.userRatings;
    
    if (ratings.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Reviews',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...ratings.take(3).map((rating) => _buildRatingItem(rating)),
            if (ratings.length > 3) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _showAllRatings(ratings),
                child: Text('View all ${ratings.length} reviews'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRatingItem(rating) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < rating.stars ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 16,
              );
            }),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rating.hasComment)
                  Text(
                    rating.comment!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(rating.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToEditProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const EditProfileScreen(),
      ),
    );
  }

  void _showAllRatings(List ratings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                'All Reviews',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: ratings.length,
                  itemBuilder: (context, index) => _buildRatingItem(ratings[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMemberSince(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays < 30) {
      return '${difference.inDays}d';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}mo';
    } else {
      return '${(difference.inDays / 365).floor()}y';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
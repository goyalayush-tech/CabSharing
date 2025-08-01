import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ride_provider.dart';
import '../../providers/user_provider.dart';
import '../../screens/rides/create_ride_screen.dart';
import '../../screens/rides/ride_details_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../widgets/ride_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const _HomeTab(),
      const _MyRidesTab(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'My Rides',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CreateRideScreen(),
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _searchController = TextEditingController();
  bool _showFilters = false;
  bool _femaleOnlyFilter = false;
  DateTime? _dateFilter;

  @override
  void initState() {
    super.initState();
    _loadNearbyRides();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadNearbyRides() {
    final rideProvider = context.read<RideProvider>();
    // Load rides near a default location (in a real app, you'd use user's location)
    rideProvider.loadNearbyRides(40.7128, -74.0060); // NYC coordinates
  }

  void _searchRides() {
    final rideProvider = context.read<RideProvider>();
    final criteria = <String, dynamic>{};
    
    if (_searchController.text.isNotEmpty) {
      criteria['destination'] = _searchController.text;
    }
    
    if (_femaleOnlyFilter) {
      criteria['femaleOnly'] = true;
    }
    
    if (_dateFilter != null) {
      criteria['date'] = _dateFilter;
    }
    
    rideProvider.searchRides(criteria);
  }

  void _clearSearch() {
    _searchController.clear();
    _femaleOnlyFilter = false;
    _dateFilter = null;
    _showFilters = false;
    
    final rideProvider = context.read<RideProvider>();
    rideProvider.clearSearchResults();
    _loadNearbyRides();
    
    setState(() {});
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (date != null) {
      setState(() {
        _dateFilter = date;
      });
      _searchRides();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Rides'),
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Where are you going?',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {});
                    if (value.isNotEmpty) {
                      _searchRides();
                    } else {
                      _clearSearch();
                    }
                  },
                ),
                
                // Filters
                if (_showFilters) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filters',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Female Only Filter
                          CheckboxListTile(
                            title: const Text('Female Only'),
                            subtitle: const Text('Show only female-only rides'),
                            value: _femaleOnlyFilter,
                            onChanged: (value) {
                              setState(() {
                                _femaleOnlyFilter = value ?? false;
                              });
                              _searchRides();
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                          
                          // Date Filter
                          ListTile(
                            title: const Text('Date'),
                            subtitle: Text(_dateFilter == null 
                                ? 'Any date' 
                                : '${_dateFilter!.day}/${_dateFilter!.month}/${_dateFilter!.year}'),
                            trailing: _dateFilter != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        _dateFilter = null;
                                      });
                                      _searchRides();
                                    },
                                  )
                                : const Icon(Icons.calendar_today),
                            onTap: _selectDate,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Rides List
          Expanded(
            child: Consumer<RideProvider>(
              builder: (context, rideProvider, child) {
                final rides = _searchController.text.isNotEmpty || _showFilters
                    ? rideProvider.searchResults
                    : rideProvider.nearbyRides;

                if (rideProvider.isSearching || rideProvider.isLoadingNearby) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (rideProvider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading rides',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(rideProvider.error!.message),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            rideProvider.clearError();
                            _loadNearbyRides();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (rides.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.directions_car_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'No rides found'
                              : 'No nearby rides',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'Try adjusting your search or filters'
                              : 'Be the first to create a ride!',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    if (_searchController.text.isNotEmpty || _showFilters) {
                      _searchRides();
                    } else {
                      _loadNearbyRides();
                    }
                  },
                  child: ListView.builder(
                    itemCount: rides.length,
                    itemBuilder: (context, index) {
                      final ride = rides[index];
                      return Consumer<UserProvider>(
                        builder: (context, userProvider, child) {
                          return FutureBuilder(
                            future: userProvider.searchUsers(ride.leaderId),
                            builder: (context, snapshot) {
                              final leaderProfile = snapshot.data?.isNotEmpty == true
                                  ? snapshot.data!.first
                                  : null;
                              
                              return RideCard(
                                ride: ride,
                                leaderProfile: leaderProfile,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => RideDetailsScreen(ride: ride),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MyRidesTab extends StatefulWidget {
  const _MyRidesTab();

  @override
  State<_MyRidesTab> createState() => _MyRidesTabState();
}

class _MyRidesTabState extends State<_MyRidesTab> {
  @override
  void initState() {
    super.initState();
    _loadUserRides();
  }

  void _loadUserRides() {
    final authProvider = context.read<AuthProvider>();
    final rideProvider = context.read<RideProvider>();
    
    if (authProvider.user != null) {
      rideProvider.loadUserRides(authProvider.user!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Rides'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        body: Consumer<RideProvider>(
          builder: (context, rideProvider, child) {
            if (rideProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (rideProvider.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading rides',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(rideProvider.error!.message),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        rideProvider.clearError();
                        _loadUserRides();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            return TabBarView(
              children: [
                // Upcoming Rides
                _buildRidesList(
                  rideProvider.upcomingRides,
                  'No upcoming rides',
                  'Your upcoming rides will appear here',
                ),
                
                // Completed Rides
                _buildRidesList(
                  rideProvider.completedRides,
                  'No completed rides',
                  'Your ride history will appear here',
                ),
                
                // Cancelled Rides
                _buildRidesList(
                  rideProvider.cancelledRides,
                  'No cancelled rides',
                  'Cancelled rides will appear here',
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRidesList(List rides, String emptyTitle, String emptySubtitle) {
    if (rides.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              emptySubtitle,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadUserRides(),
      child: ListView.builder(
        itemCount: rides.length,
        itemBuilder: (context, index) {
          final ride = rides[index];
          return Consumer<UserProvider>(
            builder: (context, userProvider, child) {
              return FutureBuilder(
                future: userProvider.searchUsers(ride.leaderId),
                builder: (context, snapshot) {
                  final leaderProfile = snapshot.data?.isNotEmpty == true
                      ? snapshot.data!.first
                      : null;
                  
                  return RideCard(
                    ride: ride,
                    leaderProfile: leaderProfile,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => RideDetailsScreen(ride: ride),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}


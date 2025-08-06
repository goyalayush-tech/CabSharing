import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../free_map_widget.dart';
import '../offline_banner.dart';
import '../../services/offline_service.dart';
import '../../services/map_cache_service.dart';
import '../../models/ride_group.dart';

/// Example demonstrating offline map functionality
class OfflineMapExample extends StatefulWidget {
  const OfflineMapExample({super.key});

  @override
  State<OfflineMapExample> createState() => _OfflineMapExampleState();
}

class _OfflineMapExampleState extends State<OfflineMapExample> {
  late IOfflineService _offlineService;
  late IMapCacheService _cacheService;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _offlineService = OfflineService();
    _cacheService = HiveMapCacheService();
    
    await _offlineService.initialize();
    await _cacheService.initialize();
    
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _offlineService.dispose();
    _cacheService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Map Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showOfflineInfo(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline status banner
          OfflineBanner(
            offlineService: _offlineService,
            onRetry: () => _offlineService.refreshConnectivity(),
            customMessage: 'Offline mode: Using cached map tiles',
          ),
          
          // Connection status card
          _buildConnectionStatusCard(),
          
          // Map with offline support
          Expanded(
            child: FreeMapWidget(
              initialLocation: const LatLng(37.7749, -122.4194), // San Francisco
              markers: [
                MapMarkerData(
                  coordinates: const LatLng(37.7749, -122.4194),
                  type: MapMarkerType.pickup,
                  title: 'San Francisco',
                  subtitle: 'Demo location',
                ),
                MapMarkerData(
                  coordinates: const LatLng(37.7849, -122.4094),
                  type: MapMarkerType.destination,
                  title: 'Nearby Location',
                  subtitle: 'Another demo point',
                ),
              ],
              offlineService: _offlineService,
              cacheService: _cacheService,
              showOfflineBanner: false, // Using top-level banner
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Cache stats button
          FloatingActionButton.extended(
            heroTag: 'cache_stats',
            onPressed: () => _showCacheStats(context),
            icon: const Icon(Icons.storage),
            label: const Text('Cache Stats'),
          ),
          const SizedBox(height: 16),
          
          // Clear cache button
          FloatingActionButton.extended(
            heroTag: 'clear_cache',
            onPressed: () => _clearCache(context),
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear Cache'),
            backgroundColor: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatusCard() {
    return StreamBuilder<bool>(
      stream: _offlineService.connectivityStream,
      initialData: _offlineService.isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isOnline ? Colors.green.shade50 : Colors.orange.shade50,
            border: Border.all(
              color: isOnline ? Colors.green.shade200 : Colors.orange.shade200,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                isOnline ? Icons.wifi : Icons.wifi_off,
                color: isOnline ? Colors.green.shade700 : Colors.orange.shade700,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isOnline ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                    ),
                    Text(
                      isOnline 
                          ? 'All features available'
                          : 'Using cached data only',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOnline ? Colors.green.shade600 : Colors.orange.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _offlineService.refreshConnectivity(),
                child: const Text('Refresh'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOfflineInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Offline Functionality'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This demo shows how the app works offline:'),
            SizedBox(height: 12),
            Text('• Map tiles are cached for offline viewing'),
            Text('• Markers and routes work with cached data'),
            Text('• Search and location services are disabled offline'),
            Text('• Automatic reconnection when back online'),
            SizedBox(height: 12),
            Text(
              'Try turning off your internet connection to see offline mode in action!',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCacheStats(BuildContext context) async {
    final stats = await _cacheService.getCacheStats();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cache Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Map Tiles', '${stats['tiles_count'] ?? 0}'),
            _buildStatRow('Geocoding Results', '${stats['geocoding_count'] ?? 0}'),
            _buildStatRow('Cached Routes', '${stats['routes_count'] ?? 0}'),
            _buildStatRow('Tiles Size', '${_formatBytes(stats['tiles_size_bytes'] ?? 0)}'),
            const SizedBox(height: 12),
            const Text(
              'Cache helps the app work offline and improves performance.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  Future<void> _clearCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will remove all cached map tiles, geocoding results, and routes. '
          'The app will need to download data again when online.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cacheService.clearAllCache();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
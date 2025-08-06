import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/map_service_monitor.dart';
import '../../services/free_geocoding_service.dart';
import '../../services/free_routing_service.dart';
import '../analytics_dashboard.dart';

/// Example widget demonstrating comprehensive monitoring integration
class MonitoringIntegrationExample extends StatefulWidget {
  const MonitoringIntegrationExample({super.key});

  @override
  State<MonitoringIntegrationExample> createState() => _MonitoringIntegrationExampleState();
}

class _MonitoringIntegrationExampleState extends State<MonitoringIntegrationExample> {
  final MapServiceMonitor _monitor = MapServiceMonitor();
  final FreeGeocodingService _geocodingService = FreeGeocodingService();
  final FreeRoutingService _routingService = FreeRoutingService();
  
  bool _isInitialized = false;
  Map<String, dynamic>? _currentStatus;
  List<Map<String, dynamic>> _alerts = [];
  
  @override
  void initState() {
    super.initState();
    _initializeMonitoring();
  }

  @override
  void dispose() {
    _monitor.shutdown();
    super.dispose();
  }

  Future<void> _initializeMonitoring() async {
    await _monitor.initialize();
    
    // Listen for alerts
    _monitor.addListener(_onMonitoringUpdate);
    
    setState(() {
      _isInitialized = true;
    });
    
    // Update status periodically
    _updateStatus();
  }

  void _onMonitoringUpdate() {
    _updateStatus();
  }

  void _updateStatus() {
    if (mounted) {
      final status = _monitor.getServiceStatus();
      setState(() {
        _currentStatus = status;
        _alerts = List<Map<String, dynamic>>.from(status['alerts'] ?? []);
      });
    }
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
        title: const Text('Monitoring Integration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _showAnalyticsDashboard,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _updateStatus,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAlertsSection(),
            const SizedBox(height: 24),
            _buildQuickStatsSection(),
            const SizedBox(height: 24),
            _buildTestOperationsSection(),
            const SizedBox(height: 24),
            _buildReportsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _alerts.isEmpty ? Icons.check_circle : Icons.warning,
                  color: _alerts.isEmpty ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'System Alerts',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_alerts.isEmpty)
              const Text('No active alerts')
            else
              ..._alerts.map((alert) => _buildAlertTile(alert)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertTile(Map<String, dynamic> alert) {
    final severity = alert['severity'] as String;
    final color = severity == 'critical' ? Colors.red : Colors.orange;
    
    return ListTile(
      leading: Icon(Icons.warning, color: color),
      title: Text(alert['message'] as String),
      subtitle: Text('Type: ${alert['type']} | ${alert['timestamp']}'),
      trailing: Chip(
        label: Text(severity.toUpperCase()),
        backgroundColor: color.withOpacity(0.2),
        labelStyle: TextStyle(color: color),
      ),
    );
  }

  Widget _buildQuickStatsSection() {
    if (_currentStatus == null) return const SizedBox.shrink();
    
    final analytics = _currentStatus!['analytics'] as Map<String, dynamic>;
    final overallHealth = _currentStatus!['overallHealthScore'] as double;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Stats',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Requests',
                    analytics['totalRequests'].toString(),
                    Icons.api,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Errors',
                    analytics['totalErrors'].toString(),
                    Icons.error,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Health',
                    '${overallHealth.toStringAsFixed(1)}%',
                    Icons.health_and_safety,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Cache Hit',
                    '${analytics['cacheHitRate'].toStringAsFixed(1)}%',
                    Icons.storage,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildTestOperationsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test Operations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _testGeocodingOperation,
                  icon: const Icon(Icons.location_on),
                  label: const Text('Test Geocoding'),
                ),
                ElevatedButton.icon(
                  onPressed: _testRoutingOperation,
                  icon: const Icon(Icons.directions),
                  label: const Text('Test Routing'),
                ),
                ElevatedButton.icon(
                  onPressed: _testFailingOperation,
                  icon: const Icon(Icons.error),
                  label: const Text('Test Error'),
                ),
                ElevatedButton.icon(
                  onPressed: _testMultipleOperations,
                  icon: const Icon(Icons.speed),
                  label: const Text('Load Test'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reports & Analytics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generateReport,
                    icon: const Icon(Icons.assessment),
                    label: const Text('Generate Report'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exportData,
                    icon: const Icon(Icons.download),
                    label: const Text('Export Data'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _showAnalyticsDashboard,
              icon: const Icon(Icons.dashboard),
              label: const Text('Open Analytics Dashboard'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testGeocodingOperation() async {
    try {
      await _monitor.trackServiceOperation(
        'nominatim',
        'geocode_test',
        () => _geocodingService.searchPlaces('New York'),
      );
      
      _showSnackBar('Geocoding test completed successfully');
    } catch (e) {
      _showSnackBar('Geocoding test failed: $e');
    }
    
    _updateStatus();
  }

  Future<void> _testRoutingOperation() async {
    try {
      await _monitor.trackServiceOperation(
        'openrouteservice',
        'routing_test',
        () => _routingService.calculateRoute(
          const LatLng(40.7128, -74.0060), // New York
          const LatLng(34.0522, -118.2437), // Los Angeles
        ),
      );
      
      _showSnackBar('Routing test completed successfully');
    } catch (e) {
      _showSnackBar('Routing test failed: $e');
    }
    
    _updateStatus();
  }

  Future<void> _testFailingOperation() async {
    try {
      await _monitor.trackServiceOperation(
        'test_service',
        'failing_operation',
        () async {
          throw Exception('Simulated failure for testing');
        },
      );
    } catch (e) {
      _showSnackBar('Error test completed (expected failure)');
    }
    
    _updateStatus();
  }

  Future<void> _testMultipleOperations() async {
    _showSnackBar('Running load test...');
    
    final futures = <Future>[];
    
    // Create multiple concurrent operations
    for (int i = 0; i < 10; i++) {
      futures.add(
        _monitor.trackServiceOperation(
          'load_test_service',
          'operation_$i',
          () async {
            await Future.delayed(Duration(milliseconds: 50 + (i * 10)));
            return 'result_$i';
          },
        ),
      );
    }
    
    try {
      await Future.wait(futures);
      _showSnackBar('Load test completed successfully');
    } catch (e) {
      _showSnackBar('Load test completed with some errors');
    }
    
    _updateStatus();
  }

  Future<void> _generateReport() async {
    final report = _monitor.generateReport();
    await _monitor.saveReport(report);
    
    _showSnackBar('Report generated and saved');
    
    // Show report summary
    _showReportDialog(report);
  }

  Future<void> _exportData() async {
    final data = _monitor.analytics.exportAnalyticsData();
    
    // In a real app, you would save this to a file or send to a server
    _showSnackBar('Analytics data exported (${data.keys.length} sections)');
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exported Data'),
          content: SingleChildScrollView(
            child: Text(
              'Data sections:\n${data.keys.join('\n')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showAnalyticsDashboard() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: _monitor.analytics),
            ChangeNotifierProvider.value(value: _monitor.healthMonitor),
          ],
          child: const AnalyticsDashboard(),
        ),
      ),
    );
  }

  void _showReportDialog(Map<String, dynamic> report) {
    final recommendations = report['recommendations'] as List<String>;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Report ${report['reportId']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Generated: ${report['generatedAt']}'),
              const SizedBox(height: 16),
              const Text('Recommendations:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...recommendations.map((rec) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• $rec'),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}

// Helper class for LatLng (simplified for example)
class LatLng {
  final double latitude;
  final double longitude;
  
  const LatLng(this.latitude, this.longitude);
  
  @override
  String toString() => 'LatLng($latitude, $longitude)';
}
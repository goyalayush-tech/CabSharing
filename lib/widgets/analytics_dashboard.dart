import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/map_analytics_service.dart';
import '../services/service_health_monitor.dart';
import '../models/service_health.dart';

/// Dashboard widget for displaying map service analytics and health
class AnalyticsDashboard extends StatefulWidget {
  const AnalyticsDashboard({super.key});

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Service Analytics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Service Health', icon: Icon(Icons.health_and_safety)),
            Tab(text: 'Rate Limits', icon: Icon(Icons.speed)),
            Tab(text: 'Errors', icon: Icon(Icons.error_outline)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildServiceHealthTab(),
          _buildRateLimitsTab(),
          _buildErrorsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return Consumer<MapAnalyticsService>(
      builder: (context, analytics, child) {
        final summary = analytics.getAnalyticsSummary();
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCards(summary),
              const SizedBox(height: 24),
              _buildServicesList(summary['services'] as List),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> summary) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Requests',
                summary['totalRequests'].toString(),
                Icons.api,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                'Success Rate',
                '${(summary['successRate'] as double * 100).toStringAsFixed(1)}%',
                Icons.check_circle,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Cache Hit Rate',
                '${summary['cacheHitRate'].toStringAsFixed(1)}%',
                Icons.storage,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                'Session Time',
                _formatDuration(summary['sessionDuration'] as Duration),
                Icons.timer,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesList(List services) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Service Statistics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...services.map((service) => _buildServiceTile(service)),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceTile(Map<String, dynamic> service) {
    final successRate = service['successRate'] as double;
    final successRatePercent = successRate * 100; // Convert to percentage for display
    final avgResponseTime = service['averageResponseTime'] as double;
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getHealthColor(successRatePercent),
        child: Text(
          service['serviceName'].toString().substring(0, 2).toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
      title: Text(service['serviceName']),
      subtitle: Text(
        'Calls: ${service['totalCalls']} | Avg: ${avgResponseTime.toStringAsFixed(0)}ms',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${successRatePercent.toStringAsFixed(1)}%',
            style: TextStyle(
              color: _getHealthColor(successRatePercent),
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${service['errorCount']} errors',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildServiceHealthTab() {
    return Consumer<ServiceHealthMonitor>(
      builder: (context, monitor, child) {
        final allHealth = monitor.getAllServiceHealth();
        final overallScore = monitor.getOverallHealthScore();
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOverallHealthCard(overallScore),
              const SizedBox(height: 24),
              _buildHealthServicesList(allHealth.values.toList()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverallHealthCard(double overallScore) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Overall System Health',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            CircularProgressIndicator(
              value: overallScore / 100,
              strokeWidth: 8,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getHealthColor(overallScore),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${overallScore.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: _getHealthColor(overallScore),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthServicesList(List<ServiceHealth> services) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Service Health Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...services.map((service) => _buildHealthServiceTile(service)),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthServiceTile(ServiceHealth service) {
    return ExpansionTile(
      leading: Icon(
        service.isAvailable ? Icons.check_circle : Icons.error,
        color: service.isAvailable ? Colors.green : Colors.red,
      ),
      title: Text(service.serviceName),
      subtitle: Text(
        'Success Rate: ${(service.successRate * 100).toStringAsFixed(1)}% | '
        'Avg Response: ${service.averageResponseTime.inMilliseconds}ms',
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHealthMetric('Status', service.isAvailable ? 'Available' : 'Unavailable'),
              _buildHealthMetric('Success Rate', '${(service.successRate * 100).toStringAsFixed(1)}%'),
              _buildHealthMetric('Average Response Time', '${service.averageResponseTime.inMilliseconds}ms'),
              _buildHealthMetric('Failure Count', service.failureCount.toString()),
              if (service.lastFailure != null)
                _buildHealthMetric('Last Failure', _formatDateTime(service.lastFailure!)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHealthMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          )),
        ],
      ),
    );
  }

  Widget _buildRateLimitsTab() {
    return Consumer<MapAnalyticsService>(
      builder: (context, analytics, child) {
        final rateLimits = analytics.getRateLimitStatus();
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rate Limit Status',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ...rateLimits.entries.map((entry) => 
                _buildRateLimitCard(entry.key, entry.value)
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRateLimitCard(String serviceName, Map<String, dynamic> status) {
    final isThrottled = status['isThrottled'] as bool;
    final currentUsage = status['currentUsage'] as int;
    final limit = status['limit'] as int;
    final resetTime = status['resetTime'] as Duration;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  serviceName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Icon(
                  isThrottled ? Icons.warning : Icons.check_circle,
                  color: isThrottled ? Colors.orange : Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: currentUsage / limit,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                isThrottled ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$currentUsage / $limit requests'),
                if (resetTime.inSeconds > 0)
                  Text('Reset in ${_formatDuration(resetTime)}'),
              ],
            ),
            if (isThrottled)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Rate limit exceeded. Requests are being throttled.',
                  style: TextStyle(color: Colors.orange[700]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getHealthColor(double percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 70) return Colors.orange;
    return Colors.red;
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  Widget _buildErrorsTab() {
    return Consumer<MapAnalyticsService>(
      builder: (context, analytics, child) {
        final errorLog = analytics.getErrorLog(limit: 50);
        final summary = analytics.getAnalyticsSummary();
        final errorsByService = summary['errorsByService'] as Map<String, List<Map<String, dynamic>>>;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildErrorSummaryCard(summary),
              const SizedBox(height: 24),
              _buildErrorsByServiceCard(errorsByService),
              const SizedBox(height: 24),
              _buildRecentErrorsCard(errorLog),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorSummaryCard(Map<String, dynamic> summary) {
    final totalErrors = summary['totalErrors'] as int;
    final totalRequests = summary['totalRequests'] as int;
    final successRate = summary['successRate'] as double;
    final errorRate = (1.0 - successRate) * 100; // Convert to percentage
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Error Summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Total Errors',
                    totalErrors.toString(),
                    Icons.error,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Error Rate',
                    '${errorRate.toStringAsFixed(2)}%',
                    Icons.trending_up,
                    errorRate > 5 ? Colors.red : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorsByServiceCard(Map<String, List<Map<String, dynamic>>> errorsByService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Errors by Service',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (errorsByService.isEmpty)
              const Text('No errors recorded')
            else
              ...errorsByService.entries.map((entry) => 
                _buildServiceErrorTile(entry.key, entry.value)
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceErrorTile(String serviceName, List<Map<String, dynamic>> errors) {
    return ExpansionTile(
      leading: Icon(Icons.error_outline, color: Colors.red),
      title: Text(serviceName),
      subtitle: Text('${errors.length} errors'),
      children: errors.take(5).map((error) => 
        ListTile(
          dense: true,
          leading: Icon(Icons.bug_report, size: 16, color: Colors.red[300]),
          title: Text(
            error['operation'] as String,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          subtitle: Text(
            error['error'].toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          trailing: Text(
            _formatDateTime(DateTime.parse(error['timestamp'] as String)),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        )
      ).toList(),
    );
  }

  Widget _buildRecentErrorsCard(List<Map<String, dynamic>> errorLog) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Errors',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (errorLog.isEmpty)
              const Text('No recent errors')
            else
              ...errorLog.take(10).map((error) => 
                _buildErrorLogTile(error)
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorLogTile(Map<String, dynamic> error) {
    return ListTile(
      dense: true,
      leading: Icon(Icons.error, color: Colors.red, size: 20),
      title: Text('${error['serviceName']}.${error['operation']}'),
      subtitle: Text(
        error['error'].toString(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _formatDateTime(DateTime.parse(error['timestamp'] as String)),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
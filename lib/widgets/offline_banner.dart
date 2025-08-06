import 'package:flutter/material.dart';
import '../services/offline_service.dart';

/// Banner widget that shows offline status and provides retry functionality
class OfflineBanner extends StatelessWidget {
  final IOfflineService offlineService;
  final VoidCallback? onRetry;
  final bool showRetryButton;
  final String? customMessage;

  const OfflineBanner({
    super.key,
    required this.offlineService,
    this.onRetry,
    this.showRetryButton = true,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: offlineService.connectivityStream,
      initialData: offlineService.isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        
        if (isOnline) {
          return const SizedBox.shrink();
        }
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            border: Border(
              bottom: BorderSide(
                color: Colors.orange.shade300,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.wifi_off,
                color: Colors.orange.shade700,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  customMessage ?? 'You\'re offline. Some features may be limited.',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (showRetryButton && onRetry != null) ...[
                const SizedBox(width: 12),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Wrapper widget that shows offline state for its child
class OfflineWrapper extends StatelessWidget {
  final Widget child;
  final IOfflineService offlineService;
  final Widget? offlineChild;
  final String? offlineMessage;
  final VoidCallback? onRetry;

  const OfflineWrapper({
    super.key,
    required this.child,
    required this.offlineService,
    this.offlineChild,
    this.offlineMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: offlineService.connectivityStream,
      initialData: offlineService.isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        
        if (isOnline) {
          return child;
        }
        
        if (offlineChild != null) {
          return offlineChild!;
        }
        
        return _buildDefaultOfflineWidget(context);
      },
    );
  }

  Widget _buildDefaultOfflineWidget(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            offlineMessage ?? 'You\'re currently offline',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Some features may be limited until you reconnect.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mixin for widgets that need offline awareness
mixin OfflineAwareMixin<T extends StatefulWidget> on State<T> {
  IOfflineService? _offlineService;
  
  IOfflineService get offlineService => _offlineService!;
  
  void initializeOfflineService(IOfflineService service) {
    _offlineService = service;
  }
  
  bool get isOnline => _offlineService?.isOnline ?? true;
  
  /// Show a snackbar when going offline
  void showOfflineSnackBar() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text('You\'re now offline'),
          ],
        ),
        backgroundColor: Colors.orange.shade600,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  /// Show a snackbar when coming back online
  void showOnlineSnackBar() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.wifi, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text('You\'re back online'),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
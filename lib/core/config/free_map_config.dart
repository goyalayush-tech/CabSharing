import '../constants/app_constants.dart';

class FreeMapConfig {
  final String nominatimBaseUrl;
  final String openRouteServiceBaseUrl;
  final String openRouteServiceApiKey;
  final String osmTileServerUrl;
  final Duration requestTimeout;
  final int maxRetries;
  final Duration cacheDuration;
  final bool enableFallback;
  final double nominatimRateLimit;
  final int openRouteServiceDailyLimit;

  const FreeMapConfig({
    this.nominatimBaseUrl = AppConstants.nominatimBaseUrl,
    this.openRouteServiceBaseUrl = AppConstants.openRouteServiceBaseUrl,
    this.openRouteServiceApiKey = AppConstants.openRouteServiceApiKey,
    this.osmTileServerUrl = AppConstants.osmTileServerUrl,
    this.requestTimeout = AppConstants.mapRequestTimeout,
    this.maxRetries = AppConstants.maxMapRetries,
    this.cacheDuration = AppConstants.mapCacheDuration,
    this.enableFallback = true,
    this.nominatimRateLimit = AppConstants.nominatimRateLimit,
    this.openRouteServiceDailyLimit = AppConstants.openRouteServiceDailyLimit,
  });

  // Development configuration with mock services
  static const FreeMapConfig development = FreeMapConfig(
    enableFallback: false,
    requestTimeout: Duration(seconds: 5),
    maxRetries: 1,
  );

  // Production configuration with all features enabled
  static const FreeMapConfig production = FreeMapConfig(
    enableFallback: true,
    requestTimeout: Duration(seconds: 10),
    maxRetries: 3,
  );

  FreeMapConfig copyWith({
    String? nominatimBaseUrl,
    String? openRouteServiceBaseUrl,
    String? openRouteServiceApiKey,
    String? osmTileServerUrl,
    Duration? requestTimeout,
    int? maxRetries,
    Duration? cacheDuration,
    bool? enableFallback,
    double? nominatimRateLimit,
    int? openRouteServiceDailyLimit,
  }) {
    return FreeMapConfig(
      nominatimBaseUrl: nominatimBaseUrl ?? this.nominatimBaseUrl,
      openRouteServiceBaseUrl: openRouteServiceBaseUrl ?? this.openRouteServiceBaseUrl,
      openRouteServiceApiKey: openRouteServiceApiKey ?? this.openRouteServiceApiKey,
      osmTileServerUrl: osmTileServerUrl ?? this.osmTileServerUrl,
      requestTimeout: requestTimeout ?? this.requestTimeout,
      maxRetries: maxRetries ?? this.maxRetries,
      cacheDuration: cacheDuration ?? this.cacheDuration,
      enableFallback: enableFallback ?? this.enableFallback,
      nominatimRateLimit: nominatimRateLimit ?? this.nominatimRateLimit,
      openRouteServiceDailyLimit: openRouteServiceDailyLimit ?? this.openRouteServiceDailyLimit,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nominatimBaseUrl': nominatimBaseUrl,
      'openRouteServiceBaseUrl': openRouteServiceBaseUrl,
      'openRouteServiceApiKey': openRouteServiceApiKey,
      'osmTileServerUrl': osmTileServerUrl,
      'requestTimeout': requestTimeout.inMilliseconds,
      'maxRetries': maxRetries,
      'cacheDuration': cacheDuration.inMilliseconds,
      'enableFallback': enableFallback,
      'nominatimRateLimit': nominatimRateLimit,
      'openRouteServiceDailyLimit': openRouteServiceDailyLimit,
    };
  }

  factory FreeMapConfig.fromJson(Map<String, dynamic> json) {
    return FreeMapConfig(
      nominatimBaseUrl: json['nominatimBaseUrl'] as String,
      openRouteServiceBaseUrl: json['openRouteServiceBaseUrl'] as String,
      openRouteServiceApiKey: json['openRouteServiceApiKey'] as String,
      osmTileServerUrl: json['osmTileServerUrl'] as String,
      requestTimeout: Duration(milliseconds: json['requestTimeout'] as int),
      maxRetries: json['maxRetries'] as int,
      cacheDuration: Duration(milliseconds: json['cacheDuration'] as int),
      enableFallback: json['enableFallback'] as bool,
      nominatimRateLimit: (json['nominatimRateLimit'] as num).toDouble(),
      openRouteServiceDailyLimit: json['openRouteServiceDailyLimit'] as int,
    );
  }

  @override
  String toString() {
    return 'FreeMapConfig('
        'nominatimBaseUrl: $nominatimBaseUrl, '
        'openRouteServiceBaseUrl: $openRouteServiceBaseUrl, '
        'requestTimeout: $requestTimeout, '
        'maxRetries: $maxRetries, '
        'cacheDuration: $cacheDuration, '
        'enableFallback: $enableFallback'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FreeMapConfig &&
        other.nominatimBaseUrl == nominatimBaseUrl &&
        other.openRouteServiceBaseUrl == openRouteServiceBaseUrl &&
        other.openRouteServiceApiKey == openRouteServiceApiKey &&
        other.osmTileServerUrl == osmTileServerUrl &&
        other.requestTimeout == requestTimeout &&
        other.maxRetries == maxRetries &&
        other.cacheDuration == cacheDuration &&
        other.enableFallback == enableFallback &&
        other.nominatimRateLimit == nominatimRateLimit &&
        other.openRouteServiceDailyLimit == openRouteServiceDailyLimit;
  }

  @override
  int get hashCode {
    return Object.hash(
      nominatimBaseUrl,
      openRouteServiceBaseUrl,
      openRouteServiceApiKey,
      osmTileServerUrl,
      requestTimeout,
      maxRetries,
      cacheDuration,
      enableFallback,
      nominatimRateLimit,
      openRouteServiceDailyLimit,
    );
  }
}
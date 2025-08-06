import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/config/app_config.dart';
import 'core/config/free_map_config.dart';
import 'services/auth_service.dart';
import 'services/mock_auth_service.dart';
import 'services/user_service.dart';
import 'services/mock_user_service.dart';
import 'services/ride_service.dart';
import 'services/mock_ride_service.dart';
import 'services/location_service.dart';
import 'services/route_service.dart';
import 'services/free_geocoding_service.dart';
import 'services/free_routing_service.dart';
import 'services/map_cache_service.dart';
import 'services/offline_service.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/ride_provider.dart';

class RideLinkApp extends StatelessWidget {
  const RideLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<IAuthService>(
          create: (_) => AppConfig.useMockAuth ? MockAuthService() : AuthService(),
        ),
        Provider<IUserService>(
          create: (_) => AppConfig.useMockAuth ? MockUserService() : UserService(),
        ),
        Provider<IRideService>(
          create: (_) => AppConfig.useMockAuth ? MockRideService() : RideService(),
        ),
        Provider<ILocationService>(
          create: (_) => AppConfig.useMockAuth ? MockLocationService() : LocationService(),
        ),
        Provider<IRouteService>(
          create: (_) => AppConfig.useMockAuth ? MockRouteService() : RouteService(),
        ),
        // Free Map Services
        Provider<FreeMapConfig>(
          create: (_) => const FreeMapConfig(),
        ),
        Provider<IMapCacheService>(
          create: (_) => AppConfig.useMockAuth ? MockMapCacheService() : HiveMapCacheService(),
        ),
        Provider<IOfflineService>(
          create: (_) => AppConfig.useMockAuth ? MockOfflineService() : OfflineService(),
        ),
        Provider<IFreeGeocodingService>(
          create: (context) => AppConfig.useMockAuth 
              ? MockFreeGeocodingService()
              : NominatimGeocodingService(
                  config: context.read<FreeMapConfig>(),
                  cacheService: context.read<IMapCacheService>(),
                ),
        ),
        Provider<IFreeRoutingService>(
          create: (context) => AppConfig.useMockAuth
              ? MockFreeRoutingService()
              : OpenRouteService(
                  config: context.read<FreeMapConfig>(),
                  cacheService: context.read<IMapCacheService>(),
                ),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(context.read<IAuthService>()),
        ),
        ChangeNotifierProvider<UserProvider>(
          create: (context) => UserProvider(context.read<IUserService>()),
        ),
        ChangeNotifierProvider<RideProvider>(
          create: (context) => RideProvider(context.read<IRideService>()),
        ),
      ],
      child: MaterialApp.router(
        title: 'RideLink',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        routerConfig: AppRouter.router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
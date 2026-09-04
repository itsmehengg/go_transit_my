import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../analytics/transport_analytics_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../routes/route_planner_screen.dart';
import '../stations/station_screens.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  static const routeName='/app';
  @override State<AppShell> createState()=>_AppShellState();
}
class _AppShellState extends State<AppShell>{
  int _index=0;
  final _screens=const [HomeScreen(),RoutePlannerScreen(),NearbyStationsScreen(),TransportAnalyticsScreen(),ProfileScreen()];
  @override Widget build(BuildContext context)=>Scaffold(body:IndexedStack(index:_index,children:_screens),bottomNavigationBar:NavigationBar(selectedIndex:_index,indicatorColor:AppColors.primary.withValues(alpha:.12),onDestinationSelected:(v)=>setState(()=>_index=v),destinations:const [NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Home'),NavigationDestination(icon:Icon(Icons.route_outlined),selectedIcon:Icon(Icons.route),label:'Routes'),NavigationDestination(icon:Icon(Icons.location_on_outlined),selectedIcon:Icon(Icons.location_on),label:'Stations'),NavigationDestination(icon:Icon(Icons.analytics_outlined),selectedIcon:Icon(Icons.analytics),label:'Analytics'),NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person),label:'Profile')]));
}

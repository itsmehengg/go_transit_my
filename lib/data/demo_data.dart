import 'package:flutter/material.dart';

class TransportMode {
  const TransportMode(this.name, this.color, this.icon);
  final String name;
  final Color color;
  final IconData icon;
}

class JourneyOption {
  const JourneyOption({
    required this.duration,
    required this.mode,
    required this.time,
    required this.fare,
    required this.transfers,
    required this.status,
  });

  final String duration;
  final TransportMode mode;
  final String time;
  final String fare;
  final String transfers;
  final String status;
}

class Station {
  const Station(this.name, this.location, this.distance);
  final String name;
  final String location;
  final String distance;
}

class ServiceAlert {
  const ServiceAlert(this.type, this.title, this.time, this.color);
  final String type;
  final String title;
  final String time;
  final Color color;
}

const mrt = TransportMode('MRT', Color(0xFF10A66B), Icons.train_rounded);
const lrt = TransportMode('LRT', Color(0xFFEF4444), Icons.tram_rounded);
const bus = TransportMode(
  'Bus',
  Color(0xFF0EA5E9),
  Icons.directions_bus_rounded,
);
const ktm = TransportMode('KTM', Color(0xFF7C3AED), Icons.train_rounded);

const journeyOptions = [
  JourneyOption(
    duration: '35 mins',
    mode: mrt,
    time: '10:30 AM - 11:05 AM',
    fare: 'RM 2.70',
    transfers: '1 Transfer',
    status: 'Live',
  ),
  JourneyOption(
    duration: '42 mins',
    mode: bus,
    time: '10:32 AM - 11:14 AM',
    fare: 'RM 2.10',
    transfers: '2 Transfers',
    status: 'Scheduled',
  ),
  JourneyOption(
    duration: '39 mins',
    mode: mrt,
    time: '10:36 AM - 11:07 AM',
    fare: 'RM 2.60',
    transfers: '1 Transfer',
    status: 'Realtime unavailable',
  ),
];

const stations = [
  Station('KL Sentral', 'Kuala Lumpur', '300 m'),
  Station('Muzium Negara', 'Kuala Lumpur', '750 m'),
  Station('Pasar Seni', 'Kuala Lumpur', '1.2 km'),
  Station('KLCC', 'Kuala Lumpur', '1.6 km'),
];

const alerts = [
  ServiceAlert(
    'Delay',
    'MRT Kajang Line delayed by 10 minutes',
    '5 mins ago',
    Color(0xFFEF4444),
  ),
  ServiceAlert(
    'Maintenance',
    'LRT Ampang Line maintenance on 25 May',
    '1 hour ago',
    Color(0xFFF59E0B),
  ),
  ServiceAlert(
    'Station Closure',
    'Rapid Jomlink Station closure notice',
    '3 hours ago',
    Color(0xFF0065D8),
  ),
];

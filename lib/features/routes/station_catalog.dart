class RouteStation {
  const RouteStation({required this.name, required this.mode});

  final String name;
  final String mode;
}

const routeStations = <RouteStation>[
  RouteStation(name: 'KL Sentral', mode: 'KTM'),
  RouteStation(name: 'Pasar Seni', mode: 'MRT'),
  RouteStation(name: 'Bukit Bintang', mode: 'MRT'),
  RouteStation(name: 'Muzium Negara', mode: 'MRT'),
  RouteStation(name: 'Merdeka', mode: 'MRT'),
  RouteStation(name: 'Cochrane', mode: 'MRT'),
  RouteStation(name: 'Maluri', mode: 'MRT'),
  RouteStation(name: 'Taman Midah', mode: 'MRT'),
  RouteStation(name: 'Kajang', mode: 'MRT'),
  RouteStation(name: 'KLCC', mode: 'LRT'),
  RouteStation(name: 'Masjid Jamek', mode: 'LRT'),
  RouteStation(name: 'Dang Wangi', mode: 'LRT'),
  RouteStation(name: 'Ampang Park', mode: 'LRT'),
  RouteStation(name: 'Bangsar', mode: 'LRT'),
  RouteStation(name: 'Abdullah Hukum', mode: 'LRT'),
  RouteStation(name: 'Universiti', mode: 'LRT'),
  RouteStation(name: 'Taman Jaya', mode: 'LRT'),
  RouteStation(name: 'Subang Jaya', mode: 'KTM'),
  RouteStation(name: 'Mid Valley', mode: 'KTM'),
  RouteStation(name: 'Bandar Tasik Selatan', mode: 'KTM'),
  RouteStation(name: 'Serdang', mode: 'KTM'),
  RouteStation(name: 'Batu Caves', mode: 'KTM'),
];

# Flutter Blueprint (Passenger + Driver)

This is the recommended clean-architecture structure for your Flutter app.

## Project Structure

```text
lib
├─ core
│  ├─ constants
│  ├─ errors
│  ├─ network
│  ├─ theme
│  └─ utils
├─ features
│  ├─ auth
│  │  ├─ data
│  │  │  ├─ datasources
│  │  │  ├─ models
│  │  │  └─ repositories
│  │  ├─ domain
│  │  │  ├─ entities
│  │  │  ├─ repositories
│  │  │  └─ usecases
│  │  └─ presentation
│  │     ├─ pages
│  │     ├─ providers
│  │     └─ widgets
│  ├─ booking
│  ├─ map_tracking
│  ├─ driver_panel
│  ├─ passenger_panel
│  └─ ratings
├─ injection_container.dart
└─ main.dart
```

## Required Flutter Packages

- `google_maps_flutter`
- `geolocator`
- `socket_io_client`
- `dio`
- `flutter_secure_storage`
- `provider` or `flutter_bloc`
- `polyline_points`

## Google Maps Setup Snippet

```dart
GoogleMap(
  initialCameraPosition: CameraPosition(
    target: LatLng(currentLat, currentLng),
    zoom: 15,
  ),
  myLocationEnabled: true,
  myLocationButtonEnabled: true,
  markers: {
    Marker(
      markerId: const MarkerId('pickup'),
      position: LatLng(pickupLat, pickupLng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    ),
    Marker(
      markerId: const MarkerId('dropoff'),
      position: LatLng(dropoffLat, dropoffLng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
    ),
  },
  polylines: {
    Polyline(
      polylineId: const PolylineId('route'),
      color: Colors.green,
      width: 5,
      points: routePoints,
    ),
  },
  onTap: (LatLng tapped) {
    // Use first tap as pickup, second as dropoff, then request route.
  },
)
```

## Socket Setup Snippet

```dart
final socket = IO.io(
  'http://YOUR_BACKEND_URL:5000',
  IO.OptionBuilder()
      .setTransports(['websocket'])
      .setAuth({'token': jwtToken})
      .enableAutoConnect()
      .build(),
);

socket.onConnect((_) {
  debugPrint('Socket connected');
});

socket.on('passenger:driver_location', (data) {
  // Update driver marker in map UI.
});
```

## Passenger Find Ride API Call

`POST /api/passenger/bookings/find-ride`

```json
{
  "pickupAddress": "Public Market",
  "pickupLat": 14.1234567,
  "pickupLng": 121.1234567,
  "dropoffAddress": "Municipal Hall",
  "dropoffLat": 14.1334567,
  "dropoffLng": 121.1434567
}
```

## Driver Location Update Pattern (3-5 seconds)

Use a periodic timer only while driver is online:

1. Get GPS location.
2. Emit `driver:location_update` with current `lat/lng`.
3. Repeat every 3-5 seconds.
4. Stop timer when offline or app is backgrounded.

## UI Direction for FindMeTricycle

- Gradient theme: green to yellow
- Rounded cards (16-20 radius)
- Map-first screens
- Bottom navigation for passenger tabs (Home, Activity, Profile)
- Driver request modal card with Accept/Decline actions
- Post-ride 5-star rating sheet


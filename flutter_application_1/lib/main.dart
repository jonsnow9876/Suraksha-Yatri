import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(SurakshaApp());
}

class SurakshaApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Suraksha Yatri (Prototype)',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: SplashScreen(),
    );
  }
}

// === CHANGE BASE_URL to match your backend ===
const String BASE_URL = "http://127.0.0.1:5000"; // emulator example

// --- A simple splash to check stored digitalID ---
class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> {
  Future<void> checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final digitalId = prefs.getString('digitalID');
    await Future.delayed(Duration(milliseconds: 600));
    if (digitalId != null && digitalId.isNotEmpty) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MapHome()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RegisterPage()));
    }
  }

  @override
  void initState(){
    super.initState();
    checkLogin();
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// --- Registration screen (simple name + phone) ---
class RegisterPage extends StatefulWidget {
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}
class _RegisterPageState extends State<RegisterPage> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool loading = false;

  Future<void> register() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Enter name & phone")));
      return;
    }
    setState((){ loading = true; });
    try {
      final resp = await http.post(Uri.parse('$BASE_URL/api/register'),
        headers: {'Content-Type':'application/json'},
        body: jsonEncode({'name': name, 'phone': phone}),
      ).timeout(Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final map = jsonDecode(resp.body);
        final digitalID = map['digitalID'] ?? map['digitalId'] ?? '';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('digitalID', digitalID);
        await prefs.setString('name', name);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MapHome()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Registration failed")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState((){ loading = false; });
    }
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: Text("Register - Suraksha Yatri")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: "Name")),
            SizedBox(height: 10),
            TextField(controller: _phoneCtrl, decoration: InputDecoration(labelText: "Phone"), keyboardType: TextInputType.phone),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : register,
              child: loading ? CircularProgressIndicator(color: Colors.white) : Text("Register & Get Digital ID")
            )
          ],
        ),
      ),
    );
  }
}

// --- Map Home: main app screen with panic button and geofence monitoring ---
class MapHome extends StatefulWidget {
  @override
  State<MapHome> createState() => _MapHomeState();
}

class _MapHomeState extends State<MapHome> {
  late GoogleMapController _mapController;
  LatLng _defaultCenter = LatLng(26.9124, 75.7873); // default center (Jaipur) - change as demo
  final double geofenceRadiusMeters = 500; // 500m geofence radius for demo
  late LatLng geofenceCenter;
  Marker? userMarker;
  Circle? geofenceCircle;
  Timer? _locationTimer;
  bool _monitoring = false;
  String? digitalID;
  String? username;

  @override
  void initState(){
    super.initState();
    geofenceCenter = _defaultCenter;
    _loadUser();
    _startMonitoring(); // start periodic location checks
  }

  @override
  void dispose(){
    _locationTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    digitalID = prefs.getString('digitalID');
    username = prefs.getString('name');
    setState((){});
  }

  Future<void> _startMonitoring() async {
    // request permissions first
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        // cannot proceed without permission
        return;
      }
    }

    _monitoring = true;
    _locationTimer = Timer.periodic(Duration(seconds: 8), (timer) => _checkLocationAndUpdate());
    // initial call
    await _checkLocationAndUpdate();
  }

  Future<void> _checkLocationAndUpdate() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      LatLng current = LatLng(pos.latitude, pos.longitude);
      // update marker
      setState(() {
        userMarker = Marker(
          markerId: MarkerId('user'),
          position: current,
          infoWindow: InfoWindow(title: username ?? 'You'),
        );
      });
      // move camera a bit on first fix
      try {
        _mapController.animateCamera(CameraUpdate.newLatLng(current));
      } catch (_) {}

      // check geofence: distance from geofenceCenter
      double distanceMeters = Geolocator.distanceBetween(
        current.latitude, current.longitude,
        geofenceCenter.latitude, geofenceCenter.longitude
      );

      // If outside geofence, send alarm
      if (distanceMeters > geofenceRadiusMeters) {
        await _sendAlert('geofence', current);
      }

    } catch (e) {
      print("Location error: $e");
    }
  }

  Future<void> _sendAlert(String type, LatLng location) async {
    if (digitalID == null) {
      // try reload
      final prefs = await SharedPreferences.getInstance();
      digitalID = prefs.getString('digitalID');
      if (digitalID == null) return;
    }
    try {
      final resp = await http.post(Uri.parse('$BASE_URL/api/alert'),
        headers: {'Content-Type':'application/json'},
        body: jsonEncode({
          'userID': digitalID,
          'type': type,
          'location': {'lat': location.latitude, 'lng': location.longitude}
        }),
      ).timeout(Duration(seconds: 8));

      if (resp.statusCode == 200) {
        // Optionally show toast/snackbar
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Alert sent: $type")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Alert failed (server)")));
      }
    } catch (e) {
      print("Error sending alert: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Alert network error")));
    }
  }

  Future<void> _onPanicPressed() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      LatLng current = LatLng(pos.latitude, pos.longitude);
      await _sendAlert('panic', current);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not get location: $e")));
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    setState(() {
      geofenceCircle = Circle(
        circleId: CircleId('geofence'),
        center: geofenceCenter,
        radius: geofenceRadiusMeters,
        strokeWidth: 2,
        strokeColor: Colors.red.withOpacity(0.7),
        fillColor: Colors.red.withOpacity(0.15),
      );
    });
  }

  // Allow user to set geofence center by long-pressing the map
  void _onMapLongPress(LatLng pos) {
    setState(() {
      geofenceCenter = pos;
      geofenceCircle = Circle(
        circleId: CircleId('geofence'),
        center: geofenceCenter,
        radius: geofenceRadiusMeters,
        strokeWidth: 2,
        strokeColor: Colors.red.withOpacity(0.7),
        fillColor: Colors.red.withOpacity(0.15),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Geofence center set")));
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('digitalID');
    await prefs.remove('name');
    _locationTimer?.cancel();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RegisterPage()));
  }

  @override
  Widget build(BuildContext context) {
    Set<Marker> markers = {};
    if (userMarker != null) markers.add(userMarker!);
    return Scaffold(
      appBar: AppBar(
        title: Text("Suraksha Yatri - Prototype"),
        actions: [
          IconButton(onPressed: _logout, icon: Icon(Icons.logout))
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _defaultCenter, zoom: 14),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onMapCreated: _onMapCreated,
            markers: markers,
            circles: geofenceCircle != null ? {geofenceCircle!} : {},
            onLongPress: _onMapLongPress,
          ),

          // Panic button + small panel
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.warning, color: Colors.white),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical:16.0),
                      child: Text("PANIC", style: TextStyle(fontSize: 18)),
                    ),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: _onPanicPressed,
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(blurRadius:4, color: Colors.black12)]),
                  child: IconButton(
                    onPressed: () async {
                      // quick manual send with current position
                      try {
                        Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
                        await _sendAlert('manual_checkin', LatLng(pos.latitude, pos.longitude));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Location error")));
                      }
                    },
                    icon: Icon(Icons.send, color: Colors.teal),
                  ),
                )
              ],
            ),
          ),

          // small overlay info
          Positioned(top: 12, left: 12, child: Card(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal:12, vertical:8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Digital ID: ${digitalID ?? '---'}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text("Geofence radius: ${geofenceRadiusMeters.toInt()} m", style: TextStyle(fontSize: 12)),
                  Text("Long-press map to change center", style: TextStyle(fontSize: 11, color: Colors.black54)),
                ],
              ),
            ),
          ))
        ],
      ),
    );
  }
}
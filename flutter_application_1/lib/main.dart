/*
SIH Prototype - Single-file Flutter app (main.dart)

WHAT'S INCLUDED
- Splash screen -> Login/Registration (fake OTP) -> Dashboard with Map
- Geofencing simulation (circle zone) with real-time alerts when entering/leaving
- Profile page (store name/phone/email in SharedPreferences)
- Report Issue form (text + pick image) stored locally
- Notifications implemented as in-app dialogs (easy to extend to local notifications)

SETUP (before running)
1) Add these packages in pubspec.yaml or run:
   flutter pub add google_maps_flutter geolocator shared_preferences image_picker path_provider

2) Android (android/app/src/main/AndroidManifest.xml) add permissions inside <manifest>:
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
   <uses-permission android:name="android.permission.INTERNET" />
   <!-- If you use image picking from camera/storage -->
   <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
   <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

   Also add your Google Maps API key in android manifest (application tag):
   <meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_ANDROID_GOOGLE_MAPS_API_KEY"/>

3) iOS: add NSLocationWhenInUseUsageDescription and photo permissions to Info.plist and add Google Maps API key as described in plugin docs.

4) Replace YOUR_ANDROID_GOOGLE_MAPS_API_KEY with an API key (if you want maps); the app will still run in map-less mode if key missing but maps won't show.

USAGE
- Run: flutter run
- On first run, register with name/phone/email. OTP step is mocked (auto-accept).
- Dashboard shows map and a geofence circle. Move your device (or simulate location in emulator) to trigger enter/exit alerts.

LIMITATIONS
- This is a prototype skeleton: backend/report storage is local only. Replace local storage with API calls when connecting to a server.

--------------------------------------------------
Below is the full main.dart implementation.
--------------------------------------------------
*/

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIH Prototype',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(milliseconds: 1400), () async {
      final prefs = await SharedPreferences.getInstance();
      final registered = prefs.getBool('registered') ?? false;
      if (registered) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => DashboardPage()));
      } else {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => RegisterPage()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield, size: 84, color: Colors.white),
            SizedBox(height: 12),
            Text('SafeZone',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('Prototype for SIH', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String phone = '';
  String email = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(
                    labelText: 'Full name', prefixIcon: Icon(Icons.person)),
                validator: (v) => (v == null || v.trim().length < 3)
                    ? 'Enter a valid name'
                    : null,
                onSaved: (v) => name = v!.trim(),
              ),
              SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                    labelText: 'Phone number', prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().length < 7)
                    ? 'Enter a valid phone'
                    : null,
                onSaved: (v) => phone = v!.trim(),
              ),
              SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                    labelText: 'Email', prefixIcon: Icon(Icons.email)),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Enter a valid email'
                    : null,
                onSaved: (v) => email = v!.trim(),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    // Mock OTP flow
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => OtpPage(
                                name: name, phone: phone, email: email)));
                  }
                },
                child: Text('Continue'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class OtpPage extends StatefulWidget {
  final String name, phone, email;
  OtpPage({required this.name, required this.phone, required this.email});
  @override
  _OtpPageState createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _otpController = TextEditingController();
  bool sending = false;

  @override
  void initState() {
    super.initState();
    // In prototype, auto-fill OTP
    Future.delayed(Duration(milliseconds: 600), () {
      _otpController.text = '1234';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
                'We have sent an OTP to ${widget.phone}. (prototype auto-fill: 1234)',
                style: TextStyle(fontSize: 14)),
            SizedBox(height: 20),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: 'Enter OTP', prefixIcon: Icon(Icons.lock)),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: sending
                  ? null
                  : () async {
                      setState(() => sending = true);
                      await Future.delayed(Duration(milliseconds: 600));
                      if (_otpController.text.trim() == '1234') {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('registered', true);
                        await prefs.setString('profile_name', widget.name);
                        await prefs.setString('profile_phone', widget.phone);
                        await prefs.setString('profile_email', widget.email);
                        Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => DashboardPage()),
                            (r) => false);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Invalid OTP (use 1234)')));
                      }
                      setState(() => sending = false);
                    },
              child: Text('Verify & Continue'),
            )
          ],
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Completer<GoogleMapController> _mapController = Completer();
  static const LatLng _center =
      LatLng(28.6139, 77.2090); // New Delhi center as default
  LatLng? _currentLatLng;
  StreamSubscription<Position>? _positionStream;
  bool _insideGeofence = false;

  // Geofence: circle center and radius (in meters)
  final LatLng _geofenceCenter = LatLng(28.6139, 77.2090);
  final double _geofenceRadius = 300; // 300 meters

  Set<Circle> _circles() {
    return {
      Circle(
        circleId: CircleId('geofence'),
        center: _geofenceCenter,
        radius: _geofenceRadius,
        strokeWidth: 2,
        strokeColor: Colors.red.withOpacity(0.7),
        fillColor: Colors.red.withOpacity(0.1),
      )
    };
  }

  Set<Marker> _markers() {
    final m = <Marker>{};
    if (_currentLatLng != null) {
      m.add(Marker(markerId: MarkerId('me'), position: _currentLatLng!));
    }
    m.add(Marker(
        markerId: MarkerId('center'),
        position: _geofenceCenter,
        infoWindow: InfoWindow(title: 'Geo-fence center')));
    return m;
  }

  @override
  void initState() {
    super.initState();
    _initLocationStream();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _initLocationStream() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best);
    _updateLocation(LatLng(pos.latitude, pos.longitude));

    _positionStream = Geolocator.getPositionStream(
            locationSettings: LocationSettings(
                accuracy: LocationAccuracy.best, distanceFilter: 10))
        .listen((Position p) {
      _updateLocation(LatLng(p.latitude, p.longitude));
    });
  }

  void _updateLocation(LatLng newLoc) async {
    setState(() {
      _currentLatLng = newLoc;
    });

    final distance = _distanceBetween(newLoc.latitude, newLoc.longitude,
        _geofenceCenter.latitude, _geofenceCenter.longitude);
    final inside = distance <= _geofenceRadius;
    if (inside != _insideGeofence) {
      // state changed
      _insideGeofence = inside;
      _showGeofenceAlert(_insideGeofence);
    }

    // move camera to location
    if (_mapController.isCompleted) {
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLng(newLoc));
    }
  }

  double _distanceBetween(double lat1, double lng1, double lat2, double lng2) {
    // using Haversine formula via Geolocator
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  void _showGeofenceAlert(bool inside) {
    final title =
        inside ? 'Entered Safe Zone' : 'Geofence Alert: You left the zone';
    final body = inside
        ? 'You are now inside the safe area.'
        : 'You have exited the safe area. Tap for help.';

    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: Text('Close')),
              TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openEmergencyOptions();
                  },
                  child: Text('Emergency'))
            ],
          );
        });
  }

  void _openEmergencyOptions() {
    showModalBottomSheet(
        context: context,
        builder: (_) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Emergency Options',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                ListTile(
                  leading: Icon(Icons.call),
                  title: Text('Call Helpline'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Pretend calling helpline...')));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.share_location),
                  title: Text('Share Location with Emergency Contact'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Location shared (prototype).')));
                  },
                ),
              ],
            ),
          );
        });
  }

  int _selectedIndex = 0;

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _mapView();
      case 1:
        return ReportsPage();
      case 2:
        return ProfilePage();
      default:
        return _mapView();
    }
  }

  Widget _mapView() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _center, zoom: 14),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          onMapCreated: (GoogleMapController controller) {
            if (!_mapController.isCompleted)
              _mapController.complete(controller);
          },
          markers: _markers(),
          circles: _circles(),
        ),
        Positioned(
          top: 14,
          left: 14,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SafeZone Dashboard',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text(
                      _insideGeofence
                          ? 'Status: Inside safe zone'
                          : 'Status: Outside safe zone',
                      style: TextStyle(
                          color: _insideGeofence ? Colors.green : Colors.red)),
                ],
              ),
            ),
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SafeZone'),
        actions: [
          IconButton(
            icon: Icon(Icons.report),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ReportIssuePage()));
            },
          )
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.my_location),
        onPressed: () async {
          if (_currentLatLng != null && _mapController.isCompleted) {
            final controller = await _mapController.future;
            controller
                .animateCamera(CameraUpdate.newLatLngZoom(_currentLatLng!, 16));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Current location not available yet')));
          }
        },
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String name = '';
  String phone = '';
  String email = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      name = prefs.getString('profile_name') ?? '';
      phone = prefs.getString('profile_phone') ?? '';
      email = prefs.getString('profile_email') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
                leading: Icon(Icons.person, size: 40),
                title: Text(name, style: TextStyle(fontSize: 20)),
                subtitle: Text(phone)),
            SizedBox(height: 8),
            ListTile(leading: Icon(Icons.email), title: Text(email)),
            SizedBox(height: 24),
            ElevatedButton.icon(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => RegisterPage()),
                      (r) => false);
                },
                icon: Icon(Icons.exit_to_app),
                label: Text('Logout'))
          ],
        ),
      ),
    );
  }
}

class ReportIssuePage extends StatefulWidget {
  @override
  _ReportIssuePageState createState() => _ReportIssuePageState();
}

class _ReportIssuePageState extends State<ReportIssuePage> {
  final _formKey = GlobalKey<FormState>();
  String title = '';
  String description = '';
  File? _imageFile;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (picked != null) {
      final dir = await getApplicationDocumentsDirectory();
      final newFile = await File(picked.path).copy(
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${picked.name}');
      setState(() => _imageFile = newFile);
    }
  }

  Future<void> _saveReport() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    final prefs = await SharedPreferences.getInstance();
    final reportsJson = prefs.getStringList('reports') ?? [];
    final report = jsonEncode({
      'title': title,
      'description': description,
      'image': _imageFile?.path,
      'time': DateTime.now().toIso8601String()
    });
    reportsJson.insert(0, report);
    await prefs.setStringList('reports', reportsJson);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Report saved (prototype)')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Report Issue')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Title'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter title' : null,
                onSaved: (v) => title = v!.trim(),
              ),
              SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(labelText: 'Description'),
                maxLines: 4,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter description'
                    : null,
                onSaved: (v) => description = v!.trim(),
              ),
              SizedBox(height: 12),
              if (_imageFile != null) Image.file(_imageFile!, height: 180),
              TextButton.icon(
                  onPressed: _pickImage,
                  icon: Icon(Icons.photo),
                  label: Text('Pick image (optional)')),
              SizedBox(height: 16),
              ElevatedButton(
                  onPressed: _saveReport, child: Text('Submit Report')),
            ],
          ),
        ),
      ),
    );
  }
}

class ReportsPage extends StatefulWidget {
  @override
  _ReportsPageState createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('reports') ?? [];
    setState(() {
      _reports =
          list.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _reports.isEmpty
          ? Center(child: Text('No reports yet'))
          : ListView.builder(
              itemCount: _reports.length,
              itemBuilder: (ctx, i) {
                final r = _reports[i];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: ListTile(
                    leading: r['image'] != null
                        ? Image.file(File(r['image']),
                            width: 56, fit: BoxFit.cover)
                        : Icon(Icons.report),
                    title: Text(r['title'] ?? ''),
                    subtitle: Text(r['description'] ?? ''),
                    trailing: Text(_shortTime(r['time'])),
                  ),
                );
              },
            ),
    );
  }

  String _shortTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year.toString().substring(0, 2)}';
    } catch (e) {
      return '';
    }
  }
}

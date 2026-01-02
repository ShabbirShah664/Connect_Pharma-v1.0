import 'dart:async';
import 'package:connect_pharma/services/notification_service.dart';
import 'package:connect_pharma/services/ml_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_pharma/services/request_service.dart';
import 'package:connect_pharma/widgets/FadeInSlide.dart';
import 'package:connect_pharma/screens/User/DeliveryScreen.dart';
import 'package:connect_pharma/screens/User/SelfPickupScreen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:connect_pharma/screens/User/SearchingScreen.dart';
import '../ChatScreen.dart';
import 'package:connect_pharma/screens/User/ProfileScreen.dart';
import 'package:geocoding/geocoding.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:connect_pharma/screens/User/TrackingMapScreen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class UserScreen extends StatefulWidget {
  // ... existing code ...

  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final _searchCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _aiSearchCtrl = TextEditingController();
  bool _loading = false;
  bool _geocodingLoading = false;
  String _aiQuery = '';
  XFile? _prescription;
  final ImagePicker _picker = ImagePicker();
  // Track previous request statuses to detect changes
  final Map<String, String> _previousStatuses = {};
  bool _isInitialLoad = true;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _requestSubscription;
  double? _curLat;
  double? _curLng;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng _currentPosition = const LatLng(24.8607, 67.0011);
  bool _mapLoading = true;

  @override
  void initState() {
    super.initState();
    NotificationService().init();
    _getCurrentLocation();
    _fetchPharmacyMarkers();
    // Delay listener setup to ensure widget is fully mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToRequestStatusChanges();
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      if (mounted) setState(() => _mapLoading = true);
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _mapLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _mapLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _mapLoading = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      if (mounted) {
        setState(() {
          _curLat = position.latitude;
          _curLng = position.longitude;
          _currentPosition = LatLng(position.latitude, position.longitude);
          _mapLoading = false;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_currentPosition),
        );
        _getAddressFromLatLng(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) setState(() => _mapLoading = false);
    }
  }

  Future<void> _getAddressFromLatLng(double lat, double lng) async {
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _locationCtrl.text = "Precise Web Location (${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})";
        });
      }
      return;
    }
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = "${place.street}, ${place.subLocality ?? ''}, ${place.locality ?? ''} ${place.postalCode ?? ''}";
        // Clean up double commas or leading/trailing commas if any parts are empty
        address = address.replaceAll(RegExp(r',\s*,'), ',').trim();
        if (address.startsWith(',')) address = address.substring(1).trim();
        if (address.endsWith(',')) address = address.substring(0, address.length - 1).trim();

        if (mounted) {
          setState(() {
            _locationCtrl.text = address;
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }
  }

  Future<void> _getLatLngFromAddress(String address) async {
    if (address.isEmpty) return;
    if (kIsWeb) {
      _showSnack('Address search is restricted on web for now. Please use current location.');
      return;
    }
    if (mounted) setState(() => _geocodingLoading = true);
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        Location loc = locations[0];
        LatLng newPos = LatLng(loc.latitude, loc.longitude);
        if (mounted) {
          setState(() {
            _curLat = loc.latitude;
            _curLng = loc.longitude;
            _currentPosition = newPos;
            _geocodingLoading = false;
          });
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(newPos),
          );
        }
      }
    } catch (e) {
      debugPrint('Error getting coordinates: $e');
      if (mounted) {
        setState(() => _geocodingLoading = false);
        _showSnack('Could not find location. Please check the address.');
      }
    }
  }

  Future<void> _fetchPharmacyMarkers() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('pharmacists').get();
      final newMarkers = snapshot.docs.map((doc) {
        final data = doc.data();
        final lat = (data['lat'] as num?)?.toDouble() ?? (data['pharmacyLat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble() ?? (data['pharmacyLng'] as num?)?.toDouble();
        if (lat == null || lng == null) return null;

        return Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: data['pharmacyName'] ?? data['displayName'] ?? 'Pharmacy',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        );
      }).whereType<Marker>().toSet();

      if (mounted) {
        setState(() {
          _markers = newMarkers;
        });
      }
    } catch (e) {
      debugPrint('Error fetching pharmacy markers: $e');
    }
  }

  /// Listen to user's requests and show notification when status changes to 'accepted'
  void _listenToRequestStatusChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Cancel existing subscription if any
    _requestSubscription?.cancel();

    _requestSubscription = RequestService.streamRequestsForUser(user.uid).listen(
      (snapshot) {
        if (!mounted) return;

        // On initial load, just populate the status map without showing notifications
        if (_isInitialLoad) {
          for (var doc in snapshot.docs) {
            final requestId = doc.id;
            final data = doc.data();
            final currentStatus = data['status'] as String? ?? '';
            _previousStatuses[requestId] = currentStatus;
          }
          _isInitialLoad = false;
          return;
        }

        // After initial load, detect status changes
        for (var doc in snapshot.docs) {
          final requestId = doc.id;
          final data = doc.data();
          final currentStatus = data['status'] as String? ?? '';
          final previousStatus = _previousStatuses[requestId];

          // Detect status change from 'open' to 'responded' or 'accepted'
          if (previousStatus == 'open' && (currentStatus == 'responded' || currentStatus == 'accepted')) {
            final medicineName = data['medicineName'] as String? ?? '';
            final pharmacyId = data['acceptedBy'] as String?;
            
            // Capitalize first letter for better display
            final displayName = medicineName.isEmpty
                ? 'your request'
                : medicineName.length > 1
                    ? medicineName[0].toUpperCase() + medicineName.substring(1)
                    : medicineName.toUpperCase();
            
            // Fetch pharmacy name and show notification
            _fetchPharmacyNameAndNotify(pharmacyId, displayName);
          }

          // Update the previous status
          _previousStatuses[requestId] = currentStatus;
        }
      },
      onError: (error) {
        // Handle errors silently or log them
        debugPrint('Error listening to requests: $error');
      },
    );
  }

  /// Fetch pharmacy name from Firestore and show notification
  Future<void> _fetchPharmacyNameAndNotify(String? pharmacyId, String medicineName) async {
    String pharmacyName = 'a pharmacy';
    
    if (pharmacyId != null && pharmacyId.isNotEmpty) {
      try {
        final pharmacyDoc = await FirebaseFirestore.instance
            .collection('pharmacists')
            .doc(pharmacyId)
            .get();
        
        if (pharmacyDoc.exists) {
          final pharmacyData = pharmacyDoc.data() as Map<String, dynamic>?;
          pharmacyName = pharmacyData?['displayName'] as String? ?? 
                        pharmacyData?['pharmacyName'] as String? ?? 
                        pharmacyData?['name'] as String? ?? 
                        'Pharmacy';
        } else {
          // If not found in pharmacists, try using the ID as fallback
          pharmacyName = 'Pharmacy';
        }
      } catch (e) {
        // If error fetching, use default name
        pharmacyName = 'a pharmacy';
      }
    }
    
    if (mounted) {
      _showNotification(
        'Request Accepted!',
        'Your request for "$medicineName" has been accepted by $pharmacyName.',
      );
    }
  }

  void _showNotification(String title, String message) {
    if (!mounted) return;
    
    // Show system notification
    NotificationService().showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: message,
    );

    // Also show in-app SnackBar for visibility if app is open
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        elevation: 6,
      ),
    );
  }

  Future<void> _pickPrescription() async {
    final XFile? file =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    setState(() => _prescription = file);
  }

  Future<void> _initiateRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Please login first.');
      return;
    }
    
    final medicineName = _searchCtrl.text.trim();
    if (medicineName.isEmpty && _prescription == null) {
      _showSnack('Please enter medicine name or upload prescription');
      return;
    }

    if (_curLat == null || _curLng == null) {
      await _getCurrentLocation();
      if (_curLat == null || _curLng == null) {
        _showSnack('Unable to get precise location. Please ensure location services are enabled.');
        setState(() => _loading = false);
        return;
      }
    }

    setState(() => _loading = true);
    try {
      String? url;
      if (_prescription != null) {
        url = await RequestService.uploadPrescription(_prescription!);
      }
      
      final docRef = await RequestService.createRequest(
        userId: user.uid,
        medicineName: medicineName.isEmpty ? "Prescription Request" : medicineName,
        prescriptionUrl: url,
        broadcast: true,
        userLat: _curLat!,
        userLng: _curLng!,
        userAddress: _locationCtrl.text.trim(),
      );
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SearchingScreen(
              requestId: docRef.id,
              medicineName: medicineName.isEmpty ? "Prescription" : medicineName,
            ),
          ),
        );
      }
      
      setState(() => _prescription = null);
    } catch (e) {
      _showSnack('Failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadAndBroadcast() => _initiateRequest();

  void _showSnack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));


  Future<bool?> _showLogoutDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Do you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }


  Future<void> _showAISuggestions(String medicineName) async {
    if (medicineName.isEmpty) {
      _showSnack('Please enter a medicine name first');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.psychology, color: Colors.white),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'AI Alternatives',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: MLService.getAlternatives(medicineName),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Consulting AI Pharmacist...'),
                            ],
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Error: ${snapshot.error}\n\nMake sure the Python backend is running.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        );
                      }

                      final data = snapshot.data!;
                      final match = data['match'];
                      final alternatives = data['alternatives'] as List<dynamic>?;
                      final message = data['message'] as String?;

                      if (match == null && (alternatives == null || alternatives.isEmpty)) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              message ?? 'No results found.', 
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        );
                      }

                      return ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (match != null) 
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Best Match',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          match,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                          const Text(
                            'Suggested Alternatives',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (alternatives != null)
                            ...alternatives.map<Widget>((alt) {
                              final brand = alt['brand_name'];
                              final formula = alt['formula'];
                              final score = alt['match_score'];
                              final price = alt['price'];

                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  title: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(brand, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          score,
                                          style: TextStyle(
                                            color: Colors.blue.shade800,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text('Formula: $formula'),
                                      const SizedBox(height: 2),
                                      Text('Price: $price', style: const TextStyle(fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                  onTap: () {
                                    // Populate search bar with this alternative
                                    _searchCtrl.text = brand;
                                    Navigator.pop(context);
                                    // Trigger search logic?
                                  },
                                ),
                              );
                            }).toList(),
                            
                            const SizedBox(height: 20),
                            const Text(
                              'Disclaimer: These are AI-generated suggestions. Always consult a certified pharmacist or doctor before changing medication.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  int _currentIndex = 0;

  void _onNavItemTapped(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLogout = await _showLogoutDialog();
        if (shouldLogout == true && mounted) {
          await FirebaseAuth.instance.signOut();
          Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildDashboard(),
            _buildTrackerTab(),
            const ProfileScreen(),
            _buildAISuggestionsTab(),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildDashboard() {
    final presName = _prescription != null ? _prescription!.path.split('/').last : null;
    return SafeArea(
      child: Column(
        children: [
          _buildCustomHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildUnifiedSearchBar(),
                  const SizedBox(height: 12),
                  _buildFeatureButtons(),
                  const SizedBox(height: 16),
                  _buildMapSection(),
                  const SizedBox(height: 16),
                  if (presName != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        'Selected: $presName',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  _buildLocationCard(),
                  const SizedBox(height: 20),
                  _buildFindButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _buildPlaceholder('Tracker');

    return SafeArea(
      child: Column(
        children: [
          _buildCustomHeader(),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Tracker',
                  style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.track_changes, color: Color(0xFF007BFF)),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: RequestService.streamRequestsForUser(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyTrackerState();
                }

                final docs = snapshot.data!.docs;
                // Sort by creation time manually as per RequestService note
                final sortedDocs = docs.toList()
                  ..sort((a, b) {
                    final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
                    final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
                    return bTime.compareTo(aTime);
                  });

                final activeRequests = sortedDocs.where((doc) {
                  final status = doc.data()['status'] ?? '';
                  return status != 'completed' && status != 'cancelled';
                }).toList();

                if (activeRequests.isEmpty) {
                  return _buildEmptyTrackerState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: activeRequests.length,
                  itemBuilder: (context, index) {
                    final data = activeRequests[index].data();
                    return _buildRequestTrackingCard(data, activeRequests[index].id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTrackerState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            'No active orders found',
            style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Go to home to find medicines',
            style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => setState(() => _currentIndex = 0),
            child: const Text('Find Medicine'),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestTrackingCard(Map<String, dynamic> data, String requestId) {
    final status = data['status'] ?? 'open';
    final medicineName = data['medicineName'] ?? 'Medicine';
    
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[100]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              medicineName.toUpperCase(),
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'Order #$requestId'.substring(0, 15) + '...',
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildTrackingStepper(status),
                ],
              ),
            ),
            if (status != 'open') ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingMapScreen(requestId: requestId, initialData: data)));
                        },
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('Live Track'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007BFF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () => _openNavigation(data),
                        icon: const Icon(Icons.navigation_outlined, size: 18),
                        label: const Text('Navigate'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: requestId, title: 'Chat')));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.chat_bubble_outline, size: 20, color: Color(0xFF007BFF)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    switch (status) {
      case 'open':
        color = Colors.orange;
        text = 'Searching';
        break;
      case 'responded':
        color = Colors.blue;
        text = 'Responded';
        break;
      case 'accepted':
        color = Colors.teal;
        text = 'Confirmed';
        break;
      case 'delivering':
        color = Colors.purple;
        text = 'In Transit';
        break;
      case 'ready_for_pickup':
        color = Colors.green;
        text = 'Ready for Pickup';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTrackingStepper(String status) {
    int currentStep = 0;
    if (status == 'responded' || status == 'accepted') currentStep = 1;
    if (status == 'delivering' || status == 'ready_for_pickup') currentStep = 2;
    if (status == 'completed') currentStep = 3;

    return Row(
      children: [
        _stepperNode('Req', currentStep >= 0),
        _stepperLine(currentStep >= 1),
        _stepperNode('Appr', currentStep >= 1),
        _stepperLine(currentStep >= 2),
        _stepperNode('Proc', currentStep >= 2),
        _stepperLine(currentStep >= 3),
        _stepperNode('End', currentStep >= 3),
      ],
    );
  }

  Widget _stepperNode(String label, bool active) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF007BFF) : Colors.grey[200],
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 8, color: active ? Colors.black87 : Colors.grey)),
      ],
    );
  }

  Widget _stepperLine(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 12),
        color: active ? const Color(0xFF007BFF).withOpacity(0.5) : Colors.grey[200],
      ),
    );
  }

  void _openNavigation(Map<String, dynamic> data) {
    final status = data['status'] ?? '';
    
    // If delivering, try to navigate to rider's current location first
    if (status == 'delivering') {
      final rLat = (data['riderLat'] as num?)?.toDouble();
      final rLng = (data['riderLng'] as num?)?.toDouble();
      if (rLat != null && rLng != null) {
        MapsLauncher.launchCoordinates(rLat, rLng, 'Rider Location');
        return;
      }
    }

    // Otherwise navigate to Pharmacy
    final pLat = (data['pharmacyLat'] as num?)?.toDouble() ?? (data['lat'] as num?)?.toDouble();
    final pLng = (data['pharmacyLng'] as num?)?.toDouble() ?? (data['lng'] as num?)?.toDouble();
    
    if (pLat != null && pLng != null) {
      MapsLauncher.launchCoordinates(pLat, pLng, 'Pharmacy Location');
    } else {
      _showSnack('Location not available');
    }
  }

  Widget _buildAISuggestionsTab() {
    return SafeArea(
      child: Column(
        children: [
          _buildCustomHeader(),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Medicine Link',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                Text(
                  'Find smart alternatives powered by ML',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFBFBFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: TextField(
                controller: _aiSearchCtrl,
                onSubmitted: (value) {
                  setState(() => _aiQuery = value.trim());
                },
                decoration: InputDecoration(
                  hintText: 'Enter medicine name...',
                  hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
                  prefixIcon: Icon(Icons.psychology, color: Colors.blueAccent),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search, color: Colors.blueAccent),
                    onPressed: () {
                      setState(() => _aiQuery = _aiSearchCtrl.text.trim());
                    },
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _aiQuery.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.medication_outlined, size: 60, color: Colors.grey[200]),
                        const SizedBox(height: 16),
                        Text(
                          'Enter a medicine name above\nto find alternatives',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  )
                : FutureBuilder<Map<String, dynamic>>(
                    future: MLService.getAlternatives(_aiQuery),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || (snapshot.hasData && snapshot.data!['match'] == null && (snapshot.data!['alternatives'] as List).isEmpty)) {
                         return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, size: 48, color: Colors.orange[200]),
                                const SizedBox(height: 16),
                                Text(
                                  snapshot.hasError 
                                    ? 'Error connecting to ML Service' 
                                    : (snapshot.data?['message'] ?? 'No results found for "$_aiQuery"'),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final data = snapshot.data!;
                      final match = data['match'];
                      final alternatives = data['alternatives'] as List<dynamic>?;

                      return ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          if (match != null) ...[
                            _buildAISectionTitle('Best Match'),
                            const SizedBox(height: 12),
                            _buildAIMatchCard(match),
                            const SizedBox(height: 24),
                          ],
                          if (alternatives != null && alternatives.isNotEmpty) ...[
                            _buildAISectionTitle('Suggested Alternatives'),
                            const SizedBox(height: 12),
                            ...alternatives.map((alt) => _buildAIAltCard(alt)).toList(),
                          ],
                          const SizedBox(height: 20),
                          const Text(
                            'Disclaimer: These are AI-generated suggestions. Always consult a professional.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.orange, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAISectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: Colors.grey[400],
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildAIMatchCard(String name) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueAccent, Colors.blueAccent.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Direct Formula Match',
                  style: GoogleFonts.inter(color: Colors.white.withOpacity(0.8), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAltCard(dynamic alt) {
    final brand = alt['brand_name'] ?? 'Unknown';
    final formula = alt['formula'] ?? 'N/A';
    final score = alt['match_score'] ?? '0%';
    final price = alt['price'] ?? 'N/A';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[100]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(brand, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                score,
                style: GoogleFonts.inter(
                  color: Colors.blue[700],
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('Formula: $formula', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text('Price: $price', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black87)),
          ],
        ),
        trailing: Icon(Icons.add_circle_outline, color: Colors.blueAccent),
        onTap: () {
          _searchCtrl.text = brand;
          setState(() => _currentIndex = 0);
          _showSnack('Selected $brand. You can now tap FIND to search stores.');
        },
      ),
    );
  }

  Widget _buildPlaceholder(String title) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
            Text('Coming Soon!', style: GoogleFonts.inter(color: Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => setState(() => _currentIndex = 0),
              icon: const Icon(Icons.home_outlined, size: 18),
              label: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomHeader() {
    return FadeInDown(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            Text(
              'CONNECT-PHARMA',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.notifications_none_outlined),
              onPressed: () => _showSnack('Notifications'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedSearchBar() {
    return FadeInUp(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFBFBFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextField(
            controller: _searchCtrl,
            onSubmitted: (_) => _initiateRequest(),
            decoration: InputDecoration(
              hintText: 'Search Medicine Nearby You',
              hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
              prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureButtons() {
    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            _featureButton(
              'Upload Prescription',
              const Color(0xFF007BFF),
              Colors.white,
              Icons.upload_file_outlined,
              _pickPrescription,
            ),
            const SizedBox(height: 12),
            _featureButton(
              'Ask For Suggestions',
              const Color(0xFFE7F3FF),
              const Color(0xFF007BFF),
              Icons.psychology_outlined,
              () => _showAISuggestions(_searchCtrl.text.trim()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureButton(String text, Color bgColor, Color textColor, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : onTap,
        icon: Icon(icon, size: 20),
        label: Text(
          text,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    return FadeInUp(
      delay: const Duration(milliseconds: 300),
      child: Container(
        height: 220,
        margin: const EdgeInsets.symmetric(horizontal: 24.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _mapLoading
              ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
                  onMapCreated: (controller) => _mapController = controller,
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition,
                    zoom: 14,
                  ),
                  mapType: MapType.normal,
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
        ),
      );
  }

  Widget _buildLocationCard() {
    return FadeInUp(
      delay: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Location',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                TextButton.icon(
                  onPressed: _mapLoading ? null : _getCurrentLocation,
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text('Live', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF007BFF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFBFBFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: TextField(
                controller: _locationCtrl,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
                onSubmitted: (value) => _getLatLngFromAddress(value),
                decoration: InputDecoration(
                  hintText: 'Enter your address manually',
                  hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
                  prefixIcon: Icon(Icons.location_on_outlined, color: Colors.grey[400], size: 20),
                  suffixIcon: _geocodingLoading 
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search, size: 20),
                        onPressed: () => _getLatLngFromAddress(_locationCtrl.text),
                      ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFindButton() {
    return FadeInUp(
      delay: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _initiateRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007BFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              elevation: 4,
              shadowColor: const Color(0xFF007BFF).withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    'FIND',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: _onNavItemTapped,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF007BFF),
      unselectedItemColor: Colors.grey[400],
      selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
      unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.track_changes), label: 'Tracker'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Account'),
        BottomNavigationBarItem(icon: Icon(Icons.bubble_chart_outlined), label: 'AI'),
      ],
    );
  }
}

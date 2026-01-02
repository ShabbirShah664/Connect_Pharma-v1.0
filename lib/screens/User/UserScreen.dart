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
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:connect_pharma/screens/User/SearchingScreen.dart';
import 'package:connect_pharma/screens/User/ProfileScreen.dart';

class UserScreen extends StatefulWidget {
  // ... existing code ...

  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final _searchCtrl = TextEditingController();
  bool _loading = false;
  XFile? _prescription;
  final ImagePicker _picker = ImagePicker();
  // Track previous request statuses to detect changes
  final Map<String, String> _previousStatuses = {};
  bool _isInitialLoad = true;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _requestSubscription;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng _currentPosition = const LatLng(24.8607, 67.0011); // Default Karachi
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
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _mapLoading = false;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_currentPosition),
        );
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) setState(() => _mapLoading = false);
    }
  }

  Future<void> _fetchPharmacyMarkers() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('pharmacists').get();
      final newMarkers = snapshot.docs.map((doc) {
        final data = doc.data();
        final lat = data['lat'] as double? ?? data['pharmacyLat'] as double?;
        final lng = data['lng'] as double? ?? data['pharmacyLng'] as double?;
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
        userLat: _currentPosition.latitude,
        userLng: _currentPosition.longitude,
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
        backgroundColor: const Color(0xFFF8F9FA),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _profileHeader(),
                const SizedBox(height: 8),
                _searchBar(),
                const SizedBox(height: 12),
                _actionButtons(),
                const SizedBox(height: 12),
                _mapPlaceholder(),
                const SizedBox(height: 8),
                _recentRequestsCard(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  Widget _profileHeader() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'Guest User';
    final email = user?.email ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      child: Row(children: [
        CircleAvatar(radius: 26, child: const Icon(Icons.person)),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(displayName,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(email, style: const TextStyle(color: Colors.grey)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            final shouldLogout = await _showLogoutDialog();
            if (shouldLogout == true && mounted) {
              await FirebaseAuth.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
            }
          },
        )
      ]),
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

  // Updated _searchBar to trigger AI on submit if configured, currently kept standard
  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search medicine by name',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            onSubmitted: (_) => _initiateRequest(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
            icon: const Icon(Icons.upload_file), onPressed: _pickPrescription),
      ]),
    );
  }

  Widget _actionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      child: Row(children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _loading ? null : _uploadAndBroadcast,
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Upload Prescription'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: () => _showAISuggestions(_searchCtrl.text.trim()),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Ask For Suggestions'),
          ),
        ),
      ]),
    );
  }

  Widget _mapPlaceholder() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      height: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _mapLoading 
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  onMapCreated: (controller) => _mapController = controller,
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition,
                    zoom: 14,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
          ),
          // Search pharmacies overlay
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Search nearby pharmacies...',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // My Location Button
          Positioned(
            bottom: 12,
            right: 12,
            child: FloatingActionButton.small(
              onPressed: _getCurrentLocation,
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentRequestsCard() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Requests',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: RequestService.streamRequestsForUser(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text('Error: ${snapshot.error}'),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Center(
                      child: Text(
                        'No requests yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ),
                );
              }

              final docs = snapshot.data!.docs;
              
              // Sort documents by createdAt (most recent first) since we removed orderBy from query
              final sortedDocs = docs.toList()
                ..sort((a, b) {
                  final aTime = a.data()['createdAt'] as Timestamp?;
                  final bTime = b.data()['createdAt'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime); // Descending order (most recent first)
                });

              return Column(
                children: sortedDocs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final doc = entry.value;
                  final data = doc.data();
                  final status = data['status'] as String? ?? 'unknown';
                  final medicineName = data['medicineName'] as String? ?? '';
                  final createdAt = data['createdAt'] as Timestamp?;
                  final acceptedBy = data['acceptedBy'] as String?;
                  final prescriptionUrl = data['prescriptionUrl'] as String?;

                  // Format medicine name
                  final displayName = medicineName.isEmpty
                      ? 'Unknown Medicine'
                      : medicineName.length > 1
                          ? medicineName[0].toUpperCase() + medicineName.substring(1)
                          : medicineName.toUpperCase();

                  // Determine status color and icon
                  Color statusColor;
                  IconData statusIcon;
                  String statusText;

                  switch (status) {
                    case 'responded':
                      statusColor = Colors.green;
                      statusIcon = Icons.store;
                      statusText = 'Pharmacist Responded';
                      break;
                    case 'accepted':
                      statusColor = Colors.green;
                      statusIcon = Icons.check_circle;
                      statusText = 'Accepted (Delivery)';
                      break;
                    case 'delivering':
                      statusColor = Colors.orange;
                      statusIcon = Icons.delivery_dining;
                      statusText = 'Out for Delivery';
                      break;
                    case 'open':
                      statusColor = Colors.orange;
                      statusIcon = Icons.pending;
                      statusText = 'Pending';
                      break;
                    case 'cancelled':
                      statusColor = Colors.grey;
                      statusIcon = Icons.cancel;
                      statusText = 'Cancelled';
                      break;
                    case 'completed':
                      statusColor = Colors.blue;
                      statusIcon = Icons.done_all;
                      statusText = 'Completed';
                      break;
                    case 'ready_for_pickup':
                      statusColor = Colors.green;
                      statusIcon = Icons.store;
                      statusText = 'Ready for Pickup';
                      break;
                    default:
                      statusColor = Colors.grey;
                      statusIcon = Icons.help_outline;
                      statusText = status;
                  }

                  // Changed list tile to be inside a column to allow extra buttons at bottom
                  return FadeInSlide(
                    index: index,
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: (status == 'accepted' || status == 'delivering') ? 4 : 2,
                      color: (status == 'accepted' || status == 'delivering') ? Colors.green.shade50 : null,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: statusColor.withOpacity(0.2),
                              child: Icon(statusIcon, color: statusColor, size: 24),
                            ),
                            title: Text(
                              displayName,
                              style: TextStyle(
                                fontWeight: (status == 'responded' || status == 'accepted' || status == 'delivering')
                                    ? FontWeight.bold 
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(statusIcon, 
                                         color: statusColor, 
                                         size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if ((status == 'responded' || status == 'accepted' || status == 'delivering' || status == 'ready_for_pickup') && acceptedBy != null)
                                      FutureBuilder<DocumentSnapshot>(
                                        future: FirebaseFirestore.instance
                                            .collection('pharmacists')
                                            .doc(acceptedBy)
                                            .get(),
                                        builder: (context, pharmacySnapshot) {
                                          if (pharmacySnapshot.hasData &&
                                              pharmacySnapshot.data!.exists) {
                                            final pharmacyData = 
                                                pharmacySnapshot.data!.data() as Map<String, dynamic>?;
                                            final pharmacyName = 
                                                pharmacyData?['displayName'] as String? ?? 
                                                pharmacyData?['pharmacyName'] as String? ?? 
                                                pharmacyData?['name'] as String? ?? 
                                                'Pharmacy';
                                            return Padding(
                                              padding: const EdgeInsets.only(left: 8),
                                              child: Text(
                                                'by $pharmacyName',
                                                style: TextStyle(
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                  ],
                                ),
                                if (status == 'responded' && data['pharmacyLat'] != null) ...[
                                  const SizedBox(height: 12),
                                  const Text('Pharmacy Location:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 120,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: GoogleMap(
                                        initialCameraPosition: CameraPosition(
                                          target: LatLng(data['pharmacyLat'], data['pharmacyLng']),
                                          zoom: 14,
                                        ),
                                        markers: {
                                          Marker(
                                            markerId: const MarkerId('pharmacy'),
                                            position: LatLng(data['pharmacyLat'], data['pharmacyLng']),
                                          ),
                                        },
                                        liteModeEnabled: true, // Optimized for list views
                                        zoomGesturesEnabled: false,
                                        scrollGesturesEnabled: false,
                                      ),
                                    ),
                                  ),
                                ],
                                if (createdAt != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatTimestamp(createdAt),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Add buttons if responded, accepted or delivering
                          if (status == 'responded')
                            _buildDecisionOptions(doc.id, data),
                          if (status == 'ready_for_pickup')
                            _buildPickupReadyOption(doc.id, data),
                          if (status == 'accepted')
                            _buildAcceptedOptions(doc.id, data),
                          if (status == 'delivering')
                             _buildTrackDeliveryOption(doc.id, data),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrackDeliveryOption(String requestId, Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DeliveryScreen(
                  requestId: requestId,
                  requestData: data,
                ),
              ),
            );
          },
          icon: const Icon(Icons.location_on),
          label: const Text('Track Delivery & Chat'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildDecisionOptions(String requestId, Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                // Change status to 'accepted' to notify riders
                await RequestService.updateRequestStatus(requestId, 'accepted');
              },
              icon: const Icon(Icons.delivery_dining, size: 18),
              label: const Text('Home Delivery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                // Change status to 'ready_for_pickup'
                await RequestService.updateRequestStatus(requestId, 'ready_for_pickup');
                if (mounted) {
                   Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SelfPickupScreen(
                        requestId: requestId,
                        requestData: data,
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.store, size: 18),
              label: const Text('Self Pickup'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupReadyOption(String requestId, Map<String, dynamic> data) {
     return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SelfPickupScreen(
                  requestId: requestId,
                  requestData: data,
                ),
              ),
            );
          },
          icon: const Icon(Icons.store),
          label: const Text('View Pharmacy & Pickup'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildAcceptedOptions(String requestId, Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeliveryScreen(
                      requestId: requestId,
                      requestData: data,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.delivery_dining, size: 18),
              label: const Text('View Delivery Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final time = timestamp.toDate();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  int _currentIndex = 0;

  void _onNavItemTapped(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboard(),
          _buildPlaceholder('Tracker'),
          const ProfileScreen(),
          _buildPlaceholder('AI Suggestions'),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
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
            ElevatedButton(
              onPressed: () => setState(() => _currentIndex = 0),
              child: const Text('Go Home'),
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
              _pickPrescription,
            ),
            const SizedBox(height: 12),
            _featureButton(
              'Ask For Suggestions',
              const Color(0xFFE7F3FF),
              const Color(0xFF007BFF),
              () => _showAISuggestions(_searchCtrl.text.trim()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureButton(String text, Color bgColor, Color textColor, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
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
          image: const DecorationImage(
            image: NetworkImage('https://via.placeholder.com/600x400/F5F5F5/808080?text=Map+Preview'),
            fit: BoxFit.cover,
            opacity: 0.6,
          ),
        ),
        child: const Center(
          child: Icon(Icons.location_on, color: Colors.red, size: 40),
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
            Text(
              'Select Location',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your Location',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '2572 Westhaven Rd, Santa Ana, Illinois 63456', // Dummy address as per image
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
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

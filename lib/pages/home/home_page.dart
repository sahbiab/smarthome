import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import '../../utils/app_colors.dart';
import '../camera/camera_page.dart';
import '../face_recognition/add_person_page.dart';
import '../rooms/room_detail_page.dart';
import '../../services/notification_service.dart'; // ⭐ NEW: Import NotificationService

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _auth = FirebaseAuth.instance;
  int _selectedIndex = 0;
  Timer? _timer;
  String _currentTime = "";

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _setupAlertListener();
    _startClock();
  }
  
  void _startClock() {
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 10), (Timer t) => _updateTime());
  }
  
  void _updateTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    setState(() {
      _currentTime = '$hour:$minute';
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _setupAlertListener() {
    // Listen to old alerts path (unknown faces from Raspberry Pi)
    final DatabaseReference alertsRef = FirebaseDatabase.instance.ref('alerts');
    
    alertsRef.limitToLast(1).onChildAdded.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final timestamp = data['timestamp'] as int? ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        final key = event.snapshot.key; // Get the key
        
        // Show alert only if it's recent (< 10 seconds ago)
        if (now - timestamp < 10000) { 
           _showSecurityAlert(data, 'unknown_face', key, 'alerts');
        }
      }
    });

    // ⭐ NEW: Listen to smart_home/notifications path (button alerts from ESP32)
    final DatabaseReference notificationsRef = FirebaseDatabase.instance.ref('smart_home/notifications');
    
    notificationsRef.limitToLast(1).onChildAdded.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final timestamp = data['timestamp'] as int? ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        final type = data['type'] as String? ?? 'unknown';
        final key = event.snapshot.key; // Get the key
        
        // Show alert only if it's recent (< 10 seconds ago)
        if (now - timestamp < 10000) { 
           _showSecurityAlert(data, type, key, 'smart_home/notifications');
        }
      }
    });
  }

  void _showSecurityAlert(Map<dynamic, dynamic> data, String type, [String? key, String? dbPath]) {
    // Determine icon and title based on type
    IconData alertIcon;
    String alertTitle;
    String alertMessage;
    Color backgroundColor;

    if (type == 'unknown_button') {
      alertIcon = Icons.touch_app_rounded;
      alertTitle = "BUTTON ALERT";
      alertMessage = data['message'] ?? "Bouton poussoir inconnu détecté!";
      backgroundColor = Colors.orange[900]!;
    } else {
      // unknown_face or default
      alertIcon = Icons.warning_amber_rounded;
      alertTitle = "SECURITY ALERT";
      alertMessage = "Unknown Person Detected!";
      backgroundColor = Colors.red[900]!;
    }

    // Trigger local notification in system tray immediately
    NotificationService().showLocalNotification(
      title: alertTitle,
      body: alertMessage,
      type: type,
      payload: type,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Row(
          children: [
            Icon(alertIcon, color: Colors.white),
            const SizedBox(width: 10),
            Text(alertTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              alertMessage,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (data['imageUrl'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  data['imageUrl'],
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => const Icon(Icons.person_off, color: Colors.white, size: 50),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? 0).toString(),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // ⭐ Delete from Firebase when dismissed
              if (key != null && dbPath != null) {
                FirebaseDatabase.instance.ref(dbPath).child(key).remove().then((_) {
                  print("Deleted notification $key from $dbPath");
                }).catchError((error) {
                  print("Failed to delete notification: $error");
                });
              }
              Navigator.pop(context);
            },
            child: const Text("DISMISS", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("No user logged in", style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final userStream = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();

    Widget body;
    if (_selectedIndex == 0) {
      body = _buildHomeBody(userStream, user.uid);
    } else if (_selectedIndex == 1) {
      body = const CameraPage();
    } else {
      body = _buildRoomsPage();
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.cardDark,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: Colors.white70,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.videocam_rounded), label: "Camera"),
          BottomNavigationBarItem(icon: Icon(Icons.meeting_room), label: "Rooms"),
        ],
      ),
    );
  }

  Widget _buildHomeBody(Stream<DocumentSnapshot> userStream, String userId) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/bghome.jpg'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.5),
            BlendMode.darken,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: StreamBuilder<DocumentSnapshot>(
            stream: userStream,
            builder: (context, snapshot) {
              String? avatarUrl;
              String? cameraUrl;

              if (snapshot.hasData && snapshot.data?.data() != null) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                avatarUrl = data['avatarUrl'];
                cameraUrl = data['cameraUrl'];
              }

              ImageProvider avatarImage = avatarUrl != null && avatarUrl.startsWith('http')
                  ? NetworkImage(avatarUrl)
                  : const AssetImage('assets/images/avatar_placeholder.png');

              return LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    // Enhanced Header with time and avatar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Time display
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.2),
                                      Colors.white.withValues(alpha: 0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      color: Colors.white.withValues(alpha: 0.9),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _currentTime,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Welcome Back,",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [
                                    Colors.white,
                                    const Color(0xFFFFD54F),
                                  ],
                                ).createShader(bounds),
                                child: const Text(
                                  "Smart Home",
                                  style: TextStyle(
                                    fontSize: 34,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Enhanced Avatar with status
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, "/profile"),
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFFFFB74D).withValues(alpha: 0.4),
                                      const Color(0xFFFF9800).withValues(alpha: 0.4),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFB74D).withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(3),
                                child: CircleAvatar(
                                  radius: 28,
                                  backgroundImage: avatarImage,
                                ),
                              ),
                              // Online status indicator
                              Positioned(
                                right: 2,
                                bottom: 2,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF5D4037),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.withValues(alpha: 0.6),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 28),
                    
                    // Camera Section with status badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Your Camera",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        // Camera status badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                (cameraUrl != null && cameraUrl.isNotEmpty)
                                    ? Colors.green.withValues(alpha: 0.3)
                                    : Colors.orange.withValues(alpha: 0.3),
                                (cameraUrl != null && cameraUrl.isNotEmpty)
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.orange.withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: (cameraUrl != null && cameraUrl.isNotEmpty)
                                  ? Colors.green.withValues(alpha: 0.4)
                                  : Colors.orange.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: (cameraUrl != null && cameraUrl.isNotEmpty)
                                      ? Colors.green
                                      : Colors.orange,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (cameraUrl != null && cameraUrl.isNotEmpty)
                                          ? Colors.green.withValues(alpha: 0.6)
                                          : Colors.orange.withValues(alpha: 0.6),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                (cameraUrl != null && cameraUrl.isNotEmpty) ? "Active" : "Not Set",
                                style: TextStyle(
                                  color: (cameraUrl != null && cameraUrl.isNotEmpty)
                                      ? Colors.green
                                      : Colors.orange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: GestureDetector(
                          onTap: () {
                            if (cameraUrl != null && cameraUrl.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const CameraPage()),
                              );
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.15),
                                  Colors.white.withValues(alpha: 0.05),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: (cameraUrl == null || cameraUrl.isEmpty)
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.videocam_off_outlined,
                                            size: 48,
                                            color: Colors.white.withValues(alpha: 0.6),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            "No camera URL set",
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.8),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Go to Profile to add it",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.5),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Mjpeg(
                                      stream: cameraUrl,
                                      isLive: true,
                                      fit: BoxFit.cover,
                                      timeout: const Duration(seconds: 4),
                                      error: (context, error, stack) => _cameraErrorWidget(error),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Access Control Section with enhanced header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Access Control",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.withValues(alpha: 0.3),
                                Colors.orange.withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.security,
                                color: Colors.orange,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Raspberry Pi",
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Enhanced Face Recognition Card
                    _enhancedFeatureCard(
                      context,
                      "Add Person",
                      "Register new face with multi-angle capture",
                      null,
                      [const Color(0xFFFFB74D), const Color(0xFFFF9800)],
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddPersonPage()),
                        );
                      },
                      imagePath: 'assets/images/avatar_placeholder.jpg',
                    ),
                    
                    
                    const SizedBox(height: 28),
                    
                    // Gas Detection Section
                    Text(
                      "Environmental Monitoring",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _gasDetectionCard(userId),
                    
                    const SizedBox(height: 28),
                    
                    // Door Control Section
                    Text(
                      "Smart Access",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _doorControlCard(userId),

                    const SizedBox(height: 28),
                    
                    // Note: LED Control moved to Room Detail Pages

                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }


  Widget _enhancedFeatureCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData? icon,
    List<Color> gradientColors,
    VoidCallback onTap, {
    String? imagePath,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.15),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon or Image with gradient background
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: imagePath == null ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ) : null,
                boxShadow: [
                  BoxShadow(
                    color: gradientColors[0].withValues(alpha: 0.6),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: imagePath != null
                  ? ClipOval(
                      child: Image.asset(
                        imagePath,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(
                      icon!,
                      color: Colors.white,
                      size: 32,
                    ),
            ),
            const SizedBox(width: 20),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow icon
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: gradientColors[0],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomsPage() {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/bghome.jpg'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.5),
            BlendMode.darken,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Smart Rooms",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Control your home devices",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withValues(alpha: 0.3),
                          Colors.green.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "4 Active",
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Room cards grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.count(
                  physics: const BouncingScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    _modernRoomCard(
                      "Kitchen",
                      Icons.restaurant_rounded,
                      [const Color(0xFFFFD54F), const Color(0xFFFFA726)],
                      true,
                      "3 devices",
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoomDetailPage(
                              roomName: "Kitchen",
                              roomIcon: Icons.restaurant_rounded,
                              gradientColors: [const Color(0xFFFFD54F), const Color(0xFFFFA726)],
                            ),
                          ),
                        );
                      },
                    ),
                    _modernRoomCard(
                      "Bedroom",
                      Icons.bed_rounded,
                      [const Color(0xFFE040FB), const Color(0xFFAB47BC)],
                      true,
                      "All secure",
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoomDetailPage(
                              roomName: "Bedroom",
                              roomIcon: Icons.bed_rounded,
                              gradientColors: [const Color(0xFFE040FB), const Color(0xFFAB47BC)],
                            ),
                          ),
                        );
                      },
                    ),
                    _modernRoomCard(
                      "Living Room",
                      Icons.weekend_rounded,
                      [const Color(0xFF00b0ff), const Color(0xFF0091ea)],
                      true,
                      "22°C",
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoomDetailPage(
                              roomName: "Living Room",
                              roomIcon: Icons.weekend_rounded,
                              gradientColors: [const Color(0xFF00b0ff), const Color(0xFF0091ea)],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modernRoomCard(
    String title,
    IconData icon,
    List<Color> gradientColors,
    bool isActive,
    String status,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.15),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: gradientColors[0].withValues(alpha: 0.6),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: Colors.green.withValues(alpha: 0.6),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ],
              ),
              
              // Title and status
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cameraErrorWidget(Object error) {
    return Container(
      color: AppColors.cardDark,
      child: Center(
        child: Text("Camera offline", style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
      ),
    );
  }



  // Gas Detection Card with Firebase Realtime Database
  Widget _gasDetectionCard(String userId) {
    final DatabaseReference gasRef = FirebaseDatabase.instance.ref('smart_home/sensors/gas');
    
    return StreamBuilder<DatabaseEvent>(
      stream: gasRef.onValue,
      builder: (context, snapshot) {
        double gasLevel = 0;
        String gasStatus = "safe";
        
        if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
          final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          gasLevel = (data['level'] ?? 0).toDouble();
          gasStatus = data['status'] ?? 'safe';
        }
        
        Color statusColor;
        IconData statusIcon;
        String statusText;
        
        if (gasStatus == 'danger' || gasLevel > 2000) {
          statusColor = Colors.red;
          statusIcon = Icons.warning_rounded;
          statusText = 'DANGER';
        } else if (gasStatus == 'warning' || gasLevel > 1200) {
          statusColor = Colors.orange;
          statusIcon = Icons.warning_amber_rounded;
          statusText = 'WARNING';
        } else {
          statusColor = Colors.green;
          statusIcon = Icons.check_circle_rounded;
          statusText = 'SAFE';
        }
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.air_rounded,
                          color: statusColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Gas Sensor",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Air Quality Monitor",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Gas level indicator
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${gasLevel.toInt()} PPM",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                color: statusColor.withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: (gasLevel / 1000).clamp(0.0, 1.0),
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "0 - 1000 PPM range",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Door Control Card with Firebase Realtime Database
  Widget _doorControlCard(String userId) {
    final DatabaseReference doorRef = FirebaseDatabase.instance.ref('smart_home/doors/main_door');
    
    return StreamBuilder<DatabaseEvent>(
      stream: doorRef.onValue,
      builder: (context, snapshot) {
        int doorPosition = 0;
        String doorStatus = "closed";
        
        if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
          final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          // Clamp value to max 90 to prevent Slider crash if Firebase has old 180 value
          doorPosition = (data['position'] ?? 0).toInt().clamp(0, 90);
          doorStatus = data['status'] ?? 'closed';
        }
        
        bool isOpen = doorStatus == 'open' || doorPosition > 45;
        Color statusColor = isOpen ? const Color(0xFF00e676) : const Color(0xFF00b0ff);
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isOpen ? Icons.door_sliding_rounded : Icons.door_back_door_rounded,
                          color: statusColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Main Door",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Servo Motor Control",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      doorStatus.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Position display
              Row(
                children: [
                  Text(
                    "$doorPosition°",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: statusColor.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: statusColor,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                        thumbColor: statusColor,
                        overlayColor: statusColor.withValues(alpha: 0.2),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                        trackHeight: 6,
                      ),
                      child: Slider(
                        value: doorPosition.toDouble(),
                        min: 0,
                        max: 90, // Changed from 180 to 90
                        onChanged: (value) {
                          // Update Firebase with new position
                          doorRef.update({
                            'position': value.toInt(),
                            'status': value < 10 ? 'closed' : (value > 80 ? 'open' : 'partially_open'),
                            'lastUpdated': ServerValue.timestamp,
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Control buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        doorRef.update({
                          'position': 0,
                          'status': 'closed',
                          'lastUpdated': ServerValue.timestamp,
                        });
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00b0ff).withValues(alpha: 0.3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: const Color(0xFF00b0ff).withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        doorRef.update({
                          'position': 90, // Changed from 180 to 90
                          'status': 'open',
                          'lastUpdated': ServerValue.timestamp,
                        });
                      },
                      icon: const Icon(Icons.door_sliding_rounded, size: 18),
                      label: const Text('Open'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00e676).withValues(alpha: 0.3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: const Color(0xFF00e676).withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // LED Control Card with Firebase Realtime Database
  Widget _ledControlCard(String userId) {
    final DatabaseReference ledRef = FirebaseDatabase.instance.ref('smart_home/lights/main_led');
    
    return StreamBuilder<DatabaseEvent>(
      stream: ledRef.onValue,
      builder: (context, snapshot) {
        bool isOn = false;
        int brightness = 255;
        
        if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
          final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          isOn = data['state'] ?? false;
          brightness = (data['brightness'] ?? 255).toInt();
        }
        
        Color statusColor = isOn ? const Color(0xFFFFD54F) : Colors.grey;
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isOn ? Icons.lightbulb : Icons.lightbulb_outline,
                          color: statusColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "LED Light",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Smart LED Control",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Toggle switch
                  Transform.scale(
                    scale: 0.9,
                    child: Switch(
                      value: isOn,
                      onChanged: (value) {
                        ledRef.update({
                          'state': value,
                          'lastUpdated': ServerValue.timestamp,
                        });
                      },
                      activeThumbColor: const Color(0xFFFFD54F),
                      activeTrackColor: const Color(0xFFFFD54F).withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Brightness control
              if (isOn) ...[
                Row(
                  children: [
                    Icon(
                      Icons.brightness_low,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Brightness",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                "${((brightness / 255) * 100).toInt()}%",
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: statusColor,
                              inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                              thumbColor: statusColor,
                              overlayColor: statusColor.withValues(alpha: 0.2),
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                              trackHeight: 6,
                            ),
                            child: Slider(
                              value: brightness.toDouble(),
                              min: 0,
                              max: 255,
                              divisions: 255,
                              onChanged: (value) {
                                ledRef.update({
                                  'brightness': value.toInt(),
                                  'lastUpdated': ServerValue.timestamp,
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.brightness_high,
                      color: statusColor,
                      size: 24,
                    ),
                  ],
                ),
              ] else ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "Turn on to adjust brightness",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class RoomDetailPage extends StatefulWidget {
  final String roomName;
  final IconData roomIcon;
  final List<Color> gradientColors;

  const RoomDetailPage({
    super.key,
    required this.roomName,
    required this.roomIcon,
    required this.gradientColors,
  });

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  late DatabaseReference _roomRef;
  late DatabaseReference _climateRef;

  @override
  void initState() {
    super.initState();
    // Determine the room ID based on the room name
    String roomId = _getRoomId(widget.roomName);
    _roomRef = FirebaseDatabase.instance.ref('rooms/$roomId');
    _climateRef = FirebaseDatabase.instance.ref('climate');
  }

  String _getRoomId(String name) {
    if (name.toLowerCase().contains("kitchen")) return "kitchen";
    if (name.toLowerCase().contains("bedroom")) return "bedroom";
    if (name.toLowerCase().contains("living")) return "living";
    return "living"; // Default
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Full Screen Background Image
          Positioned.fill(
            child: Image.asset(
              _getRoomImage(),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: Colors.grey[900]);
              },
            ),
          ),

          // 2. Gradient Overlay for readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                  stops: const [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // 3. Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Back button)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),

                const Spacer(),

                // Room Title & Climate Info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.roomName,
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w300,
                                color: Colors.white,
                                letterSpacing: -1.0,
                              ),
                            ),
                          ),
                          // Climate Badge (DHT11 Data)
                          StreamBuilder<DatabaseEvent>(
                            stream: _climateRef.onValue,
                            builder: (context, snapshot) {
                              double temp = 0;
                              if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
                                final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                                temp = (data['temperature'] ?? 0).toDouble();
                              }

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: widget.gradientColors[0].withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.thermostat, color: Colors.white, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${temp.toStringAsFixed(1)}°C",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Active Devices count (visual estimate)
                      StreamBuilder<DatabaseEvent>(
                        stream: _roomRef.onValue,
                        builder: (context, snapshot) {
                          int activeCount = 0;
                          if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
                            final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                            data.forEach((key, value) {
                              if (value == true) activeCount++;
                            });
                          }
                          return Text(
                            "$activeCount devices active",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Devices Control Panel
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    border: Border(
                      top: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "SCENES & DEVICES",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Horizontal List of Devices
                          SizedBox(
                            height: 140,
                            child: StreamBuilder<DatabaseEvent>(
                              stream: _roomRef.onValue,
                              builder: (context, snapshot) {
                                Map<dynamic, dynamic> roomData = {};
                                if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
                                  roomData = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                                }

                                List<Widget> deviceCards = [];

                                // 1. Main Light (Available in all rooms)
                                bool lightStatus = roomData['light'] ?? false;
                                deviceCards.add(_deviceCard(
                                  'Light Bulb',
                                  Icons.lightbulb_outline_rounded,
                                  lightStatus,
                                  [const Color(0xFFFFD54F), const Color(0xFFFFA726)],
                                  () => _roomRef.update({'light': !lightStatus}),
                                ));

                                // 2. Smart Window (Servo) - Only in Living Room
                                if (widget.roomName.contains("Living")) {
                                  int windowPosition = (roomData['window'] ?? 0).toInt();
                                  deviceCards.add(const SizedBox(width: 16));
                                  deviceCards.add(_windowPositionCard(windowPosition));
                                }

                                // 3. Dummy TV (If requested, optional)
                                if (widget.roomName.contains("Living")) {
                                    deviceCards.add(const SizedBox(width: 16));
                                    deviceCards.add(_deviceCard(
                                    'Smart TV',
                                    Icons.tv_rounded,
                                    false, // Always off for now
                                    [const Color(0xFFE040FB), const Color(0xFFAB47BC)],
                                    () {}, // No action
                                    ));
                                }

                                return ListView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  children: deviceCards,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _deviceCard(
    String name,
    IconData icon,
    bool isActive,
    List<Color> gradientColors,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 130,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive 
              ? gradientColors[0].withValues(alpha: 0.9) 
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive 
                ? Colors.transparent 
                : Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: gradientColors[0].withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 8),
                  )
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  isActive ? "ON" : "OFF",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _windowPositionCard(int currentPosition) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF42A5F5).withValues(alpha: 0.9),
            const Color(0xFF1E88E5).withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF42A5F5).withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.window_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Text(
                '${currentPosition}°',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Smart Window',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currentPosition == 0 ? 'Closed' : currentPosition == 180 ? 'Fully Open' : 'Partially Open',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: currentPosition.toDouble(),
              min: 0,
              max: 180,
              divisions: 18,
              onChanged: (value) {
                _roomRef.update({'window': value.toInt()});
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getRoomImage() {
    switch (widget.roomName) {
      case 'Kitchen':
        return 'assets/images/kitchen.jpg';
      case 'Living Room':
        return 'assets/images/living_room.jpg';
      case 'Bedroom':
        return 'assets/images/bghome.jpg';
      default:
        return 'assets/images/bghome.jpg';
    }
  }
}

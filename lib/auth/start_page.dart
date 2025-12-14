import 'package:flutter/material.dart';
import 'package:smart_home_project/auth/login.dart';

class SmartHomeIntroPage extends StatelessWidget {
  const SmartHomeIntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ---------- BACKGROUND ----------
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/intro.jpg"),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // ---------- DARK OVERLAY ----------
          Container(color: Colors.black.withValues(alpha: 0.45)),

          // ---------- CONTENT ----------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height:70), 
                // ---------- TOP LOGO ----------
                Row(
                  children: [
                    Icon(
                      Icons.home_rounded,
                      color: Colors.orangeAccent,
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "SMARTHOME",
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: "Poppins",
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
                // ---------- BIG TITLE ----------
                Text(
                  "Easier Life\nwith Smart\nHome",
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: "Poppins",
                    fontSize: 38,
                    height: 1.1,
                    
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 20),

                // ---------- DESCRIPTION ----------
                Text(
                  "Welcome to a world where your home adapts to your needs "
                  "effortlessly, making your daily routine a breeze.",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontFamily: "Poppins",
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 300),

                // ---------- START BUTTON ----------
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage()),
                      );
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_open_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage()),
                      );
                    },
                    child: Text(
                      "Start",
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: "Poppins",
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 50), // bottom spacing
              ],
            ),
          ),
        ],
      ),
    );
  }
}

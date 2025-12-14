import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/app_colors.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  User? user;
  bool emailVerified = false;
  bool loading = true;

  TextEditingController nameController = TextEditingController();
  TextEditingController cameraUrlController = TextEditingController();

  String? avatarUrl;
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() {
      loading = true;
      errorMsg = null;
    });

    try {
      user = _auth.currentUser;
      if (user == null) {
        errorMsg = "User not logged in.";
        return;
      }

      await user!.reload();
      user = _auth.currentUser;

      emailVerified = user!.emailVerified;

      final doc = await _firestore.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        nameController.text = data['name'] ?? user!.displayName ?? "";
        avatarUrl = data['avatarUrl'];
        cameraUrlController.text = data['cameraUrl'] ?? "";
      } else {
        nameController.text = user!.displayName ?? "";
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
      errorMsg = "Failed to load profile data.";
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 500, maxHeight: 500);
    if (picked == null) return;

    setState(() {
      loading = true;
      errorMsg = null;
    });

    final file = File(picked.path);
    try {
      final ref = _storage.ref().child('avatars/${user!.uid}.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await _firestore.collection('users').doc(user!.uid).set({
        'avatarUrl': url,
      }, SetOptions(merge: true));

      setState(() {
        avatarUrl = url;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Avatar uploaded successfully")));
    } catch (e) {
      debugPrint("Upload avatar error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to upload avatar")));
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _selectAvatarFromBuiltIn() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        final avatars = [
          'assets/avatars/avatar1.jpg',
          'assets/avatars/avatar2.jpg',
          'assets/avatars/avatar3.jpg',
          'assets/avatars/avatar4.jpg',
          'assets/avatars/avatar5.jpg',
          'assets/avatars/avatar6.jpg',
          'assets/avatars/avatar7.jpg',
        ];
        return AlertDialog(
          title: const Text('Select Avatar'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: avatars.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(avatars[index]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: Image.asset(avatars[index], fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        avatarUrl = selected;
      });

      try {
        await _firestore.collection('users').doc(user!.uid).set({
          'avatarUrl': selected,
        }, SetOptions(merge: true));

        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Avatar updated")));
      } catch (e) {
        debugPrint("Error saving avatar selection: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Failed to update avatar")));
      }
    }
  }

  Future<void> _saveProfile() async {
    if (user == null) return;

    setState(() {
      loading = true;
      errorMsg = null;
    });

    try {
      await _firestore.collection('users').doc(user!.uid).set({
        'name': nameController.text.trim(),
        'cameraUrl': cameraUrlController.text.trim(),
      }, SetOptions(merge: true));

      await user!.updateDisplayName(nameController.text.trim());

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Profile updated")));
    } catch (e) {
      debugPrint("Save profile error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Failed to save profile")));
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    if (!emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please verify your email before signing out")));
      return;
    }
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed("/login");
  }

  Future<void> _sendVerificationEmail() async {
    try {
      await user?.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verification email sent")));
    } catch (e) {
      debugPrint("Email verification error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Failed to send verification email")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    if (errorMsg != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Profile"), backgroundColor: AppColors.background),
        body: Center(
          child: Text(
            errorMsg!,
            style: const TextStyle(color: Colors.red, fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.transparent,
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
            GestureDetector(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 55,
                backgroundColor: Colors.white12,
                backgroundImage: avatarUrl != null
                    ? (avatarUrl!.startsWith('http')
                        ? NetworkImage(avatarUrl!)
                        : AssetImage(avatarUrl!) as ImageProvider)
                    : const AssetImage('assets/images/avatar_placeholder.png'),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.edit, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _pickAvatar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Upload Avatar"),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _selectAvatarFromBuiltIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Choose Avatar"),
                ),
              ],
            ),

            const SizedBox(height: 24),

            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Name",
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
            ),

            const SizedBox(height: 24),

            TextField(
              controller: cameraUrlController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Camera Stream URL",
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Save Profile"),
            ),

            const SizedBox(height: 40),

            if (!emailVerified)
              Column(
                children: [
                  Text(
                    "Your email is not verified.",
                    style: TextStyle(color: Colors.red[400]),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _sendVerificationEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Send Verification Email"),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: emailVerified ? _signOut : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: emailVerified ? Colors.redAccent : Colors.grey,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Sign Out"),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

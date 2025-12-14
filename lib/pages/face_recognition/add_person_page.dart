import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../services/face_recognition_api.dart';

class AddPersonPage extends StatefulWidget {
  const AddPersonPage({super.key});

  @override
  State<AddPersonPage> createState() => _AddPersonPageState();
}

class _AddPersonPageState extends State<AddPersonPage> {
  CameraController? controller;
  List<CameraDescription>? cameras;
  final TextEditingController _nameController = TextEditingController();
  bool _isProcessing = false;
  
  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras!.isNotEmpty) {
        CameraDescription? frontCamera;
        for (var camera in cameras!) {
          if (camera.lensDirection == CameraLensDirection.front) {
            frontCamera = camera;
            break;
          }
        }
        
        final selectedCamera = frontCamera ?? cameras![0];
        controller = CameraController(selectedCamera, ResolutionPreset.high);
        await controller!.initialize();
        
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _captureAndUpload() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a name"), backgroundColor: Colors.red),
      );
      return;
    }

    if (controller == null || !controller!.value.isInitialized) return;

    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Capture Single Image
      final XFile photo = await controller!.takePicture();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Uploading to Raspberry Pi..."), backgroundColor: Colors.blue),
      );

      // 2. Upload "center" image
      // We send just one image with key 'center'
      Map<String, String> imagePaths = {
        'center': photo.path
      };
      
      final uploaded = await FaceRecognitionAPI.uploadPerson(name, imagePaths);
      
      if (mounted) {
        if (uploaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("✓ $name uploaded!"), backgroundColor: Colors.green),
          );
          _nameController.clear();
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Upload failed. Check server."), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/bghome.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // 2. Dark Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ),
          
          // 3. Content
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header ---
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        // Back Button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Title
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Add Person",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Register New Face",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // --- Camera Preview ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      height: 400, // Fixed height for camera card
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                        boxShadow: [
                           BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20),
                        ]
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          color: Colors.black,
                          child: Center(
                            child: AspectRatio(
                               aspectRatio: 1 / controller!.value.aspectRatio,
                               child: CameraPreview(controller!),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- Input and Controls ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        // Name Field
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: TextField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Enter person's name",
                              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                              prefixIcon: Icon(Icons.person, color: Colors.white.withValues(alpha: 0.7)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Capture Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isProcessing ? null : _captureAndUpload,
                            style: ElevatedButton.styleFrom(
                               backgroundColor: const Color(0xFFFF9800), // Orange
                               foregroundColor: Colors.white,
                               elevation: 8,
                               shadowColor: Colors.orange.withValues(alpha: 0.5),
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isProcessing 
                              ? const SizedBox(
                                  width: 24, height: 24, 
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.camera_alt_rounded),
                                    SizedBox(width: 10),
                                    Text("Capture & Save", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Text(
                          "Face the camera clearly and ensure good lighting.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

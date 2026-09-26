import "dart:typed_data";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "package:provider/provider.dart";
import "../../../core/config/app_config.dart";
import "../../../core/components/index.dart";
import "../../../core/theme/design_tokens.dart";
import "../../shared/state/session_store.dart";
import "driver_ride_controller.dart";

class DriverEditProfilePage extends StatefulWidget {
  const DriverEditProfilePage({super.key});

  @override
  State<DriverEditProfilePage> createState() => _DriverEditProfilePageState();
}

class _DriverEditProfilePageState extends State<DriverEditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _tricycleController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _currentProfileImageUrl;

  @override
  void initState() {
    super.initState();
    final ctrl = context.read<DriverRideController>();
    final session = context.read<SessionStore>().session;
    final profile = ctrl.driverProfile ?? {};

    _fullNameController.text =
        _text(profile["full_name"]) ?? session?.fullName ?? "";
    _phoneController.text = _text(profile["phone"]) ?? session?.phone ?? "";
    _emailController.text = _text(profile["email"]) ?? "";
    _tricycleController.text = _text(profile["tricycle_number"]) ?? "";

    final imagePath = _text(profile["profile_image_url"]);
    if (imagePath != null) {
      _currentProfileImageUrl = AppConfig.resolveAssetUrl(imagePath);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _tricycleController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    setState(() {
      _selectedImage = picked;
      _selectedImageBytes = bytes;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final ctrl = context.read<DriverRideController>();
    final success = await ctrl.updateProfile(
      fullName: _fullNameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      tricycleNumber: _tricycleController.text.trim(),
      profileImage: _selectedImage,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated.")),
      );
      Navigator.of(context).pop();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ctrl.error ?? "Failed to update profile.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DriverRideController>();
    ImageProvider<Object>? avatarImage;
    if (_selectedImageBytes != null) {
      avatarImage = MemoryImage(_selectedImageBytes!);
    } else if (_currentProfileImageUrl != null) {
      avatarImage = NetworkImage(_currentProfileImageUrl!);
    }

    return Scaffold(
      appBar: const AppAppBar(title: "Edit Profile"),
      body: Container(
        color: DesignTokens.bg,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DesignTokens.spacing16),
          child: AppCard(
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.spacing16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: DesignTokens.driverAccent,
                            backgroundImage: avatarImage,
                            child: avatarImage == null
                                ? const Icon(Icons.person,
                                    color: DesignTokens.bg, size: 42)
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: InkWell(
                              onTap: _pickProfileImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: DesignTokens.driverAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: DesignTokens.bg,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      label: "Full Name",
                      placeholder: "Juan Dela Cruz",
                      controller: _fullNameController,
                      validator: (value) {
                        if (value == null || value.trim().length < 2) {
                          return "Enter a valid full name.";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: "Phone Number",
                      placeholder: "+639123456789",
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        final phone = value?.trim() ?? "";
                        if (phone.isEmpty) return "Phone number is required.";
                        if (!RegExp(r"^[0-9+ -]{7,20}$").hasMatch(phone)) {
                          return "Enter a valid phone number.";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: "Email",
                      placeholder: "name@example.com",
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final email = value?.trim() ?? "";
                        if (email.isEmpty) return null;
                        if (!RegExp(r"^[^@]+@[^@]+\.[^@]+$").hasMatch(email)) {
                          return "Enter a valid email address.";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: "Tricycle Number",
                      placeholder: "e.g. TRK-1234",
                      controller: _tricycleController,
                      validator: (value) {
                        if (value == null || value.trim().length < 2) {
                          return "Enter a valid tricycle number.";
                        }
                        return null;
                      },
                    ),
                    if (ctrl.error != null) ...[
                      const SizedBox(height: DesignTokens.spacing12),
                      Text(
                        ctrl.error!,
                        style: const TextStyle(color: DesignTokens.red),
                      ),
                    ],
                    const SizedBox(height: DesignTokens.spacing18),
                    AppButton(
                      label: "Save Changes",
                      isLoading: ctrl.isSavingProfile,
                      onPressed: ctrl.isSavingProfile ? null : _save,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String? _text(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

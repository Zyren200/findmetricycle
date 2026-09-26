import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../../core/components/index.dart";
import "../../../../core/theme/design_tokens.dart";
import "../passenger_profile_controller.dart";

/// Full-screen replacement for what used to be a plain AlertDialog with
/// unstyled TextFields (rendered with the default light Material theme,
/// clashing badly with the rest of the app's dark design system).
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;

  @override
  void initState() {
    super.initState();
    final profile = context.read<PassengerProfileController>().userProfile ?? {};
    _nameCtrl = TextEditingController(text: profile["full_name"]?.toString() ?? "");
    _emailCtrl = TextEditingController(text: profile["email"]?.toString() ?? "");
    _phoneCtrl = TextEditingController(text: profile["phone"]?.toString() ?? "");
    _addressCtrl = TextEditingController(text: profile["address"]?.toString() ?? "");
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final ctrl = context.read<PassengerProfileController>();
    final ok = await ctrl.updateProfile(
      fullName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? "Profile updated." : (ctrl.profileError ?? "Failed to update profile.")),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PassengerProfileController>();

    return Scaffold(
      backgroundColor: DesignTokens.bg,
      appBar: const AppAppBar(title: "Edit Profile"),
      body: SafeArea(
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
                    AppTextField(
                      label: "Full Name",
                      placeholder: "Juan Dela Cruz",
                      controller: _nameCtrl,
                      validator: (value) {
                        if (value == null || value.trim().length < 2) {
                          return "Enter a valid full name.";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: DesignTokens.spacing12),
                    AppTextField(
                      label: "Email",
                      placeholder: "name@example.com",
                      controller: _emailCtrl,
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
                    const SizedBox(height: DesignTokens.spacing12),
                    AppTextField(
                      label: "Mobile Number",
                      placeholder: "+639123456789",
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Mobile number is required.";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: DesignTokens.spacing12),
                    AppTextField(
                      label: "Address",
                      placeholder: "House/Unit No., Street, Barangay",
                      controller: _addressCtrl,
                      maxLines: 2,
                    ),
                    if (ctrl.profileError != null) ...[
                      const SizedBox(height: DesignTokens.spacing12),
                      Text(
                        ctrl.profileError!,
                        style: const TextStyle(color: DesignTokens.red),
                      ),
                    ],
                    const SizedBox(height: DesignTokens.spacing20),
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

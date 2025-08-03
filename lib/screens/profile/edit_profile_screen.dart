import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_profile.dart';
import '../../widgets/user_avatar.dart';
import '../../core/errors/app_error.dart';
import '../../core/utils/validators.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isNewProfile = false;
  
  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    final userProvider = context.read<UserProvider>();
    final profile = userProvider.currentUserProfile;
    
    if (profile != null) {
      _nameController.text = profile.name;
      _bioController.text = profile.bio ?? '';
      _phoneController.text = profile.phoneNumber ?? '';
    } else {
      _isNewProfile = true;
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user != null) {
        _nameController.text = authProvider.user!.displayName ?? '';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(AppError error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_getErrorMessage(error)),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _getErrorMessage(AppError error) {
    switch (error.type) {
      case ErrorType.network:
        return 'Network error: ${error.message}';
      case ErrorType.validation:
        return error.message;
      default:
        return 'Error: ${error.message}';
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 80,
                );
                if (image != null) {
                  await _uploadImage(image);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 80,
                );
                if (image != null) {
                  await _uploadImage(image);
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await _removeImage();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadImage(XFile image) async {
    final userProvider = context.read<UserProvider>();
    final authProvider = context.read<AuthProvider>();
    
    if (authProvider.user != null) {
      await userProvider.uploadProfileImage(authProvider.user!.uid, await image.readAsBytes());
    }
  }

  Future<void> _removeImage() async {
    final userProvider = context.read<UserProvider>();
    final authProvider = context.read<AuthProvider>();
    
    if (authProvider.user != null) {
      await userProvider.deleteProfileImage(authProvider.user!.uid);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final userProvider = context.read<UserProvider>();
    final authProvider = context.read<AuthProvider>();
    
    if (authProvider.user == null) {
      _showErrorSnackBar(AppError.auth('User not authenticated', 'no-user'));
      return;
    }

    final now = DateTime.now();
    final currentProfile = userProvider.currentUserProfile;
    
    final profile = UserProfile(
      id: authProvider.user!.uid,
      name: _nameController.text.trim(),
      email: authProvider.user!.email ?? '',
      profileImageUrl: currentProfile?.profileImageUrl,
      bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
      phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      averageRating: currentProfile?.averageRating ?? 0.0,
      totalRides: currentProfile?.totalRides ?? 0,
      isVerified: currentProfile?.isVerified ?? false,
      createdAt: currentProfile?.createdAt ?? now,
      updatedAt: now,
    );

    if (_isNewProfile) {
      await userProvider.createProfile(profile);
    } else {
      await userProvider.updateProfile(profile);
    }

    if (userProvider.error == null && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isNewProfile ? 'Profile created successfully!' : 'Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNewProfile ? 'Create Profile' : 'Edit Profile'),
        actions: [
          Consumer<UserProvider>(
            builder: (context, userProvider, child) {
              return TextButton(
                onPressed: userProvider.isLoading || userProvider.isUpdating
                    ? null
                    : _saveProfile,
                child: userProvider.isLoading || userProvider.isUpdating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              );
            },
          ),
        ],
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          if (userProvider.error != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showErrorSnackBar(userProvider.error!);
              userProvider.clearError();
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildProfileImageSection(userProvider),
                  const SizedBox(height: 32),
                  _buildFormFields(),
                  const SizedBox(height: 32),
                  _buildSaveButton(userProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileImageSection(UserProvider userProvider) {
    final profile = userProvider.currentUserProfile;
    
    return Column(
      children: [
        Stack(
          children: [
            UserAvatar(
              imageUrl: profile?.profileImageUrl,
              name: _nameController.text.isNotEmpty ? _nameController.text : 'User',
              radius: 60,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  onPressed: userProvider.isUploadingImage ? null : _pickImage,
                ),
              ),
            ),
            if (userProvider.isUploadingImage)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Tap to change profile photo',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Full Name *',
            hintText: 'Enter your full name',
            prefixIcon: Icon(Icons.person),
          ),
          validator: Validators.validateName,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _bioController,
          decoration: const InputDecoration(
            labelText: 'Bio',
            hintText: 'Tell others about yourself',
            prefixIcon: Icon(Icons.info),
          ),
          maxLines: 3,
          maxLength: 500,
          validator: Validators.validateBio,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            hintText: 'Enter your phone number',
            prefixIcon: Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
          validator: Validators.validatePhoneNumber,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.blue[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Complete your profile to build trust with other riders. A complete profile increases your chances of getting ride requests.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(UserProvider userProvider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: userProvider.isLoading || userProvider.isUpdating
            ? null
            : _saveProfile,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: userProvider.isLoading || userProvider.isUpdating
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Saving...'),
                ],
              )
            : Text(_isNewProfile ? 'Create Profile' : 'Save Changes'),
      ),
    );
  }
}
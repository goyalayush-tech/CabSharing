import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double radius;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.radius = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: radius,
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        child: imageUrl == null
            ? Text(
                _getInitials(name),
                style: TextStyle(
                  fontSize: radius * 0.6,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              )
            : null,
      ),
    );
  }

  String _getInitials(String name) {
    final words = name.trim().split(' ');
    if (words.isEmpty) return '';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}

// Legacy alias for backward compatibility
class UserAvatarWidget extends UserAvatar {
  const UserAvatarWidget({
    super.key,
    super.imageUrl,
    required super.name,
    super.radius = 20,
    super.onTap,
  });
}
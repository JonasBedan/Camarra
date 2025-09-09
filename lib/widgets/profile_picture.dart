import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../utils/premium_service.dart';

class ProfilePicture extends StatelessWidget {
  final UserModel? user;
  final double size;
  final VoidCallback? onTap;
  final bool showBorder;
  final Color? backgroundColor;
  final Color? textColor;
  final bool showMoodOverlay;
  final bool showPremiumBadge;

  const ProfilePicture({
    super.key,
    required this.user,
    this.size = 40,
    this.onTap,
    this.showBorder = false,
    this.backgroundColor,
    this.textColor,
    this.showMoodOverlay = true,
    this.showPremiumBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        // WRAPPED IN STACK FOR OVERLAY
        children: [
          Container(
            width: size,
            height: size,
            decoration: showBorder
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.primaryColor, width: 2),
                  )
                : null,
            child: ClipOval(child: _buildProfileContent(theme)),
          ),
          // Mood emoji overlay
          if (showMoodOverlay && user?.mood != null) ...[
            Positioned(
              bottom: 0, // Adjusted position
              right: 0, // Adjusted position
              child: Container(
                // Added container for sizing and alignment
                width: size * 0.4,
                height: size * 0.4,
                alignment: Alignment.center,
                child: Text(
                  _getMoodEmoji(user!.mood!),
                  style: TextStyle(fontSize: size * 0.25), // Adjusted font size
                ),
              ),
            ),
          ],
          // Premium badge overlay
          if (showPremiumBadge && user != null) ...[
            FutureBuilder<bool>(
              future: PremiumService().hasPremiumAccess(user!.uid),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!) {
                  return Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: Icon(
                        Icons.star,
                        color: Colors.white,
                        size: size * 0.2,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ],
      ),
    );
  }

  String _getMoodEmoji(String mood) {
    switch (mood.toLowerCase()) {
      case 'terrible':
      case 'very bad':
        return '😢';
      case 'bad':
      case 'poor':
        return '😕';
      case 'neutral':
        return '😐';
      case 'okay':
        return '🙂';
      case 'good':
        return '😊';
      case 'great':
        return '😄';
      case 'excellent':
        return '😃';
      case 'amazing':
        return '😁';
      default:
        return '😊';
    }
  }

  Widget _buildProfileContent(ThemeData theme) {
    // If user has a profile picture URL, show the image
    if (user?.profilePictureUrl != null &&
        user!.profilePictureUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: user!.profilePictureUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildInitialFallback(theme),
        errorWidget: (context, url, error) => _buildInitialFallback(theme),
      );
    }

    // Otherwise, show the username initial
    return _buildInitialFallback(theme);
  }

  Widget _buildInitialFallback(ThemeData theme) {
    final initial = user?.username.isNotEmpty == true
        ? user!.username.substring(0, 1).toUpperCase()
        : 'U';

    return Container(
      color: backgroundColor ?? theme.primaryColor,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: textColor ?? Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

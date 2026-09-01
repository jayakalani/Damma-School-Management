import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/services/auth_service.dart';
import '../../app/widgets/glass_ui.dart';
import 'manage_profile_dialog.dart';

enum _ProfileMenuAction { editProfile, logout }

/// Glass-styled profile badge with Edit Profile and Logout quick links.
class UserProfileMenu extends StatefulWidget {
  const UserProfileMenu({
    super.key,
    required this.session,
    required this.auth,
    required this.database,
    required this.roleLabel,
    required this.onLogout,
    this.onProfileUpdated,
  });

  final AuthSession session;
  final AuthService auth;
  final Database database;
  final String roleLabel;
  final VoidCallback onLogout;
  final VoidCallback? onProfileUpdated;

  @override
  State<UserProfileMenu> createState() => _UserProfileMenuState();
}

class _UserProfileMenuState extends State<UserProfileMenu> {
  bool _hovered = false;

  Future<void> _openEditProfile() async {
    final message = await ManageProfileDialog.show(
      context: context,
      database: widget.database,
      auth: widget.auth,
    );
    if (!mounted || message == null) return;
    widget.onProfileUpdated?.call();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final session = widget.auth.currentSession ?? widget.session;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: PopupMenuButton<_ProfileMenuAction>(
          tooltip: 'Account menu',
          offset: const Offset(0, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 12,
          shadowColor: colorScheme.primary.withValues(alpha: 0.18),
          onSelected: (action) {
            switch (action) {
              case _ProfileMenuAction.editProfile:
                _openEditProfile();
              case _ProfileMenuAction.logout:
                widget.onLogout();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _ProfileMenuAction.editProfile,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.edit_outlined, color: colorScheme.primary),
                title: const Text('Edit Profile'),
                subtitle: Text(
                  'Update name or password',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: _ProfileMenuAction.logout,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout, color: colorScheme.error),
                title: Text('Logout', style: TextStyle(color: colorScheme.error)),
              ),
            ),
          ],
          child: GlassSurface(
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            opacity: _hovered ? 0.84 : 0.74,
            borderOpacity: _hovered ? 0.78 : 0.58,
            blur: 14,
            elevated: _hovered,
            tint: _hovered
                ? Color.alphaBlend(colorScheme.primary.withValues(alpha: 0.06), Colors.white)
                : Colors.white,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        Color.alphaBlend(colorScheme.primary.withValues(alpha: 0.7), Colors.white),
                      ],
                    ),
                    boxShadow: floatingShadow(color: colorScheme.primary, blur: 12, y: 4, opacity: 0.18),
                  ),
                  child: Text(
                    session.fullName[0].toUpperCase(),
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.fullName,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        widget.roleLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

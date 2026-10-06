import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/password_model.dart';
import '../utils/app_theme.dart';
import '../utils/url_helper.dart';
import 'totp_card_widget.dart';
import 'vault_logo_avatar.dart';

/// A card widget to display each saved password item.
///
/// Features:
/// - Favorite star button
/// - Category icon or custom website logo
/// - Website URL with 1-click open link and copy buttons
/// - Service title & username
/// - Password with eye icon to hide/show
/// - Live 2FA / TOTP code generator with countdown timer
/// - Custom key-value fields viewer
/// - Expiration alert banner
/// - Edit and delete actions
/// - Supports both Light and Dark themes
class PasswordCard extends StatefulWidget {
  final PasswordItemModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onToggleFavorite;
  final String? vaultName;

  const PasswordCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    this.onToggleFavorite,
    this.vaultName,
  });

  @override
  State<PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends State<PasswordCard> {
  bool _isPasswordVisible = false;
  final Map<int, bool> _secretFieldVisibility = {};

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('$label copied to clipboard!'),
          ],
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catColor = AppTheme.getCategoryColor(widget.item.category);
    final catIcon = AppTheme.getCategoryIcon(widget.item.category);
    final hasTotp = widget.item.totpSecret != null && widget.item.totpSecret!.trim().isNotEmpty;
    final customFields = widget.item.customFields;
    final isExpired = widget.item.isExpired;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.item.isFavorite
              ? Colors.amber.withValues(alpha: isDark ? 0.5 : 0.8)
              : (isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder),
          width: widget.item.isFavorite ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.item.isFavorite
                ? Colors.amber.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Category icon or Custom Logo, Service title, Favorite & Actions
            Row(
              children: [
                // Category Icon, Website Favicon, or Custom Logo
                VaultLogoAvatar(
                  customLogo: widget.item.customLogo,
                  websiteUrl: widget.item.websiteUrl,
                  fallbackIcon: catIcon,
                  fallbackColor: catColor,
                  size: 44,
                  borderRadius: 12,
                ),
                const SizedBox(width: 12),

                // Title and Category / Vault Label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.item.title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.item.isFavorite) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.item.category,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: catColor,
                              ),
                            ),
                          ),
                          if (widget.vaultName != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.vaultName!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Favorite Star Button
                if (widget.onToggleFavorite != null)
                  IconButton(
                    icon: Icon(
                      widget.item.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 22,
                      color: widget.item.isFavorite
                          ? Colors.amber
                          : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                    ),
                    tooltip: widget.item.isFavorite ? 'Unstar' : 'Star',
                    onPressed: widget.onToggleFavorite,
                  ),

                // Edit Button
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                  tooltip: 'Edit',
                  onPressed: widget.onEdit,
                ),

                // Delete Button
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.error),
                  tooltip: 'Delete',
                  onPressed: widget.onDelete,
                ),
              ],
            ),

            // Expiry Alert Banner
            if (isExpired) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.error),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Password rotation reminder expired. Consider updating.',
                        style: TextStyle(fontSize: 11, color: AppTheme.error, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(
                height: 1,
                color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
              ),
            ),

            // Optional Website URL with open & copy buttons
            if (widget.item.websiteUrl != null && widget.item.websiteUrl!.trim().isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.language_outlined,
                    size: 18,
                    color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => openUrlInBrowser(widget.item.websiteUrl!),
                      borderRadius: BorderRadius.circular(4),
                      child: Text(
                        widget.item.websiteUrl!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryLight,
                          decoration: TextDecoration.underline,
                          decorationColor: AppTheme.primaryLight.withValues(alpha: 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Open in browser button
                  InkWell(
                    onTap: () => openUrlInBrowser(widget.item.websiteUrl!),
                    borderRadius: BorderRadius.circular(6),
                    child: const Tooltip(
                      message: 'Open in new tab',
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.open_in_new, size: 16, color: AppTheme.primaryLight),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Copy URL button
                  InkWell(
                    onTap: () => _copyToClipboard(context, widget.item.websiteUrl!, 'Website URL'),
                    borderRadius: BorderRadius.circular(6),
                    child: const Tooltip(
                      message: 'Copy URL',
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.copy_rounded, size: 16, color: AppTheme.primaryLight),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Username / Email field with copy button
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 18,
                  color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.item.usernameOrEmail,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _copyToClipboard(context, widget.item.usernameOrEmail, 'Username'),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.copy_rounded, size: 16, color: AppTheme.primaryLight),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Password field with Reveal/Hide & Copy
            Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isPasswordVisible ? widget.item.password : '••••••••••••',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: _isPasswordVisible ? 0.5 : 2.0,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                ),
                // Toggle Show / Hide Password
                InkWell(
                  onTap: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Copy Password
                InkWell(
                  onTap: () => _copyToClipboard(context, widget.item.password, 'Password'),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.copy_rounded, size: 16, color: AppTheme.primaryLight),
                  ),
                ),
              ],
            ),

            // Live 2FA / TOTP Authenticator code if enabled
            if (hasTotp) ...[
              const SizedBox(height: 12),
              TotpLiveCard(
                secret: widget.item.totpSecret!,
                compact: true,
              ),
            ],

            // Custom fields viewer
            if (customFields.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...customFields.asMap().entries.map((entry) {
                final idx = entry.key;
                final field = entry.value;
                final isFieldVisible = _secretFieldVisibility[idx] ?? !field.isSecret;

                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        field.isSecret ? Icons.vpn_key_outlined : Icons.label_outline,
                        size: 16,
                        color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${field.label}: ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          isFieldVisible ? field.value : '••••••••',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (field.isSecret)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _secretFieldVisibility[idx] = !isFieldVisible;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              isFieldVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 16,
                              color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                            ),
                          ),
                        ),
                      InkWell(
                        onTap: () => _copyToClipboard(context, field.value, field.label),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.copy_rounded, size: 14, color: AppTheme.primaryLight),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            // Optional Notes display
            if (widget.item.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkBackground : AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.item.notes,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

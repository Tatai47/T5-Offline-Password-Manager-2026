import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/vault_model.dart';
import '../utils/app_theme.dart';
import 'create_vault_dialog.dart';

class VaultSelectorSheet extends StatefulWidget {
  final int userId;
  final VaultModel? currentVault; // null means 'All Vaults'
  final Function(VaultModel? selectedVault) onVaultSelected;

  const VaultSelectorSheet({
    super.key,
    required this.userId,
    required this.currentVault,
    required this.onVaultSelected,
  });

  @override
  State<VaultSelectorSheet> createState() => _VaultSelectorSheetState();
}

class _VaultSelectorSheetState extends State<VaultSelectorSheet> {
  List<VaultModel> _vaults = [];
  bool _isLoading = true;
  int _totalPasswordCount = 0;

  @override
  void initState() {
    super.initState();
    _loadVaults();
  }

  Future<void> _loadVaults() async {
    setState(() => _isLoading = true);
    // Ensure at least a default vault exists
    await DatabaseHelper.instance.getOrCreateDefaultVault(widget.userId);
    final vaults = await DatabaseHelper.instance.getVaultsForUser(widget.userId);
    final totalCount = await DatabaseHelper.instance.getPasswordCount(widget.userId);

    if (mounted) {
      setState(() {
        _vaults = vaults;
        _totalPasswordCount = totalCount;
        _isLoading = false;
      });
    }
  }

  void _openCreateEditDialog({VaultModel? vaultToEdit}) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => CreateVaultDialog(
        userId: widget.userId,
        vaultToEdit: vaultToEdit,
        onVaultSaved: _loadVaults,
      ),
    ).then((saved) {
      if (saved == true) {
        _loadVaults();
      }
    });
  }

  Future<void> _handleVaultTap(VaultModel? vault) async {
    if (vault != null && vault.isPinProtected) {
      // Prompt for PIN
      final pinEntered = await _showPinPrompt(vault);
      if (pinEntered != vault.pin) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect vault PIN'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
    }

    if (mounted) {
      Navigator.pop(context);
      widget.onVaultSelected(vault);
    }
  }

  Future<String?> _showPinPrompt(VaultModel vault) async {
    final pinController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: vault.color),
            const SizedBox(width: 8),
            Text('Unlock ${vault.name}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This vault is protected. Enter its 4-digit PIN to open:'),
            const SizedBox(height: 14),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '••••',
                counterText: '',
                prefixIcon: Icon(Icons.pin),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: vault.color),
            onPressed: () => Navigator.pop(ctx, pinController.text.trim()),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteVault(VaultModel vault) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete "${vault.name}"?'),
        content: Text(
          'Are you sure you want to delete this vault? '
          'Stored passwords (${vault.itemCount}) will not be deleted; they will simply move to unassigned / All Vaults.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await DatabaseHelper.instance.deleteVault(vault.id!, widget.userId);
              _loadVaults();
              if (widget.currentVault?.id == vault.id) {
                widget.onVaultSelected(null);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Select Vault',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Vault', style: TextStyle(fontSize: 13)),
                    onPressed: () => _openCreateEditDialog(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),

            // Vaults List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      children: [
                        // "All Vaults" Entry
                        _buildVaultTile(
                          vault: null,
                          title: 'All Vaults',
                          subtitle: 'View passwords across all vaults',
                          icon: Icons.dashboard_outlined,
                          color: AppTheme.primary,
                          count: _totalPasswordCount,
                          isSelected: widget.currentVault == null,
                          isPin: false,
                        ),

                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Text(
                            'MY VAULTS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                            ),
                          ),
                        ),

                        ..._vaults.map((vault) {
                          final isSelected = widget.currentVault?.id == vault.id;
                          return _buildVaultTile(
                            vault: vault,
                            title: vault.name,
                            subtitle: vault.description.isNotEmpty
                                ? vault.description
                                : '${vault.itemCount} items',
                            icon: vault.iconData,
                            color: vault.color,
                            count: vault.itemCount,
                            isSelected: isSelected,
                            isPin: vault.isPinProtected,
                          );
                        }),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVaultTile({
    required VaultModel? vault,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required int count,
    required bool isSelected,
    required bool isPin,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: isSelected
            ? color.withValues(alpha: isDark ? 0.2 : 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleVaultTap(vault),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Icon Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),

                // Name & description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isPin) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.lock_rounded, size: 14, color: isDark ? Colors.amber : Colors.amber.shade700),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCardBorder : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                ),

                // Context options if specific vault
                if (vault != null) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) {
                      if (val == 'edit') {
                        _openCreateEditDialog(vaultToEdit: vault);
                      } else if (val == 'delete') {
                        _confirmDeleteVault(vault);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Edit Vault'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                            SizedBox(width: 10),
                            Text('Delete Vault', style: TextStyle(color: AppTheme.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else
                  const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

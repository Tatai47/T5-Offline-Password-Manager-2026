import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/vault_model.dart';
import '../utils/app_theme.dart';

class CreateVaultDialog extends StatefulWidget {
  final int userId;
  final VaultModel? vaultToEdit;
  final VoidCallback? onVaultSaved;

  const CreateVaultDialog({
    super.key,
    required this.userId,
    this.vaultToEdit,
    this.onVaultSaved,
  });

  @override
  State<CreateVaultDialog> createState() => _CreateVaultDialogState();
}

class _CreateVaultDialogState extends State<CreateVaultDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _pinController;

  late String _selectedIcon;
  late String _selectedColor;
  bool _enablePinLock = false;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _iconOptions = [
    {'name': 'shield', 'icon': Icons.shield_outlined, 'label': 'Shield'},
    {'name': 'work', 'icon': Icons.work_outline, 'label': 'Work'},
    {'name': 'finance', 'icon': Icons.account_balance_outlined, 'label': 'Finance'},
    {'name': 'lock', 'icon': Icons.lock_outline, 'label': 'Secret'},
    {'name': 'key', 'icon': Icons.vpn_key_outlined, 'label': 'Keys'},
    {'name': 'folder', 'icon': Icons.folder_outlined, 'label': 'Folder'},
    {'name': 'shopping', 'icon': Icons.shopping_bag_outlined, 'label': 'Shop'},
    {'name': 'cloud', 'icon': Icons.cloud_outlined, 'label': 'Cloud'},
    {'name': 'code', 'icon': Icons.code_rounded, 'label': 'Developer'},
    {'name': 'star', 'icon': Icons.star_outline, 'label': 'Starred'},
    {'name': 'heart', 'icon': Icons.favorite_outline, 'label': 'Personal'},
    {'name': 'gaming', 'icon': Icons.sports_esports_outlined, 'label': 'Gaming'},
  ];

  final List<String> _colorOptions = [
    '#4F46E5', // Indigo
    '#10B981', // Emerald
    '#06B6D4', // Cyan
    '#8B5CF6', // Purple
    '#EC4899', // Pink
    '#F59E0B', // Amber
    '#E11D48', // Crimson
    '#0D9488', // Teal
    '#EA580C', // Orange
    '#3B82F6', // Blue
  ];

  @override
  void initState() {
    super.initState();
    final v = widget.vaultToEdit;
    _nameController = TextEditingController(text: v?.name ?? '');
    _descriptionController = TextEditingController(text: v?.description ?? '');
    _pinController = TextEditingController(text: v?.pin ?? '');
    _selectedIcon = v?.iconName ?? 'shield';
    _selectedColor = v?.colorHex ?? '#4F46E5';
    _enablePinLock = v?.isPinProtected ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_enablePinLock && _pinController.text.trim().length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vault PIN must be exactly 4 digits'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final desc = _descriptionController.text.trim();
      final pin = _enablePinLock ? _pinController.text.trim() : null;

      if (widget.vaultToEdit == null) {
        // Create new vault
        final newVault = VaultModel(
          userId: widget.userId,
          name: name,
          description: desc,
          iconName: _selectedIcon,
          colorHex: _selectedColor,
          pin: pin,
          createdAt: DateTime.now().toIso8601String(),
        );
        await DatabaseHelper.instance.createVault(newVault);
      } else {
        // Update existing vault
        final updatedVault = widget.vaultToEdit!.copyWith(
          name: name,
          description: desc,
          iconName: _selectedIcon,
          colorHex: _selectedColor,
          pin: pin,
          clearPin: !_enablePinLock,
        );
        await DatabaseHelper.instance.updateVault(updatedVault);
      }

      if (mounted) {
        Navigator.pop(context, true);
        widget.onVaultSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving vault: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.vaultToEdit != null;
    final currentColor = _parseColor(_selectedColor);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Column(
          children: [
            // Header with Preview
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: currentColor.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: currentColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: currentColor.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      VaultModel.getIconForName(_selectedIcon),
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Vault' : 'Create New Vault',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _nameController.text.trim().isEmpty
                              ? 'Enter details below'
                              : _nameController.text.trim(),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Scrollable Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Vault Name
                      Text(
                        'Vault Name',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'e.g. Work, Finance, Crypto, Family',
                          prefixIcon: Icon(Icons.drive_file_rename_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a vault name';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Description
                      Text(
                        'Description (Optional)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          hintText: 'Brief summary of what goes in this vault',
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Choose Icon
                      Text(
                        'Vault Icon',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 68,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _iconOptions.length,
                          itemBuilder: (context, index) {
                            final opt = _iconOptions[index];
                            final isSelected = _selectedIcon == opt['name'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () => setState(() => _selectedIcon = opt['name'] as String),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 58,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? currentColor.withValues(alpha: 0.15)
                                        : (isDark ? AppTheme.darkCardBorder : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? currentColor : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        opt['icon'] as IconData,
                                        color: isSelected ? currentColor : (isDark ? Colors.white70 : Colors.black54),
                                        size: 24,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        opt['label'] as String,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected ? currentColor : (isDark ? Colors.white70 : Colors.black54),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Choose Color Theme
                      Text(
                        'Color Accent',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _colorOptions.map((hex) {
                          final color = _parseColor(hex);
                          final isSelected = _selectedColor == hex;
                          return InkWell(
                            onTap: () => setState(() => _selectedColor = hex),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.6),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 22),

                      // Vault Lock / PIN Security
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCardBorder.withValues(alpha: 0.3) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lock_person_outlined, color: currentColor, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Vault PIN Protection',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Require a 4-digit PIN to open this vault',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _enablePinLock,
                                  activeThumbColor: currentColor,
                                  onChanged: (val) {
                                    setState(() => _enablePinLock = val);
                                  },
                                ),
                              ],
                            ),
                            if (_enablePinLock) ...[
                              const Divider(height: 18),
                              TextFormField(
                                controller: _pinController,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: '4-Digit Vault PIN',
                                  hintText: '••••',
                                  prefixIcon: Icon(Icons.pin),
                                  counterText: '',
                                ),
                                validator: (value) {
                                  if (_enablePinLock) {
                                    if (value == null || value.trim().length != 4) {
                                      return 'Please enter a 4-digit PIN';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(isEdit ? Icons.check : Icons.add),
                    label: Text(isEdit ? 'Save Changes' : 'Create Vault'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

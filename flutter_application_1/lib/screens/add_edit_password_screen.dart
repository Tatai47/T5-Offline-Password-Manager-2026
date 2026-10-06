import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../database/db_helper.dart';
import '../models/password_model.dart';
import '../models/vault_model.dart';
import '../utils/app_theme.dart';
import '../utils/password_strength_helper.dart';
import '../utils/totp_helper.dart';
import '../utils/url_helper.dart';
import '../widgets/create_vault_dialog.dart';
import '../widgets/password_generator_dialog.dart';
import '../widgets/totp_card_widget.dart';
import '../widgets/vault_logo_avatar.dart';

/// Screen used to either Add a new password or Edit an existing one.
///
/// If [itemToEdit] is null -> Mode: ADD
/// If [itemToEdit] is not null -> Mode: EDIT
class AddEditPasswordScreen extends StatefulWidget {
  final int userId;
  final PasswordItemModel? itemToEdit;
  final int? initialVaultId;

  const AddEditPasswordScreen({
    super.key,
    required this.userId,
    this.itemToEdit,
    this.initialVaultId,
  });

  @override
  State<AddEditPasswordScreen> createState() => _AddEditPasswordScreenState();
}

class _AddEditPasswordScreenState extends State<AddEditPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _websiteController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _notesController;
  late TextEditingController _totpSecretController;

  String _selectedCategory = 'Other';
  String? _customLogoBase64;
  bool _isPasswordHidden = true;
  bool _isSaving = false;
  bool _isFavorite = false;

  int? _selectedVaultId;
  List<VaultModel> _userVaults = [];

  List<CustomFieldModel> _customFields = [];
  DateTime? _expiryDate;

  final ImagePicker _picker = ImagePicker();

  final List<String> _categories = [
    'Social',
    'Work',
    'Email',
    'Finance',
    'Entertainment',
    'Other',
  ];

  // Quick suggestions for service names
  final List<String> _commonServices = [
    'Google',
    'GitHub',
    'Netflix',
    'Amazon',
    'Facebook',
    'Instagram',
    'Twitter / X',
    'Apple ID',
  ];

  static const Map<String, String> _serviceUrls = {
    'Google': 'https://accounts.google.com',
    'GitHub': 'https://github.com',
    'Netflix': 'https://netflix.com',
    'Amazon': 'https://amazon.com',
    'Facebook': 'https://facebook.com',
    'Instagram': 'https://instagram.com',
    'Twitter / X': 'https://x.com',
    'Apple ID': 'https://appleid.apple.com',
  };

  @override
  void initState() {
    super.initState();
    final item = widget.itemToEdit;
    _titleController = TextEditingController(text: item?.title ?? '');
    _websiteController = TextEditingController(text: item?.websiteUrl ?? '');
    _usernameController = TextEditingController(text: item?.usernameOrEmail ?? '');
    _passwordController = TextEditingController(text: item?.password ?? '');
    _notesController = TextEditingController(text: item?.notes ?? '');
    _totpSecretController = TextEditingController(text: item?.totpSecret ?? '');
    _selectedCategory = item?.category ?? 'Other';
    _customLogoBase64 = item?.customLogo;
    _isFavorite = item?.isFavorite ?? false;
    _selectedVaultId = item?.vaultId ?? widget.initialVaultId;

    if (item != null) {
      _customFields = List.from(item.customFields);
      if (item.expiresAt != null && item.expiresAt!.isNotEmpty) {
        _expiryDate = DateTime.tryParse(item.expiresAt!);
      }
    }

    _loadVaults();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _websiteController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _notesController.dispose();
    _totpSecretController.dispose();
    super.dispose();
  }

  Future<void> _loadVaults() async {
    await DatabaseHelper.instance.getOrCreateDefaultVault(widget.userId);
    final vaults = await DatabaseHelper.instance.getVaultsForUser(widget.userId);
    if (mounted) {
      setState(() {
        _userVaults = vaults;
        if (_selectedVaultId == null && vaults.isNotEmpty) {
          _selectedVaultId = vaults.first.id;
        }
      });
    }
  }

  /// Image picker for custom website logo
  Future<void> _pickLogo(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 85,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _customLogoBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not pick logo: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  /// Bottom sheet to choose, change, or remove website logo
  void _showLogoOptions() {
    final hasUrl = _websiteController.text.trim().isNotEmpty;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Upload a custom image file from your device'),
                onTap: () {
                  Navigator.pop(context);
                  _pickLogo(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary),
                title: const Text('Take a Photo'),
                subtitle: const Text('Take a picture with your camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickLogo(ImageSource.camera);
                },
              ),
              if (_customLogoBase64 != null && hasUrl)
                ListTile(
                  leading: const Icon(Icons.auto_awesome, color: AppTheme.success),
                  title: const Text('Use Auto-fetched Website Logo'),
                  subtitle: Text('Fetch automatically from ${extractDomain(_websiteController.text) ?? "website"}'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _customLogoBase64 = null;
                    });
                  },
                ),
              if (_customLogoBase64 != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppTheme.error),
                  title: const Text('Remove Custom Logo', style: TextStyle(color: AppTheme.error)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _customLogoBase64 = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens the advanced password generator dialog
  void _openPasswordGenerator() {
    showDialog(
      context: context,
      builder: (ctx) => PasswordGeneratorDialog(
        onPasswordSelected: (pwd) {
          setState(() {
            _passwordController.text = pwd;
            _isPasswordHidden = false;
          });
        },
      ),
    );
  }

  /// Adds a custom key-value field
  void _showAddCustomFieldDialog() {
    final labelCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    bool isSecret = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Custom Field'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Field Name',
                  hintText: 'e.g. PIN, Security Answer, Port, API Key',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valueCtrl,
                obscureText: isSecret,
                decoration: const InputDecoration(
                  labelText: 'Field Value',
                  hintText: 'Value to store',
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mask Value (Secret)'),
                value: isSecret,
                onChanged: (val) => setDlgState(() => isSecret = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final label = labelCtrl.text.trim();
                final val = valueCtrl.text.trim();
                if (label.isNotEmpty && val.isNotEmpty) {
                  setState(() {
                    _customFields.add(CustomFieldModel(
                      label: label,
                      value: val,
                      isSecret: isSecret,
                    ));
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add Field'),
            ),
          ],
        ),
      ),
    );
  }

  /// Date picker for rotation reminder
  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now.add(const Duration(days: 90)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  /// Save or update the password in SQLite
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final nowString = DateTime.now().toIso8601String();
      final webUrl = _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim();
      final totpSec = _totpSecretController.text.trim().isEmpty ? null : _totpSecretController.text.trim();
      final customFieldsJson = _customFields.isEmpty
          ? null
          : jsonEncode(_customFields.map((f) => f.toMap()).toList());
      final expIso = _expiryDate?.toIso8601String();

      if (widget.itemToEdit == null) {
        // Mode: ADD NEW
        final newItem = PasswordItemModel(
          userId: widget.userId,
          vaultId: _selectedVaultId,
          title: _titleController.text.trim(),
          usernameOrEmail: _usernameController.text.trim(),
          password: _passwordController.text,
          category: _selectedCategory,
          notes: _notesController.text.trim(),
          websiteUrl: webUrl,
          customLogo: _customLogoBase64,
          isFavorite: _isFavorite,
          totpSecret: totpSec,
          customFieldsJson: customFieldsJson,
          expiresAt: expIso,
          createdAt: nowString,
        );

        await DatabaseHelper.instance.addPassword(newItem);
      } else {
        // Mode: UPDATE EXISTING
        final updatedItem = widget.itemToEdit!.copyWith(
          vaultId: _selectedVaultId,
          title: _titleController.text.trim(),
          usernameOrEmail: _usernameController.text.trim(),
          password: _passwordController.text,
          category: _selectedCategory,
          notes: _notesController.text.trim(),
          websiteUrl: webUrl,
          customLogo: _customLogoBase64,
          isFavorite: _isFavorite,
          totpSecret: totpSec,
          clearTotp: totpSec == null,
          customFieldsJson: customFieldsJson,
          expiresAt: expIso,
          clearExpiry: expIso == null,
        );

        await DatabaseHelper.instance.updatePassword(updatedItem);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.itemToEdit == null ? 'Password saved successfully!' : 'Password updated!',
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Return 'true' to let previous screen know data changed
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving password: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.itemToEdit != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    final strength = PasswordStrengthHelper.evaluate(_passwordController.text);
    final hasValidTotp = TotpHelper.isValidSecret(_totpSecretController.text);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Password' : 'Add New Password'),
        actions: [
          // Favorite Star toggle
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: _isFavorite ? Colors.amber : (isDark ? Colors.white70 : Colors.black54),
              size: 26,
            ),
            tooltip: _isFavorite ? 'Remove from Favorites' : 'Mark as Favorite',
            onPressed: () {
              setState(() => _isFavorite = !_isFavorite);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vault Selector Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCardBorder.withValues(alpha: 0.3) : Colors.indigo.shade50.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: AppTheme.primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ASSIGN TO VAULT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<int?>(
                                  value: _selectedVaultId,
                                  isDense: true,
                                  icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primary),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                                  ),
                                  items: _userVaults.map((v) {
                                    return DropdownMenuItem<int?>(
                                      value: v.id,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(v.iconData, size: 18, color: v.color),
                                          const SizedBox(width: 8),
                                          Text(v.name),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() => _selectedVaultId = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('New Vault', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            showDialog<bool>(
                              context: context,
                              builder: (ctx) => CreateVaultDialog(
                                userId: widget.userId,
                                onVaultSaved: _loadVaults,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Title / Service
                  Text(
                    'Account / Service Name',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelColor),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Google, GitHub, Netflix, Work Portal',
                      prefixIcon: Icon(Icons.apps_outlined, color: AppTheme.textSecondary),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter service or account name';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 10),

                  // Quick suggestion chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _commonServices.map((service) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(
                              service,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _titleController.text = service;
                                if (_websiteController.text.trim().isEmpty && _serviceUrls.containsKey(service)) {
                                  _websiteController.text = _serviceUrls[service]!;
                                }
                              });
                            },
                            backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
                            side: BorderSide(
                              color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Website URL + Logo Picker
                  Text(
                    'Website / Domain Address (Optional)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelColor),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _websiteController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      hintText: 'e.g. https://github.com',
                      prefixIcon: Icon(Icons.language_outlined, color: AppTheme.textSecondary),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),

                  const SizedBox(height: 8),

                  // Logo Preview Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCardBorder.withValues(alpha: 0.2) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        VaultLogoAvatar(
                          websiteUrl: _websiteController.text.trim(),
                          customLogo: _customLogoBase64,
                          size: 36,
                          fallbackIcon: AppTheme.getCategoryIcon(_selectedCategory),
                          fallbackColor: AppTheme.getCategoryColor(_selectedCategory),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _customLogoBase64 != null
                                    ? 'Custom uploaded logo'
                                    : (_websiteController.text.trim().isNotEmpty
                                        ? 'Auto logo from domain'
                                        : 'Default letter icon'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: labelColor,
                                ),
                              ),
                              Text(
                                _customLogoBase64 != null
                                    ? 'Using image from device'
                                    : 'Tap button to upload custom icon',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: const Size(60, 32),
                          ),
                          icon: const Icon(Icons.image_outlined, size: 16),
                          label: Text(
                            _customLogoBase64 != null ? 'Change' : 'Upload',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: _showLogoOptions,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Username or Email
                  Text(
                    'Username or Email',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelColor),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. user@email.com or @handle',
                      prefixIcon: Icon(Icons.person_outline, color: AppTheme.textSecondary),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter username or email';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  // Password & Generator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Password',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelColor),
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(40, 28),
                            ),
                            icon: const Icon(Icons.tune_rounded, size: 15, color: AppTheme.primary),
                            label: const Text('Generator Options', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: _openPasswordGenerator,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _isPasswordHidden,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Enter password or generate one',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 20),
                            tooltip: 'Quick Generate',
                            onPressed: () {
                              final pwd = PasswordStrengthHelper.generate(length: 16);
                              setState(() {
                                _passwordController.text = pwd;
                                _isPasswordHidden = false;
                              });
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              _isPasswordHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: AppTheme.textSecondary,
                            ),
                            onPressed: () {
                              setState(() => _isPasswordHidden = !_isPasswordHidden);
                            },
                          ),
                        ],
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Please enter a password';
                      }
                      return null;
                    },
                  ),

                  // Password Strength Bar & Checklist
                  if (_passwordController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: strength.score,
                              minHeight: 5,
                              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(strength.color),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          strength.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: strength.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildCritBadge('10+ chars', strength.hasMinLength, isDark),
                        _buildCritBadge('Uppercase', strength.hasUppercase, isDark),
                        _buildCritBadge('Lowercase', strength.hasLowercase, isDark),
                        _buildCritBadge('Numbers', strength.hasNumbers, isDark),
                        _buildCritBadge('Symbols', strength.hasSymbols, isDark),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),

                  // 2FA / TOTP Authenticator Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCardBorder.withValues(alpha: 0.25) : Colors.blue.shade50.withValues(alpha: 0.4),
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
                            const Icon(Icons.security_rounded, color: AppTheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Authenticator 2FA (One-Time Password)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: labelColor,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              style: TextButton.styleFrom(padding: EdgeInsets.zero),
                              onPressed: () {
                                final randomSec = TotpHelper.generateRandomSecret();
                                setState(() => _totpSecretController.text = randomSec);
                              },
                              child: const Text('Generate Key', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _totpSecretController,
                          onChanged: (_) => setState(() {}),
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: 'Enter 2FA secret seed (e.g. JBSWY3DPEHPK3PXP)',
                            prefixIcon: const Icon(Icons.key_outlined, size: 20),
                            suffixIcon: _totpSecretController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _totpSecretController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                        ),
                        if (hasValidTotp) ...[
                          const SizedBox(height: 12),
                          TotpLiveCard(secret: _totpSecretController.text.trim()),
                        ] else if (_totpSecretController.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'Invalid Base32 secret key. Secret should only contain letters A-Z and digits 2-7.',
                            style: TextStyle(fontSize: 11, color: AppTheme.error),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Category Selector Chips
                  Text(
                    'Category',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelColor),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      final catColor = AppTheme.getCategoryColor(cat);
                      return ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: catColor.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: isSelected ? catColor : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected ? catColor : (isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedCategory = cat);
                          }
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Custom Fields Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Custom Fields (${_customFields.length})',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelColor),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add_circle_outline, size: 16),
                        label: const Text('Add Field', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _showAddCustomFieldDialog,
                      ),
                    ],
                  ),
                  if (_customFields.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ..._customFields.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final field = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCardBorder.withValues(alpha: 0.3) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              field.isSecret ? Icons.vpn_key_outlined : Icons.label_outline,
                              size: 18,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    field.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    field.isSecret ? '••••••••' : field.value,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: labelColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                              onPressed: () {
                                setState(() => _customFields.removeAt(idx));
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 20),

                  // Password Expiry / Rotation Reminder
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCardBorder.withValues(alpha: 0.25) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_outlined, color: AppTheme.primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Password Rotation Reminder',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: labelColor,
                                ),
                              ),
                              Text(
                                _expiryDate != null
                                    ? 'Expires on: ${_expiryDate!.year}-${_expiryDate!.month.toString().padLeft(2, '0')}-${_expiryDate!.day.toString().padLeft(2, '0')}'
                                    : 'No expiration reminder set',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _expiryDate != null && DateTime.now().isAfter(_expiryDate!)
                                      ? AppTheme.error
                                      : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_expiryDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _expiryDate = null),
                          ),
                        TextButton(
                          onPressed: _pickExpiryDate,
                          child: Text(_expiryDate != null ? 'Change' : 'Set Date'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Notes field
                  Text(
                    'Notes (Optional)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelColor),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Pin code, recovery email, security questions',
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 40),
                        child: Icon(Icons.notes_outlined, color: AppTheme.textSecondary),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _handleSave,
                      icon: _isSaving
                          ? const SizedBox.shrink()
                          : const Icon(Icons.check, size: 20),
                      label: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(isEditing ? 'Save Changes' : 'Save Password'),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCritBadge(String label, bool passed, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: passed
            ? AppTheme.success.withValues(alpha: 0.15)
            : (isDark ? Colors.white10 : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            passed ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 12,
            color: passed ? AppTheme.success : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: passed ? FontWeight.bold : FontWeight.normal,
              color: passed ? AppTheme.success : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

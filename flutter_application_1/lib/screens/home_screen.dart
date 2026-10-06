import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/user_model.dart';
import '../models/password_model.dart';
import '../models/vault_model.dart';
import '../utils/app_theme.dart';
import '../widgets/user_avatar.dart';
import '../widgets/password_card.dart';
import '../widgets/vault_selector_sheet.dart';
import 'add_edit_password_screen.dart';
import 'admin_panel_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

/// The HomeScreen displays the user's password vault.
///
/// Features:
/// - Multi-Vault Switching & Creation
/// - Real-time Search
/// - Category & Favorites Filtering
/// - Password Strength & 2FA Indicators
/// - Admin & User Settings
class HomeScreen extends StatefulWidget {
  final UserModel currentUser;

  const HomeScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late UserModel _user;
  List<PasswordItemModel> _passwords = [];
  Map<int, VaultModel> _vaultMap = {};
  VaultModel? _currentVault; // null = 'All Vaults'
  bool _isLoading = true;

  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    '★ Starred',
    'Social',
    'Work',
    'Email',
    'Finance',
    'Entertainment',
    'Other',
  ];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _user = widget.currentUser;
    _initVaultsAndLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initVaultsAndLoad() async {
    // Ensure user has at least a default vault
    await DatabaseHelper.instance.getOrCreateDefaultVault(_user.id!);
    await _loadPasswords();
  }

  /// Queries SQLite for this user's passwords and vaults
  Future<void> _loadPasswords() async {
    setState(() => _isLoading = true);

    final vaults = await DatabaseHelper.instance.getVaultsForUser(_user.id!);
    final map = {for (var v in vaults) v.id!: v};

    // If current vault was deleted, fall back to null (All)
    if (_currentVault != null && !map.containsKey(_currentVault!.id)) {
      _currentVault = null;
    }

    final isStarredFilter = _selectedCategory == '★ Starred';
    final categoryFilter = (isStarredFilter || _selectedCategory == 'All')
        ? null
        : _selectedCategory;

    final list = await DatabaseHelper.instance.getPasswordsForUser(
      _user.id!,
      vaultId: _currentVault?.id,
      onlyFavorites: isStarredFilter ? true : null,
      category: categoryFilter,
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
    );

    if (mounted) {
      setState(() {
        _vaultMap = map;
        _passwords = list;
        _isLoading = false;
      });
    }
  }

  /// Opens the Vault Switcher Bottom Sheet
  void _openVaultSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VaultSelectorSheet(
        userId: _user.id!,
        currentVault: _currentVault,
        onVaultSelected: (selected) {
          setState(() => _currentVault = selected);
          _loadPasswords();
        },
      ),
    );
  }

  /// Opens the Add/Edit password screen
  Future<void> _openAddEditScreen({PasswordItemModel? itemToEdit}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditPasswordScreen(
          userId: _user.id!,
          itemToEdit: itemToEdit,
          initialVaultId: _currentVault?.id,
        ),
      ),
    );

    // If a password was added or updated, reload our list
    if (result == true) {
      _loadPasswords();
    }
  }

  /// Toggles favorite status on a password card
  Future<void> _toggleFavorite(PasswordItemModel item) async {
    final newStatus = !item.isFavorite;
    await DatabaseHelper.instance.togglePasswordFavorite(item.id!, _user.id!, newStatus);
    setState(() {
      final index = _passwords.indexWhere((p) => p.id == item.id);
      if (index != -1) {
        _passwords[index] = _passwords[index].copyWith(isFavorite: newStatus);
        // If filtering by Starred and removed, filter out
        if (_selectedCategory == '★ Starred' && !newStatus) {
          _passwords.removeAt(index);
        }
      }
    });
  }

  /// Deletes a password after user confirmation
  void _confirmDelete(PasswordItemModel item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Password'),
        content: Text('Are you sure you want to delete your credentials for "${item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              await DatabaseHelper.instance.deletePassword(item.id!, _user.id!);
              _loadPasswords();
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Deleted "${item.title}"'),
                  backgroundColor: AppTheme.textPrimary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Navigates to the user's profile screen
  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          currentUser: _user,
          onUserUpdated: (updatedUser) {
            setState(() {
              _user = updatedUser;
            });
          },
        ),
      ),
    ).then((_) => _loadPasswords());
  }

  /// Navigates to Settings screen (Export, Import, Backup, Sign Out)
  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          currentUser: _user,
          onUserUpdated: (updatedUser) {
            setState(() {
              _user = updatedUser;
            });
          },
          onDataChanged: () {
            _loadPasswords();
          },
        ),
      ),
    ).then((_) => _loadPasswords());
  }

  /// Dialog to set a 4-digit PIN for quick unlock on software launch
  void _showQuickPinSetupDialog() {
    final pinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isObscured = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.pin_outlined, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick PIN Unlock Setup',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Save credentials to local database',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.shield_outlined, size: 18, color: AppTheme.primary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Save credentials locally in this device\'s SQLite database. Whenever you open the software, simply enter this 4-digit PIN to access your vault instantly.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Create 4-Digit PIN',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: isObscured,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: '••••',
                          counterText: '',
                          suffixIcon: IconButton(
                            icon: Icon(
                              isObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 18,
                            ),
                            onPressed: () => setDialogState(() => isObscured = !isObscured),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.length != 4 || int.tryParse(val) == null) {
                            return 'Please enter exactly 4 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Confirm 4-Digit PIN',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: confirmPinController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: isObscured,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          hintText: '••••',
                          counterText: '',
                        ),
                        validator: (val) {
                          if (val != pinController.text) {
                            return 'PINs do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Save & Enable PIN'),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final newPin = pinController.text.trim();
                    await DatabaseHelper.instance.setUserPin(_user.id!, newPin);
                    await DatabaseHelper.instance.saveUserSession(_user.id!);
                    setState(() {
                      _user = _user.copyWith(pin: newPin);
                    });
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text('4-Digit Quick PIN configured! Unlock with this PIN on software open.'),
                            ),
                          ],
                        ),
                        backgroundColor: AppTheme.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vaultColor = _currentVault != null ? _currentVault!.color : AppTheme.primary;
    final vaultIcon = _currentVault != null ? _currentVault!.iconData : Icons.dashboard_outlined;
    final vaultName = _currentVault != null ? _currentVault!.name : 'All Vaults';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              children: [
                // Top App Bar / User Profile Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      // User Avatar (Clickable to open profile)
                      UserAvatar(
                        base64Image: _user.profileImage,
                        displayName: _user.name,
                        radius: 24,
                        onTap: _openProfile,
                      ),
                      const SizedBox(width: 14),

                      // Greeting & User Name
                      Expanded(
                        child: InkWell(
                          onTap: _openProfile,
                          borderRadius: BorderRadius.circular(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back,',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                _user.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Admin Console Icon (Only visible to Administrators)
                      if (_user.isAdmin)
                        IconButton(
                          icon: const Icon(Icons.admin_panel_settings, color: Colors.amber, size: 26),
                          tooltip: 'Admin Console',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminPanelScreen(currentUser: _user),
                              ),
                            );
                          },
                        ),

                      // Settings Icon (Export, Import, Backup, Profile)
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, color: AppTheme.primary, size: 26),
                        tooltip: 'Settings & Data Backup',
                        onPressed: _openSettings,
                      ),
                    ],
                  ),
                ),

                // Quick PIN Setup Banner (if user hasn't configured a 4-digit PIN)
                if (_user.pin == null || _user.pin!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.pin_outlined, color: AppTheme.primary, size: 16),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Set 4-Digit Quick PIN',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Unlock your vault instantly on software launch',
                                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: _showQuickPinSetupDialog,
                            child: const Text('Set PIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Vault Switcher Banner Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Material(
                    color: vaultColor.withValues(alpha: isDark ? 0.18 : 0.08),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _openVaultSelector,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: vaultColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(vaultIcon, color: vaultColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'ACTIVE VAULT',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.9,
                                          color: vaultColor,
                                        ),
                                      ),
                                      if (_currentVault?.isPinProtected ?? false) ...[
                                        const SizedBox(width: 6),
                                        Icon(Icons.lock_rounded, size: 12, color: vaultColor),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    vaultName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkCardBorder : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_passwords.length} items',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.unfold_more, size: 16, color: vaultColor),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                      _loadPasswords();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search title, username, URL, or notes...',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                                _loadPasswords();
                              },
                            )
                          : null,
                    ),
                  ),
                ),

                // Category & Favorites Filter Chips
                SizedBox(
                  height: 46,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat;
                      Color catColor;
                      if (cat == '★ Starred') {
                        catColor = Colors.amber;
                      } else if (cat == 'All') {
                        catColor = AppTheme.primary;
                      } else {
                        catColor = AppTheme.getCategoryColor(cat);
                      }

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          selectedColor: catColor.withValues(alpha: 0.18),
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
                              _loadPasswords();
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 6),

                // Passwords List Section
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _passwords.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _loadPasswords,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                itemCount: _passwords.length,
                                itemBuilder: (context, index) {
                                  final item = _passwords[index];
                                  final itemVaultName = (_currentVault == null && item.vaultId != null)
                                      ? _vaultMap[item.vaultId]?.name
                                      : null;

                                  return PasswordCard(
                                    item: item,
                                    vaultName: itemVaultName,
                                    onEdit: () => _openAddEditScreen(itemToEdit: item),
                                    onDelete: () => _confirmDelete(item),
                                    onToggleFavorite: () => _toggleFavorite(item),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
      // Floating Action Button to add a new password
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: vaultColor,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add),
        label: Text(_currentVault != null ? 'Add to ${_currentVault!.name}' : 'Add Password'),
        onPressed: () => _openAddEditScreen(),
      ),
    );
  }

  /// Shown when the user doesn't have any passwords yet or search returns no results
  Widget _buildEmptyState() {
    final isSearching = _searchQuery.isNotEmpty || _selectedCategory != 'All';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearching ? Icons.search_off_rounded : Icons.shield_outlined,
                size: 56,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isSearching ? 'No Matching Passwords' : 'No Passwords in this Vault',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Try searching for something else or clear filters.'
                  : 'Start protecting your accounts by adding credentials to this vault.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            if (!isSearching)
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add First Password'),
                onPressed: () => _openAddEditScreen(),
              ),
          ],
        ),
      ),
    );
  }
}

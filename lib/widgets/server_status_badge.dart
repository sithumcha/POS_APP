import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/offline_sync_service.dart';
import '../theme/app_theme.dart';

class ServerStatusBadge extends StatefulWidget {
  final bool compact;

  const ServerStatusBadge({
    super.key,
    this.compact = false,
  });

  @override
  State<ServerStatusBadge> createState() => _ServerStatusBadgeState();
}

class _ServerStatusBadgeState extends State<ServerStatusBadge> {
  final ApiService _apiService = ApiService();
  final OfflineSyncService _offlineSync = OfflineSyncService();
  Timer? _heartbeatTimer;

  bool _isChecking = true;
  bool _isOnline = false;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    // Auto purge any stale rejected unsynced staff records from local storage
    _apiService.purgeUnsyncedStaffMembers().then((_) => _checkHealth());
    // Auto ping health check every 10 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkHealth());
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkHealth() async {
    if (!mounted) return;
    setState(() {
      _isChecking = true;
    });

    final status = await _apiService.checkServerHealth();
    final isOnline = status['isOnline'] as bool? ?? false;
    final pendingCount = await _offlineSync.getTotalPendingCount();

    if (isOnline && pendingCount > 0) {
      // Auto drain pending offline queue
      _offlineSync.syncAllPending();
    }

    if (!mounted) return;
    setState(() {
      _isChecking = false;
      _isOnline = isOnline;
      _pendingCount = pendingCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String label = _isChecking
        ? 'Checking...'
        : (_isOnline
            ? (_pendingCount > 0 ? 'Online (Syncing $_pendingCount)' : 'Server Online')
            : (_pendingCount > 0 ? 'Offline ($_pendingCount pending)' : 'Server Offline'));

    final Color bgColor = _isChecking
        ? const Color(0xFFFEF3C7)
        : (_isOnline ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2));

    final Color borderColor = _isChecking
        ? const Color(0xFFFCD34D)
        : (_isOnline ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA));

    final Color textColor = _isChecking
        ? const Color(0xFF92400E)
        : (_isOnline ? const Color(0xFF065F46) : const Color(0xFF991B1B));

    return GestureDetector(
      onTap: () {
        _checkHealth();
        _showQueueDetailsModal(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 10 : 12,
          vertical: widget.compact ? 6 : 7,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIndicatorDot(),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: widget.compact ? 11 : 12,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQueueDetailsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return FutureBuilder<Map<String, dynamic>>(
              future: _offlineSync.getPendingSummary(),
              builder: (context, snapshot) {
                final summary = snapshot.data ?? {};
                final total = summary['total'] as int? ?? 0;
                final orders = summary['orders'] as List? ?? [];
                final cats = summary['categories'] as List? ?? [];
                final subcats = summary['subcategories'] as List? ?? [];
                final prods = summary['products'] as List? ?? [];
                final staff = summary['staff'] as List? ?? [];

                return Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _isOnline ? AppColors.success : AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Sync Queue & Cloud Status',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Status Summary Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _isOnline ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _isOnline ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isOnline ? 'Cloud Server Connected' : 'Server Disconnected',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: _isOnline ? const Color(0xFF166534) : const Color(0xFF991B1B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  total == 0
                                      ? 'All local data is synced with backend DB.'
                                      : '$total item(s) pending sync to backend DB.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _isOnline ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _isOnline ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                                ),
                              ),
                              child: Text(
                                '$total Pending',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: _isOnline ? const Color(0xFF166534) : const Color(0xFF991B1B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (total == 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.cloud_done_rounded, size: 48, color: AppColors.success),
                                SizedBox(height: 10),
                                Text(
                                  'Database is completely up to date!',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'No pending offline records.',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        const Text(
                          'Pending Items Not Yet in DB:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              // Unsynced Staff
                              for (var s in staff)
                                _buildPendingItemTile(
                                  icon: Icons.badge_outlined,
                                  title: 'Staff: ${s['first_name'] ?? ''} ${s['last_name'] ?? ''}',
                                  subtitle: 'Email: ${s['email'] ?? 'No email'} (Pending cloud add)',
                                  onDismiss: () async {
                                    await _offlineSync.dismissPendingStaff((s['email'] ?? '').toString());
                                    setModalState(() {});
                                    _checkHealth();
                                  },
                                ),

                              // Unsynced Orders
                              for (var o in orders)
                                _buildPendingItemTile(
                                  icon: Icons.receipt_long_outlined,
                                  title: 'Order: ${o['queue_id'] ?? 'Pending Order'}',
                                  subtitle: 'Total: LKR ${o['payload']?['total_amount'] ?? 0}',
                                ),

                              // Unsynced Subcategories
                              for (var sub in subcats)
                                _buildPendingItemTile(
                                  icon: Icons.subdirectory_arrow_right_rounded,
                                  title: 'Subcategory: ${sub['data']?['name'] ?? 'Pending'} (${sub['action']})',
                                  subtitle: 'Slug: /${sub['data']?['slug'] ?? ''}',
                                ),

                              // Unsynced Categories
                              for (var c in cats)
                                _buildPendingItemTile(
                                  icon: Icons.category_outlined,
                                  title: 'Category: ${c['data']?['name'] ?? 'Pending'} (${c['action']})',
                                  subtitle: 'Slug: /${c['data']?['slug'] ?? ''}',
                                ),

                              // Unsynced Products
                              for (var p in prods)
                                _buildPendingItemTile(
                                  icon: Icons.inventory_2_outlined,
                                  title: 'Product: ${p['data']?['name'] ?? 'Pending'} (${p['action']})',
                                  subtitle: 'Price: LKR ${p['data']?['price'] ?? 0}',
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Triggering immediate Cloud Sync...'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  await _offlineSync.syncAllPending();
                                  await _checkHealth();
                                },
                                icon: const Icon(Icons.sync_rounded, size: 18),
                                label: const Text('Force Sync to DB'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(46),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: ctx,
                                  builder: (dCtx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: const Text('Clear Sync Queue?'),
                                    content: const Text('Are you sure you want to dismiss all pending items without syncing? This will remove stuck local test items.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(dCtx, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                                        child: const Text('Clear All'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed == true) {
                                  await _offlineSync.clearAllPending();
                                  Navigator.pop(ctx);
                                  await _checkHealth();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Offline queue cleared.'),
                                        backgroundColor: const Color(0xFFD97706),
                                      ),
                                    );
                                  }
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: Color(0xFFFECACA)),
                                minimumSize: const Size(100, 46),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Clear Queue'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPendingItemTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onDismiss,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black87),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
              tooltip: 'Dismiss item',
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }

  Widget _buildIndicatorDot() {
    if (_isChecking) {
      return const SizedBox(
        width: 8,
        height: 8,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: Color(0xFFD97706),
        ),
      );
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _isOnline ? AppColors.success : AppColors.error,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (_isOnline ? AppColors.success : AppColors.error).withOpacity(0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

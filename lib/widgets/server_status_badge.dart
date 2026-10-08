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
    _checkHealth();
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
      onTap: _checkHealth,
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

import 'package:flutter/material.dart';
import 'package:wappa_app/core/sync/sync_manager.dart';

/// Banner que se muestra en la parte superior cuando no hay conexión
class OfflineBanner extends StatefulWidget {
  final Widget child;

  const OfflineBanner({
    super.key,
    required this.child,
  });

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _isOnline = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _isOnline = SyncManager.instance.isOnline;
    
    // Escuchar cambios de conectividad
    SyncManager.instance.statusStream.listen((status) {
      if (!mounted) return;
      
      setState(() {
        _isOnline = SyncManager.instance.isOnline;
        _isSyncing = status == SyncStatus.syncing;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Banner de offline
        if (!_isOnline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.orange.shade700,
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_off,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Sin conexión - Los cambios se sincronizarán automáticamente',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // Indicador de sincronización
        if (_isSyncing && _isOnline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            color: Colors.blue.shade700,
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Sincronizando cambios...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        
        // Contenido principal
        Expanded(child: widget.child),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/sync/sync_manager.dart';

/// Widget que muestra el estado de conectividad y sincronización
/// Se puede colocar en el Scaffold como snackbar o banner
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: SyncManager.instance.statusStream,
      initialData: SyncStatus.idle,
      builder: (context, snapshot) {
        final status = snapshot.data ?? SyncStatus.idle;
        final isOnline = SyncManager.instance.isOnline;

        // No mostrar nada si está idle y online
        if (status == SyncStatus.idle && isOnline) {
          return const SizedBox.shrink();
        }

        Color backgroundColor;
        IconData icon;
        String message;

        if (!isOnline) {
          backgroundColor = Colors.orange.shade700;
          icon = Icons.wifi_off;
          message = 'Trabajando sin conexión';
        } else if (status == SyncStatus.syncing) {
          backgroundColor = Colors.blue.shade700;
          icon = Icons.sync;
          message = 'Sincronizando cambios...';
        } else if (status == SyncStatus.error) {
          backgroundColor = Colors.red.shade700;
          icon = Icons.error_outline;
          message = 'Error de sincronización';
        } else {
          return const SizedBox.shrink();
        }

        return Material(
          color: backgroundColor,
          elevation: 4,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (status == SyncStatus.syncing) ...[
                    const SizedBox(width: 12),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Banner persistente que se muestra en la parte superior cuando está offline
class OfflineBanner extends StatelessWidget {
  final Widget child;

  const OfflineBanner({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StreamBuilder<SyncStatus>(
          stream: SyncManager.instance.statusStream,
          builder: (context, snapshot) {
            final isOnline = SyncManager.instance.isOnline;

            if (isOnline) {
              return const SizedBox.shrink();
            }

            return Container(
              width: double.infinity,
              color: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'Sin conexión - Los cambios se sincronizarán automáticamente',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Expanded(child: child),
      ],
    );
  }
}

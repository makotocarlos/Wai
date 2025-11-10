import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/offline_database.dart';

enum SyncStatus { idle, syncing, error }

class SyncManager {
  static final SyncManager instance = SyncManager._internal();
  
  SyncManager._internal() {
    _initConnectivityListener();
  }

  final _connectivity = Connectivity();
  final _statusController = StreamController<SyncStatus>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  bool _isOnline = true;
  bool _isSyncing = false;
  Timer? _syncTimer;

  Stream<SyncStatus> get statusStream => _statusController.stream;
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  void _initConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final wasOnline = _isOnline;
        _isOnline = results.any((result) => 
          result != ConnectivityResult.none
        );
        
        if (!wasOnline && _isOnline) {
          // Reconectado, iniciar sincronización
          syncPendingOperations();
        }
      },
    );

    // Verificar estado inicial
    _connectivity.checkConnectivity().then((results) {
      _isOnline = results.any((result) => result != ConnectivityResult.none);
    });

    // Sincronización periódica cada 30 segundos si hay conexión
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isOnline && !_isSyncing) {
        syncPendingOperations();
      }
    });
  }

  Future<void> syncPendingOperations() async {
    if (_isSyncing || !_isOnline) return;

    _isSyncing = true;
    _statusController.add(SyncStatus.syncing);

    try {
      final db = await OfflineDatabase.instance.database;
      final pendingOps = await db.query(
        'sync_queue',
        orderBy: 'created_at ASC',
      );

      for (final op in pendingOps) {
        try {
          await _processSyncOperation(op);
          
          // Eliminar de la cola si fue exitoso
          await db.delete(
            'sync_queue',
            where: 'id = ?',
            whereArgs: [op['id']],
          );
        } catch (e) {
          // Incrementar contador de reintentos
          await db.update(
            'sync_queue',
            {'retry_count': (op['retry_count'] as int) + 1},
            where: 'id = ?',
            whereArgs: [op['id']],
          );
          
          // Si ha fallado más de 5 veces, marcar como error
          if ((op['retry_count'] as int) >= 5) {
            print('Operación fallida después de 5 reintentos: ${op['operation_type']}');
          }
        }
      }

      _statusController.add(SyncStatus.idle);
    } catch (e) {
      _statusController.add(SyncStatus.error);
      print('Error en sincronización: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _processSyncOperation(Map<String, dynamic> op) async {
    final operationType = op['operation_type'] as String;
    final entityType = op['entity_type'] as String;
    final entityId = op['entity_id'] as String;
    // final payload = jsonDecode(op['payload'] as String) as Map<String, dynamic>;

    print('📤 Procesando operación: $operationType para $entityType (ID: $entityId)');
    
    // Por ahora, las operaciones de book/chapter se manejarán en el repositorio
    // Este método está listo para que los repositorios lo usen
    // La sincronización real ocurre cuando watchBooks detecta cambios
    
    // Si es una operación de creación de libro local, se sincronizará
    // automáticamente por el watchBooks stream cuando detecte el ID local_*
  }

  Future<void> addToSyncQueue({
    required String operationType,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    final db = await OfflineDatabase.instance.database;
    await db.insert('sync_queue', {
      'operation_type': operationType,
      'entity_type': entityType,
      'entity_id': entityId,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'retry_count': 0,
    });

    // Intentar sincronizar inmediatamente si hay conexión
    if (_isOnline && !_isSyncing) {
      syncPendingOperations();
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _statusController.close();
  }
}

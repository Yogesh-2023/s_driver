import 'dart:async';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../core/security/secure_session_store.dart';
import '../../data/api/api_constants.dart';
import '../../widgets/custom_snackbar.dart';
import 'socket_events.dart';

enum SocketConnectionStatus { disconnected, connecting, connected, error }

class SocketService extends GetxService {
  IO.Socket? _socket;
  String? _sessionCookie;
  String? _userId;
  String _role = 'driver';
  final Rx<SocketConnectionStatus> connectionStatus =
      SocketConnectionStatus.disconnected.obs;

  bool _isInitializing = false;

  // Store registered listeners to re-attach them if the socket is recreated
  final Map<String, List<Function(dynamic)>> _registeredCallbacks = {};

  static SocketService get to {
    try {
      return Get.find<SocketService>();
    } catch (e) {
      return Get.put(SocketService(), permanent: true);
    }
  }

  // Active status checks
  bool get isConnected =>
      connectionStatus.value == SocketConnectionStatus.connected;
  bool get isConnecting =>
      connectionStatus.value == SocketConnectionStatus.connecting;
  String? get userId => _userId;
  String? get driverId => _userId;

  // Stream for listening to connection status changes
  Stream<SocketConnectionStatus> get statusStream => connectionStatus.stream;

  // Callback to execute when connection is established (for active trip recovery)
  Future<void> Function()? onConnectionEstablished;

  /// Initializes and connects to the socket server
  void initSocket({
    required String sessionCookie,
    String? userId,
    String role = 'driver',
  }) {
    if (sessionCookie.isEmpty) {
      print('--- [SOCKET_IO] Initialization skipped: missing session cookie ---');
      connectionStatus.value = SocketConnectionStatus.disconnected;
      return;
    }

    var socketUrl = ApiConstants.baseUrl.replaceAll('/api', '');

    print('--- [SOCKET_IO] Initializing socket connection for Driver App ---');
    print('--- [SOCKET_IO] Target URL: $socketUrl ---');
    print(
      '--- [SOCKET_IO] Query Params: role=$role, userId=$userId, moduleType=GOODS ---',
    );

    // Close existing socket if any
    closeSocket();

    _sessionCookie = sessionCookie;
    _userId = userId;
    _role = role;
    connectionStatus.value = SocketConnectionStatus.connecting;

    // Extract the actual token from the cookie string if present
    String parsedSessionToken = sessionCookie;
    if (sessionCookie.contains('session=')) {
      final matches = RegExp(r'session=([^;]+)').firstMatch(sessionCookie);
      if (matches != null && matches.groupCount >= 1) {
        parsedSessionToken = matches.group(1) ?? sessionCookie;
      }
    }

    try {
      _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .disableAutoConnect() // Connect manually
            .setPath('/socket.io')
            .setTransports(['websocket']) // Strictly websocket transport
            .enableWithCredentials() // withCredentials: true
            .enableForceNew()
            .enableReconnection()
            .setReconnectionAttempts(20)
            .setReconnectionDelay(1500)
            .setTimeout(20000)
            .setQuery({
              'role': role,
              'userId': userId,
              'sessionToken': parsedSessionToken,
              'moduleType': 'GOODS',
            })
            .setAuth({'token': parsedSessionToken})
            .setExtraHeaders({'Cookie': sessionCookie})
            .build(),
      );

      _setupListeners();
      _socket!.connect();
    } catch (e) {
      connectionStatus.value = SocketConnectionStatus.error;
      print('--- [SOCKET_IO] Initialization Error: $e ---');
    }
  }

  /// Sets up default event listeners
  void _setupListeners() {
    if (_socket == null) return;

    // 1. Connection established
    _socket!.on(SocketEvents.connect, (_) async {
      connectionStatus.value = SocketConnectionStatus.connected;
      print('[YOGESH][SOCKET][DRIVER] Connected! Socket ID: ${_socket!.id}');

      // Request initial state synchronization on connection / reconnection
      emitEvent(SocketEvents.stateSyncRequest, <String, dynamic>{});

      // Trigger active trip recovery callback
      if (onConnectionEstablished != null) {
        print('[YOGESH][SOCKET][DRIVER] Triggering active trip recovery callback');
        await onConnectionEstablished!();
      }
    });

    // 1.1 Server Ready
    _socket!.on(SocketEvents.socketReady, (data) {
      print('[YOGESH][SOCKET][DRIVER] socket:ready received: $data');
    });

    // 1.2 State Sync
    _socket!.on(SocketEvents.stateSync, (data) {
      print('[YOGESH][SOCKET][DRIVER] state:sync received: $data');
    });

    // 1.3 Socket Error
    _socket!.on(SocketEvents.socketError, (errData) {
      print('[YOGESH][SOCKET][DRIVER] socket:error received: $errData');
      final code = errData is Map ? errData['code'] ?? errData['error'] : errData;
      if (code == 'SOCKET_UNAUTHENTICATED') {
        connectionStatus.value = SocketConnectionStatus.error;
      }
    });

    // 2. Disconnected
    _socket!.on(SocketEvents.disconnect, (reason) {
      connectionStatus.value = SocketConnectionStatus.disconnected;
      print('[YOGESH][SOCKET][DRIVER] Disconnected. Reason: $reason');
      if (reason == 'io server disconnect') {
        _socket?.connect();
      }
    });

    // 3. Connection Error
    _socket!.on(SocketEvents.connectError, (err) {
      connectionStatus.value = SocketConnectionStatus.error;
      print('[YOGESH][SOCKET][DRIVER] Connection Error: $err');
    });

    // 4. General Error
    _socket!.on(SocketEvents.error, (err) {
      print('[YOGESH][SOCKET][DRIVER] Socket Error: $err');
    });

    // 4.5. Log ALL incoming events for debugging
    _socket!.onAny((event, data) {
      print('[YOGESH][SOCKET][DRIVER] [ON_ANY] Received Event: "$event"');
      print('[YOGESH][SOCKET][DRIVER] [ON_ANY] Payload: $data');
    });

    // Debug Listeners for all Ride & Goods Flows (Always print in terminal)
    final debugEvents = [
      'dispatch:offer',
      'dispatch_offer',
      'NEW_TRIP_REQUEST',
      'TRIP_ACCEPTED',
      'DRIVER_FOUND',
      'DRIVER_ON_THE_WAY',
      'DRIVER_LOCATION',
      'DRIVER_ARRIVED',
      'TRIP_STARTED',
      'TRIP_COMPLETED',
      'goods.driver.assigned',
      'goods.driver.on_the_way',
      'goods.pickup.otp.sent',
      'goods.pickup.otp.required',
      'goods.booking.created',
      'goods:booking:request',
      SocketEvents.goodsBookingRequestSent,
      SocketEvents.goodsBookingRequestSentAlias,
      SocketEvents.goodsRequestNew,
    ];

    for (var event in debugEvents) {
      _socket!.on(event, (data) {
        print('\n====== 🚀 [DRIVER APP SOCKET DEBUG] $event ======');
        print('Payload: $data');
        print('=================================================\n');
      });
    }

    // Re-attach any previously registered listeners (e.g. after a reconnect/re-init)
    _registeredCallbacks.forEach((event, callbacks) {
      for (var callback in callbacks) {
        _socket!.on(event, (data) {
          print('--- [SOCKET_IO] [RE-EVENT RECEIVED] -> Event: "$event" ---');
          if (_shouldShowEventSnackBar(event) &&
              event != 'DRIVER_LOCATION' &&
              event != 'DRIVER_LOCATION_UPDATE' &&
              event != SocketEvents.driverOnlineSuccess &&
              event != 'goods.location.updated' &&
              event != 'CHAT_HISTORY' &&
              event != 'RECEIVE_MESSAGE') {
            String msg = 'Event: $event';
            if (data is Map && data['message'] != null) {
              msg = data['message'].toString();
            }
            showCustomSnackBar(msg, isError: false);
          }
          callback(data);
        });

        final errorEvent = '$event:error';
        _socket!.on(errorEvent, (errorData) {
          print('--- [SOCKET_IO] [ERROR RECEIVED] -> Event: "$errorEvent" ---');
          showCustomSnackBar(
            errorData is Map
                ? (errorData['message'] ?? 'Action Failed')
                : 'Action Failed: $errorData',
            isError: true,
          );
        });
      }
    });
  }

  bool _shouldShowEventSnackBar(String event) {
    final lower = event.toLowerCase();
    if (lower.startsWith('dispatch') ||
        lower.contains('dispatch_offer') ||
        lower.contains('dispatch:offer') ||
        lower.contains('dispatch') ||
        lower.contains('payment') ||
        lower.contains('payment_confirmed') ||
        lower.contains('payment_completed')) {
      return false;
    }

    // Ride request events have dedicated UI. Showing a generic toast before
    // the screen validates expiresAt makes an expired request look active.
    const eventsWithDedicatedUi = {
      SocketEvents.newTripRequest,
      SocketEvents.tripRequestExpired,
      SocketEvents.tripCancelled,
      SocketEvents.goodsBookingRequestSent,
      SocketEvents.goodsBookingRequestTimeout,
      SocketEvents.goodsBookingRequestExpired,
      SocketEvents.goodsBookingCancelled,
      'TRIP_CANCELLED_BY_USER',
      'cars:booking:cancelled',
      'dispatch:offer',
      'dispatch_offer',
      'dispatch:offer-expired',
      'dispatch:offer_expired',
      'dispatch_offer_expired',
      'dispatch:offer-cancelled',
      'dispatch:offer_cancelled',
      'dispatch_offer_cancelled',
      'dispatch:rejected',
      'dispatch_rejected',
      'dispatch:accept',
      'dispatch_accept',
      'payment:confirmed',
      'payment_confirmed',
      'payment:completed',
      'payment_completed',
      'booking:payment-confirmed',
      'booking:payment_confirmed',
      'booking:payment-completed',
      'booking:payment_completed',
      'payment:captured',
      'payment_captured',
    };
    return !eventsWithDedicatedUi.contains(event);
  }

  /// Registers a listener for a specific socket event
  void listenTo(String event, Function(dynamic data) callback) {
    bool isFirstListener =
        !_registeredCallbacks.containsKey(event) ||
        _registeredCallbacks[event]!.isEmpty;

    _registeredCallbacks.putIfAbsent(event, () => []).add(callback);
    print('[YOGESH][SOCKET][DRIVER] REGISTERING LISTENER -> $event');

    if (_socket == null) {
      print(
        '--- [SOCKET_IO] Warning: Socket not initialized yet. Listener for "$event" saved and will attach on connect. ---',
      );
      return;
    }

    if (isFirstListener) {
      _socket!.on(event, (data) {
        if (event == 'dispatch:offer' ||
            event == 'dispatch_offer' ||
            event == 'NEW_TRIP_REQUEST' ||
            event == 'goods:booking:request' ||
            event == 'goods.booking.request.sent') {
          print('[YOGESH][SOCKET][DRIVER] INCOMING RIDE REQUEST -> $event');
          print('[YOGESH][SOCKET][DRIVER] PAYLOAD -> $data');
        } else {
          print('--- [SOCKET_IO] [EVENT RECEIVED] -> Event: "$event" ---');
          print('--- [SOCKET_IO] [PAYLOAD] -> $data ---');
        }

        if (_shouldShowEventSnackBar(event) &&
            event != 'DRIVER_LOCATION' &&
            event != 'DRIVER_LOCATION_UPDATE' &&
            event != SocketEvents.driverOnlineSuccess &&
            event != 'goods.location.updated' &&
            event != 'CHAT_HISTORY' &&
            event != 'RECEIVE_MESSAGE') {
          String msg = 'Event: $event';
          if (data is Map && data['message'] != null) {
            msg = data['message'].toString();
          }
          showCustomSnackBar(msg, isError: false);
        }

        final callbacks = _registeredCallbacks[event]?.toList() ?? [];
        for (var cb in callbacks) {
          cb(data);
        }
      });

      // Also register error listeners for specific event (e.g. event_name:error)
      final errorEvent = '$event:error';
      _socket!.on(errorEvent, (errorData) {
        print('--- [SOCKET_IO] [ERROR RECEIVED] -> Event: "$errorEvent" ---');
        print('--- [SOCKET_IO] [ERROR DETAILS] -> $errorData ---');
        showCustomSnackBar(
          errorData is Map
              ? (errorData['message'] ?? 'Action Failed')
              : 'Action Failed: $errorData',
          isError: true,
        );
      });
    }
  }

  /// Unregisters a listener for a specific event
  void stopListening(String event, [Function(dynamic data)? callback]) {
    if (callback != null) {
      _registeredCallbacks[event]?.remove(callback);
    } else {
      _registeredCallbacks.remove(event);
    }

    if ((_registeredCallbacks[event]?.isEmpty ?? true) && _socket != null) {
      _registeredCallbacks.remove(event);
      print('--- [SOCKET_IO] Stopped listening to: "$event" ---');
      _socket!.off(event);
      _socket!.off('$event:error');
    }
  }

  /// Emits an event with optional payload
  bool emitEvent(String event, [dynamic data]) {
    if (_socket == null || !isConnected) {
      print(
        '--- [SOCKET_IO] Error: Cannot emit "$event". Socket is not connected. ---',
      );
      return false;
    }

    print('--- [SOCKET_IO] [EMITTING EVENT] -> Event: "$event" ---');
    if (data != null) {
      print('--- [SOCKET_IO] [EMIT PAYLOAD] -> $data ---');
      _socket!.emit(event, data);
    } else {
      _socket!.emit(event);
    }
    return true;
  }

  /// Emits an event with acknowledgement callback (returns Future response)
  Future<dynamic> emitWithAck(
    String event, [
    dynamic data,
    Duration timeout = const Duration(seconds: 10),
  ]) async {
    if (_socket == null || !isConnected) {
      print(
        '--- [SOCKET_IO] Error: Cannot emitWithAck "$event". Socket is not connected. ---',
      );
      return {'success': false, 'error': 'SOCKET_NOT_CONNECTED'};
    }

    print(
      '--- [SOCKET_IO] [EMITTING WITH ACK] -> Event: "$event" Payload: $data ---',
    );
    final completer = Completer<dynamic>();

    try {
      _socket!.emitWithAck(
        event,
        data ?? {},
        ack: (response) {
          if (!completer.isCompleted) {
            print(
              '--- [SOCKET_IO] [ACK RECEIVED] -> Event: "$event" Response: $response ---',
            );
            completer.complete(response);
          }
        },
      );
    } catch (e) {
      print('--- [SOCKET_IO] Exception calling emitWithAck for "$event": $e ---');
      try {
        _socket!.emit(event, [
          data ?? {},
          (response) {
            if (!completer.isCompleted) {
              print(
                '--- [SOCKET_IO] [ACK CALLBACK RECEIVED] -> Event: "$event" Response: $response ---',
              );
              completer.complete(response);
            }
          },
        ]);
      } catch (e2) {
        if (!completer.isCompleted) {
          completer.completeError(e2);
        }
      }
    }

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        print('--- [SOCKET_IO] Timeout waiting for ACK on event: "$event" ---');
        return {'success': false, 'error': 'TIMEOUT'};
      },
    );
  }

  // ==========================================
  // CANONICAL SOCKET API CONVENIENCE METHODS
  // ==========================================

  /// 1. driver:online or driver:go-online
  Future<dynamic> goOnline({
    required double latitude,
    required double longitude,
    double heading = 0,
    double speed = 0,
    double accuracy = 0,
    int sequence = 1,
    String? tripId,
  }) async {
    final payload = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed': speed,
      'accuracy': accuracy,
      'timestamp': DateTime.now().toIso8601String(),
      'sequence': sequence,
      if (tripId != null && tripId.isNotEmpty) 'tripId': tripId,
    };
    emitEvent(SocketEvents.driverOnline, payload);
    return await emitWithAck(SocketEvents.driverGoOnline, payload);
  }

  /// 2. driver:offline or driver:go-offline
  Future<dynamic> goOffline() async {
    emitEvent(SocketEvents.driverOffline, <String, dynamic>{});
    return await emitWithAck(SocketEvents.driverGoOffline, <String, dynamic>{});
  }

  /// 3. driver:location:update
  Future<dynamic> updateLocation({
    required double latitude,
    required double longitude,
    double heading = 0,
    double speed = 0,
    double accuracy = 0,
    required int sequence,
    String? tripId,
  }) async {
    final payload = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed': speed,
      'accuracy': accuracy,
      'timestamp': DateTime.now().toIso8601String(),
      'sequence': sequence,
      if (tripId != null && tripId.isNotEmpty) 'tripId': tripId,
    };
    return await emitWithAck(SocketEvents.driverLocationUpdateCanonical, payload);
  }

  /// 4. dispatch:accept
  Future<dynamic> acceptDispatch({required String offerId}) async {
    final payload = <String, dynamic>{'offerId': offerId};
    return await emitWithAck(SocketEvents.dispatchAccept, payload);
  }

  /// 5. dispatch:reject
  Future<dynamic> rejectDispatch({
    required String offerId,
    String? reason,
  }) async {
    final payload = <String, dynamic>{
      'offerId': offerId,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    };
    print('[YOGESH][SOCKET][DRIVER] [REJECT_EVENT_SENT] dispatch:reject emitted with payload: $payload');
    emitEvent(SocketEvents.dispatchReject, payload);
    return await emitWithAck(SocketEvents.dispatchReject, payload);
  }

  /// 6. driver:heading-to-pickup
  Future<dynamic> headingToPickup({required String tripId}) async {
    final payload = <String, dynamic>{'tripId': tripId};
    return await emitWithAck(SocketEvents.driverHeadingToPickup, payload);
  }

  /// 7. driver:arrived
  Future<dynamic> driverArrived({required String tripId}) async {
    final payload = <String, dynamic>{'tripId': tripId};
    return await emitWithAck(SocketEvents.driverArrivedCanonical, payload);
  }

  /// 8. trip:start
  Future<dynamic> startTrip({
    required String tripId,
    required String otp,
  }) async {
    final payload = <String, dynamic>{'tripId': tripId, 'otp': otp};
    return await emitWithAck(SocketEvents.tripStart, payload);
  }

  /// 9. trip:complete
  Future<dynamic> completeTrip({required String tripId}) async {
    final payload = <String, dynamic>{'tripId': tripId};
    return await emitWithAck(SocketEvents.tripComplete, payload);
  }

  /// 10. driver:heartbeat
  Future<dynamic> sendHeartbeat() async {
    return await emitWithAck(SocketEvents.driverHeartbeat, <String, dynamic>{});
  }

  /// Shared: state:sync:request
  Future<dynamic> requestStateSync() async {
    return await emitWithAck(
      SocketEvents.stateSyncRequest,
      <String, dynamic>{},
    );
  }

  /// Shared: sos:create
  Future<dynamic> createSos({
    required String bookingId,
    required double latitude,
    required double longitude,
    String? message,
  }) async {
    final payload = <String, dynamic>{
      'bookingId': bookingId,
      'latitude': latitude,
      'longitude': longitude,
      if (message != null && message.isNotEmpty) 'message': message,
    };
    return await emitWithAck(SocketEvents.sosCreate, payload);
  }

  /// Shared: chat:join
  Future<dynamic> joinChat({required String bookingId}) async {
    final payload = <String, dynamic>{'bookingId': bookingId};
    return await emitWithAck(SocketEvents.chatJoin, payload);
  }

  /// Shared: chat:send
  Future<dynamic> sendChat({
    required String bookingId,
    required String message,
    String? clientMessageId,
  }) async {
    final payload = <String, dynamic>{
      'bookingId': bookingId,
      'message': message,
      'clientMessageId':
          clientMessageId ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
    };
    return await emitWithAck(SocketEvents.chatSend, payload);
  }

  Future<bool> ensureConnected() async {
    if (isConnected) return true;

    if (_isInitializing) {
      for (var attempt = 0; attempt < 20; attempt++) {
        if (isConnected) return true;
        await Future.delayed(const Duration(milliseconds: 500));
      }
      return isConnected;
    }

    if (_socket == null ||
        connectionStatus.value == SocketConnectionStatus.error) {
      _isInitializing = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        final sessionCookie =
            _sessionCookie ?? await SecureSessionStore.readCookie();
        final userId = _userId ?? prefs.getString('user_id') ?? '';

        if (sessionCookie == null || sessionCookie.isEmpty) {
          print(
            '--- [SOCKET_IO] Reconnect skipped: missing session cookie ---',
          );
          connectionStatus.value = SocketConnectionStatus.disconnected;
          return false;
        }

        // Double check after async gap
        if (_socket == null ||
            connectionStatus.value == SocketConnectionStatus.error) {
          initSocket(sessionCookie: sessionCookie, userId: userId, role: _role);
        }
      } finally {
        _isInitializing = false;
      }
    } else if (!isConnecting) {
      connectionStatus.value = SocketConnectionStatus.connecting;
      _socket?.connect();
    }

    for (var attempt = 0; attempt < 12; attempt++) {
      if (isConnected) return true;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    return isConnected;
  }

  Future<bool> reconnectFromStoredSession({String role = 'driver'}) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionCookie = await SecureSessionStore.readCookie();
    final userId = prefs.getString('user_id') ?? '';

    if (sessionCookie == null || sessionCookie.isEmpty) {
      print('--- [SOCKET_IO] Stored reconnect skipped: missing session cookie ---');
      connectionStatus.value = SocketConnectionStatus.disconnected;
      return false;
    }

    if ((isConnected || isConnecting) &&
        _userId == userId &&
        _sessionCookie == sessionCookie &&
        _role == role) {
      return ensureConnected();
    }

    if (_userId != null && _userId != userId) {
      closeSocket();
    }
    _role = role;
    return ensureConnected();
  }

  /// Closes the socket connection
  void closeSocket() {
    if (_socket != null) {
      print('--- [SOCKET_IO] Closing and destroying socket connection ---');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _sessionCookie = null;
    _userId = null;
    connectionStatus.value = SocketConnectionStatus.disconnected;
  }

  @override
  void onClose() {
    closeSocket();
    super.onClose();
  }
}

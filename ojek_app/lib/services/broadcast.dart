import 'dart:async';
import 'dart:convert';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

/// BroadcastService menyatukan pengelolaan koneksi Pusher (broadcast/socket)
/// agar dipakai konsisten di seluruh halaman.
class BroadcastService {
  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();
  bool _initialized = false;
  String? _token;

  Future<void> init({String? token}) async {
    // Selalu perbarui token meskipun sudah initialized,
    // agar authorizer private channel memakai token terbaru.
    if (token != null) {
      _token = token;
    }
    if (_initialized) return;
    await _pusher.init(
      apiKey: AppConfig.pusherKey,
      cluster: AppConfig.pusherCluster,
      authEndpoint: '${AppConfig.apiBaseUrl.replaceAll('/api', '')}/broadcasting/auth',
      onAuthorizer: (channelName, socketId, options) async {
        try {
          final url = '${AppConfig.apiBaseUrl.replaceAll('/api', '')}/broadcasting/auth';
          final res = await http.post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (_token != null) 'Authorization': 'Bearer ${_token!}',
            },
            body: jsonEncode({
              'socket_id': socketId,
              'channel_name': channelName,
            }),
          );
          final Map<String, dynamic> body = jsonDecode(res.body);
          return body;
        } catch (e) {
          return {};
        }
      },
      onConnectionStateChange: (current, previous) {},
      onError: (message, code, exception) {},
    );
    await _pusher.connect();
    _initialized = true;
  }

  /// Berlangganan channel publik `orders`. Event yang didukung:
  /// - `order.created` (new order)
  /// - `accepted`, `cancelled`, `completed`
  Future<void> subscribeOrders(
    void Function(Map<String, dynamic>) onNewOrder, {
    void Function(Map<String, dynamic>)? onAccepted,
    void Function(Map<String, dynamic>)? onCancelled,
    void Function(Map<String, dynamic>)? onCompleted,
    String? token,
  }) async {
    await init(token: token);
    await _pusher.subscribe(
      channelName: "orders",
      onEvent: (event) {
        try {
          print('[Broadcast orders] event=${event.eventName} data=${event.data}');
        } catch (_) {}
        if (event.eventName == "order.created") {
          onNewOrder({"data": event.data});
        } else if (event.eventName == "accepted") {
          onAccepted?.call({"data": event.data});
        } else if (event.eventName == "cancelled") {
          onCancelled?.call({"data": event.data});
        } else if (event.eventName == "completed") {
          onCompleted?.call({"data": event.data});
        }
      },
    );
  }

  /// Berlangganan detail order: baik channel publik `orders` (difilter
  /// berdasarkan `id`) maupun channel privat `private-orders.{id}`.
  Future<void> subscribeOrderDetail(
    int orderId,
    void Function(Map<String, dynamic>) onOrderEvent,
    {String? token}) async {
    await init(token: token);
    // Channel publik 'orders' (filter berdasarkan orderId di payload)
    await _pusher.subscribe(
      channelName: "orders",
      onEvent: (event) {
        final raw = event.data;
        Map<String, dynamic> payload = {};
        try {
          payload = raw is String
              ? (raw.isNotEmpty
                    ? (jsonDecode(raw) as Map<String, dynamic>)
                    : {})
              : (raw as Map<String, dynamic>? ?? {});
        } catch (_) {}
        final id = payload['id'];
        if (id == orderId) {
          if (event.eventName == "accepted") {
            onOrderEvent({"type": "accepted", "data": event.data});
          } else if (event.eventName == "rejected") {
            onOrderEvent({"type": "rejected", "data": event.data});
          } else if (event.eventName == "completed") {
            onOrderEvent({"type": "completed", "data": event.data});
          } else if (event.eventName == "cancelled") {
            onOrderEvent({"type": "cancelled", "data": event.data});
          }
        }
      },
    );
    // Channel privat 'orders.{id}' untuk event spesifik order
    await _pusher.subscribe(
      channelName: "private-orders.$orderId",
      onEvent: (event) {
        if (event.eventName == "accepted") {
          onOrderEvent({"type": "accepted", "data": event.data});
        } else if (event.eventName == "rejected") {
          onOrderEvent({"type": "rejected", "data": event.data});
        } else if (event.eventName == "completed") {
          onOrderEvent({"type": "completed", "data": event.data});
        } else if (event.eventName == "cancelled") {
          onOrderEvent({"type": "cancelled", "data": event.data});
        }
      },
    );
  }

  /// Berlangganan inbox privat untuk driver tertentu: `private-users.{id}`.
  /// Event yang didukung:
  /// - `order.created` (offer order tertarget)
  /// - `accepted`, `cancelled`, `completed` (tutup/ubah status modal segera)
  Future<void> subscribeDriverInbox(
    int userId,
    void Function(Map<String, dynamic>) onNewOrder, {
    void Function(Map<String, dynamic>)? onAccepted,
    void Function(Map<String, dynamic>)? onCancelled,
    void Function(Map<String, dynamic>)? onCompleted,
    String? token,
  }) async {
    await init(token: token);
    await _pusher.subscribe(
      channelName: "private-users.$userId",
      onEvent: (event) {
        try {
          print('[Broadcast users.$userId] event=${event.eventName} data=${event.data}');
        } catch (_) {}
        if (event.eventName == "order.created") {
          onNewOrder({"data": event.data});
        } else if (event.eventName == "accepted") {
          onAccepted?.call({"data": event.data});
        } else if (event.eventName == "cancelled") {
          onCancelled?.call({"data": event.data});
        } else if (event.eventName == "completed") {
          onCompleted?.call({"data": event.data});
        }
      },
    );
  }

  /// Berlangganan update lokasi driver per order.
  Future<void> subscribeOrderLocation(
    int orderId,
    void Function(Map<String, dynamic>) onLocation, {String? token}
  ) async {
    await init(token: token);
    await _pusher.subscribe(
      channelName: "private-orders.$orderId",
      onEvent: (event) {
        if (event.eventName == "driver.location.updated") {
          onLocation({"data": event.data});
        }
      },
    );
  }

  /// Berhenti berlangganan semua channel dan putuskan koneksi.
  Future<void> unsubscribeAll() async {
    try {
      await _pusher.disconnect();
    } catch (_) {}
    _initialized = false;
  }
}
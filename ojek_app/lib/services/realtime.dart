import 'dart:async';
import 'dart:convert';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class RealtimeService {
  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();
  bool _initialized = false;
  String? _token;

  Future<void> init({String? token}) async {
    if (_initialized) return;
    _token = token;
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
          print('[PUSHER orders] event=${event.eventName} data=${event.data}');
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

  Future<void> subscribeOrderDetail(
    int orderId,
    void Function(Map<String, dynamic>) onOrderEvent,
    {String? token}) async {
    await init(token: token);
    // 1) Subscribe ke channel publik 'orders' dan filter berdasarkan orderId
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
    // 2) Subscribe ke channel private 'orders.{id}' agar event accepted/rejected/completed tetap tertangkap
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

  Future<void> subscribeOrderLocation(
    int orderId,
    void Function(Map<String, dynamic>) onLocation, {String? token}
  ) async {
    await init(token: token);
    // Private channel untuk lokasi driver per order
    await _pusher.subscribe(
      channelName: "private-orders.$orderId",
      onEvent: (event) {
        if (event.eventName == "driver.location.updated") {
          onLocation({"data": event.data});
        }
      },
    );
  }

  Future<void> unsubscribeAll() async {
    try {
      await _pusher.disconnect();
    } catch (_) {}
    _initialized = false;
  }
}

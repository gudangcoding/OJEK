import 'dart:async';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../config.dart';

class RealtimeService {
  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await _pusher.init(
      apiKey: AppConfig.pusherKey,
      cluster: AppConfig.pusherCluster,
      onConnectionStateChange: (current, previous) {},
      onError: (message, code, exception) {},
    );
    await _pusher.connect();
    _initialized = true;
  }

  Future<void> subscribeOrders(void Function(Map<String, dynamic>) onNewOrder) async {
    await init();
    await _pusher.subscribe(channelName: "orders", onEvent: (event) {
      if (event.eventName == "new-order") {
        onNewOrder({"data": event.data});
      }
    });
  }

  Future<void> subscribeOrderDetail(int orderId, void Function(Map<String, dynamic>) onEvent) async {
    await init();
    await _pusher.subscribe(channelName: "order.$orderId", onEvent: (event) {
      if (event.eventName == "accepted") {
        onEvent({"type": "accepted", "data": event.data});
      } else if (event.eventName == "rejected") {
        onEvent({"type": "rejected", "data": event.data});
      } else if (event.eventName == "completed") {
        onEvent({"type": "completed", "data": event.data});
      }
    });
  }

  Future<void> unsubscribeAll() async {
    try {
      await _pusher.disconnect();
    } catch (_) {}
    _initialized = false;
  }
}
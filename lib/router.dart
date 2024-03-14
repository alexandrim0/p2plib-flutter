import 'dart:io';
import 'dart:async';
import 'package:p2plib/p2plib.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'mdns.dart';

class Router extends RouterL3 {
  Router({
    this.port = TransportUdp.defaultPort,
    this.isAppLifecycleListenerEnabled = true,
    this.isConnectivityListenerEnabled = true,
  });

  Router.mdns({
    required String serviceName,
    required String serviceType,
    this.port = TransportUdp.defaultPort,
    this.isAppLifecycleListenerEnabled = true,
    this.isConnectivityListenerEnabled = true,
    Duration timeout = const Duration(seconds: 5),
  }) {
    _mdns = Mdns(
      serviceName: serviceName,
      serviceType: serviceType,
      onPeerFound: _onPeerFound,
      timeout: timeout,
    );
  }

  final int port;

  final bool isAppLifecycleListenerEnabled;

  final bool isConnectivityListenerEnabled;

  final _connectivity = Connectivity();

  late final Mdns? _mdns;

  late final AppLifecycleListener? _appLifecycleListener;

  late final StreamSubscription<ConnectivityResult>? _connectivityChanges;

  _NetworkManagerStatus _status = _NetworkManagerStatus.uninited;

  @override
  Future<Uint8List> init([Uint8List? seed]) async {
    if (_status != _NetworkManagerStatus.uninited) {
      throw Exception('Init once!');
    }
    _status = _NetworkManagerStatus.pending;

    _appLifecycleListener = isAppLifecycleListenerEnabled
        ? AppLifecycleListener(
            onStateChange: (state) async => switch (state) {
              AppLifecycleState.paused => await stop(),
              AppLifecycleState.resumed => await start(),
              _ => null,
            },
          )
        : null;

    _connectivityChanges = isConnectivityListenerEnabled
        ? _connectivity.onConnectivityChanged.listen(
            (state) async => start(state: state),
          )
        : null;

    final actualSeed = await super.init(seed);
    _status = _NetworkManagerStatus.stopped;
    return actualSeed;
  }

  @override
  Future<void> start({int? port, ConnectivityResult? state}) async {
    if (_status == _NetworkManagerStatus.uninited) throw Exception('Uninited!');
    if (_status != _NetworkManagerStatus.stopped) return;
    _status = _NetworkManagerStatus.pending;

    switch (state ?? await _connectivity.checkConnectivity()) {
      case ConnectivityResult.none:
      case ConnectivityResult.bluetooth:
        await stop();

      case ConnectivityResult.wifi:
        await _mdns?.register(selfId.value, port ?? this.port);
        await _mdns?.startDiscovery();
        continue startCase;

      startCase:
      case ConnectivityResult.vpn:
      case ConnectivityResult.other:
      case ConnectivityResult.mobile:
      case ConnectivityResult.ethernet:
        await super.start(port: port ?? this.port);
        _connectivityChanges?.resume();
        if (kDebugMode) print('P2P Network Router started!');
    }
  }

  @override
  Future<void> stop() async {
    if (_status != _NetworkManagerStatus.started) return;
    _status = _NetworkManagerStatus.pending;

    super.stop();
    _connectivityChanges?.pause();
    await _mdns?.stopDiscovery();
    await _mdns?.unregister();
    _status = _NetworkManagerStatus.stopped;
    if (kDebugMode) print('P2P Network Router stopped!');
  }

  Future<void> dispose() async {
    _appLifecycleListener?.dispose();
    await _connectivityChanges?.cancel();
    await stop();
  }

  void _onPeerFound({
    required Uint8List peerId,
    required InternetAddress address,
    int? port,
  }) =>
      addPeerAddress(
        peerId: PeerId(value: peerId),
        address: FullAddress(address: address, port: port ?? this.port),
        properties: AddressProperties(isLocal: true, isStatic: true),
      );
}

enum _NetworkManagerStatus { uninited, stopped, started, pending }

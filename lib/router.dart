import 'dart:io';
import 'dart:async';
import 'package:p2plib/p2plib.dart';
import 'package:flutter/foundation.dart';

import 'mdns.dart';

class Router extends RouterL3 {
  Router({
    this.port = TransportUdp.defaultPort,
    this.debounceInterval = const Duration(seconds: 1),
    super.logger = kDebugMode ? print : null,
  }) : _mdns = null;

  Router.mdns({
    required String serviceName,
    required String serviceType,
    this.port = TransportUdp.defaultPort,
    this.debounceInterval = const Duration(seconds: 1),
    Duration mdnsTimeout = const Duration(seconds: 5),
    super.logger = kDebugMode ? print : null,
  }) {
    _mdns = Mdns(
      serviceName: serviceName,
      serviceType: serviceType,
      timeout: mdnsTimeout,
      onPeerFound: ({
        required Uint8List peerId,
        required InternetAddress address,
        int? port,
      }) =>
          addPeerAddress(
        peerId: PeerId(value: peerId),
        address: FullAddress(address: address, port: port ?? this.port),
        properties: AddressProperties(isLocal: true, isStatic: true),
      ),
    );
  }

  final int port;

  final Duration debounceInterval;

  late final Mdns? _mdns;

  Timer? _timer;

  @override
  Future<void> start({int? port}) async {
    if (_timer?.isActive ?? false) _timer?.cancel();
    _timer = Timer(
      debounceInterval,
      () async {
        await super.start(port: port ?? this.port);
        if (kDebugMode) print('P2P network started!');
        await _mdns?.start(selfId.value, port ?? this.port);
      },
    );
  }

  @override
  Future<void> stop() async {
    if (_timer?.isActive ?? false) _timer?.cancel();
    _timer = Timer(
      debounceInterval,
      () async {
        super.stop();
        if (kDebugMode) print('P2P network stopped!');
        await _mdns?.stop();
      },
    );
  }
}

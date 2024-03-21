import 'dart:io';
import 'dart:async';
import 'package:p2plib/p2plib.dart';

import 'mdns.dart';

class Router extends RouterL3 {
  Router({
    this.port = TransportUdp.defaultPort,
    this.debounceInterval = const Duration(seconds: 1),
  }) : _mdns = null;

  Router.mdns({
    required String serviceName,
    required String serviceType,
    this.port = TransportUdp.defaultPort,
    this.debounceInterval = const Duration(seconds: 1),
    Duration mdnsTimeout = const Duration(seconds: 5),
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

  bool _isStarted = false;

  Timer? timer;

  @override
  Future<void> start({int? port}) async {
    if (_isStarted) return;
    if (timer?.isActive ?? false) timer?.cancel();
    timer = Timer(
      debounceInterval,
      () async {
        await super.start(port: port ?? this.port);
        _isStarted = true;
        await _mdns?.start(selfId.value, port ?? this.port);
      },
    );
  }

  @override
  Future<void> stop() async {
    if (!_isStarted) return;
    if (timer?.isActive ?? false) timer?.cancel();
    timer = Timer(
      debounceInterval,
      () async {
        super.stop();
        await _mdns?.stop();
      },
    );
  }
}

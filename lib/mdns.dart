import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:nsd/nsd.dart' as nsd;
import 'package:flutter/foundation.dart';

typedef OnServiceFoundCallback = void Function({
  required Uint8List peerId,
  required InternetAddress address,
  int? port,
});

class Mdns {
  Mdns({
    required this.serviceName,
    required this.serviceType,
    required this.onPeerFound,
    this.timeout = const Duration(seconds: 5),
  });

  final Duration timeout;
  final String serviceName;
  final String serviceType;
  final OnServiceFoundCallback onPeerFound;

  nsd.Registration? _registration;
  nsd.Discovery? _discovery;

  Future<void> register(Uint8List peerId, int port) async {
    try {
      _registration ??= await nsd
          .register(
            nsd.Service(
              name: serviceName,
              type: serviceType,
              port: port,
              txt: {
                _txtPeerId: _utf8Encoder.convert(base64Encode(peerId)),
              },
            ),
          )
          .timeout(timeout);
    } catch (e) {
      if (kDebugMode) print(e);
    }
  }

  Future<void> unregister() async {
    if (_registration == null) return;
    final registration = _registration!;
    _registration = null;
    await nsd.unregister(registration);
  }

  Future<void> startDiscovery() async {
    try {
      _discovery ??= await nsd
          .startDiscovery(serviceType, ipLookupType: nsd.IpLookupType.any)
          .timeout(timeout)
        ..addServiceListener(_onServiceFound);
    } on TimeoutException catch (e) {
      if (kDebugMode) print(e);
    }
  }

  Future<void> stopDiscovery() async {
    if (_discovery == null) return;
    final discovery = _discovery!;
    _discovery = null;
    try {
      await nsd.stopDiscovery(discovery);
      discovery.dispose();
    } on TimeoutException catch (e) {
      if (kDebugMode) print(e);
    }
  }

  void _onServiceFound(
    nsd.Service service,
    nsd.ServiceStatus status,
  ) {
    if (kDebugMode) print('mDNS $status: ${service.addresses}');
    if (service.type != serviceType) return;

    final peerIdBytes = service.txt?[_txtPeerId];
    if (peerIdBytes == null || peerIdBytes.isEmpty) return;

    if (status == nsd.ServiceStatus.found) {
      for (final address in service.addresses!) {
        if (address.isLinkLocal || address.address.isEmpty) continue;
        onPeerFound(
          address: address,
          port: service.port,
          peerId: base64Decode(_utf8Decoder.convert(peerIdBytes)),
        );
      }
    }
  }

  static const _txtPeerId = 'peerId';
  static const _utf8Encoder = Utf8Encoder();
  static const _utf8Decoder = Utf8Decoder();
}

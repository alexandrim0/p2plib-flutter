import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:nsd/nsd.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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

  final void Function({
    required Uint8List peerId,
    required InternetAddress address,
    int? port,
  }) onPeerFound;

  Registration? _registration;
  Discovery? _discovery;

  Future<void> start(Uint8List peerId, int port) async {
    if (await Connectivity().checkConnectivity() == ConnectivityResult.wifi) {
      try {
        _registration ??= await register(
          Service(
            name: serviceName,
            type: serviceType,
            port: port,
            txt: {
              _txtPeerId: _utf8Encoder.convert(base64Encode(peerId)),
            },
          ),
        ).timeout(timeout);
      } catch (e) {
        if (kDebugMode) print(e);
      }
      try {
        _discovery ??=
            await startDiscovery(serviceType, ipLookupType: IpLookupType.any)
                .timeout(timeout)
              ..addServiceListener(_onServiceFound);
      } catch (e) {
        if (kDebugMode) print(e);
      }
    }
  }

  Future<void> stop() async {
    if (_registration != null) {
      try {
        await unregister(_registration!);
      } catch (e) {
        if (kDebugMode) print(e);
      } finally {
        _registration = null;
      }
    }
    if (_discovery != null) {
      try {
        await stopDiscovery(_discovery!);
        _discovery?.dispose();
      } catch (e) {
        if (kDebugMode) print(e);
      } finally {
        _discovery = null;
      }
    }
  }

  void _onServiceFound(Service service, ServiceStatus status) {
    if (kDebugMode) print('mDNS $status: ${service.addresses}');
    if (service.type != serviceType) return;

    final peerIdBytes = service.txt?[_txtPeerId];
    if (peerIdBytes == null || peerIdBytes.isEmpty) return;

    if (status == ServiceStatus.found) {
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

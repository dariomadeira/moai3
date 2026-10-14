import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:moai3/config/constants.dart';

/// Payload de input etiquetado por frame sobre DataChannel.
class ArcadeNetplayInputPacket {
  final int frame;
  final int mask;
  final String senderDeviceId;

  const ArcadeNetplayInputPacket({
    required this.frame,
    required this.mask,
    required this.senderDeviceId,
  });

  Map<String, dynamic> toJson() => {
        't': 'input',
        'frame': frame,
        'mask': mask,
        'senderDeviceId': senderDeviceId,
      };

  static ArcadeNetplayInputPacket? tryParse(Map<String, dynamic> map) {
    if (map['t'] != 'input') return null;
    return ArcadeNetplayInputPacket(
      frame: (map['frame'] as num?)?.toInt() ?? 0,
      mask: (map['mask'] as num?)?.toInt() ?? 0,
      senderDeviceId: map['senderDeviceId'] as String? ?? '',
    );
  }
}

/// Transporte P2P WebRTC (DataChannel) para inputs de netplay.
/// La señalización SDP/ICE la hace el caller vía Supabase.
class ArcadeWebRtcTransport {
  RTCPeerConnection? _pc;
  RTCDataChannel? _dc;
  final List<RTCIceCandidate> _pendingRemoteIce = [];
  bool _remoteDescriptionSet = false;

  final StreamController<ArcadeNetplayInputPacket> _inputController =
      StreamController<ArcadeNetplayInputPacket>.broadcast();
  final StreamController<Map<String, dynamic>> _signalOutController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _stateController =
      StreamController<String>.broadcast();

  Stream<ArcadeNetplayInputPacket> get onInput => _inputController.stream;
  Stream<Map<String, dynamic>> get onSignalOut => _signalOutController.stream;
  Stream<String> get onState => _stateController.stream;

  bool get isConnected =>
      _dc != null && _dc!.state == RTCDataChannelState.RTCDataChannelOpen;

  Future<void> startAsHost() async {
    await _createPeer(isHost: true);
    final dc = await _pc!.createDataChannel(
      'arcade_inputs',
      RTCDataChannelInit()
        ..ordered = true
        ..maxRetransmits = 0,
    );
    _attachDataChannel(dc);
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    _signalOutController.add({
      'type': 'webrtc_offer',
      'sdp': offer.sdp,
      'sdpType': offer.type,
    });
  }

  Future<void> startAsGuest() async {
    await _createPeer(isHost: false);
  }

  Future<void> handleRemoteSignal(Map<String, dynamic> msg) async {
    final type = msg['type'] as String?;
    if (type == null || _pc == null) return;

    try {
      if (type == 'webrtc_offer') {
        final sdp = msg['sdp'] as String? ?? '';
        final sdpType = msg['sdpType'] as String? ?? 'offer';
        await _pc!.setRemoteDescription(RTCSessionDescription(sdp, sdpType));
        _remoteDescriptionSet = true;
        await _flushPendingIce();
        final answer = await _pc!.createAnswer();
        await _pc!.setLocalDescription(answer);
        _signalOutController.add({
          'type': 'webrtc_answer',
          'sdp': answer.sdp,
          'sdpType': answer.type,
        });
      } else if (type == 'webrtc_answer') {
        final sdp = msg['sdp'] as String? ?? '';
        final sdpType = msg['sdpType'] as String? ?? 'answer';
        await _pc!.setRemoteDescription(RTCSessionDescription(sdp, sdpType));
        _remoteDescriptionSet = true;
        await _flushPendingIce();
      } else if (type == 'webrtc_ice') {
        final candidate = msg['candidate'] as String?;
        if (candidate == null || candidate.isEmpty) return;
        final ice = RTCIceCandidate(
          candidate,
          msg['sdpMid'] as String?,
          msg['sdpMLineIndex'] as int?,
        );
        if (!_remoteDescriptionSet) {
          _pendingRemoteIce.add(ice);
        } else {
          await _pc!.addCandidate(ice);
        }
      } else if (type == 'netplay_start') {
        _stateController.add('netplay_start');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ArcadeWebRtcTransport] signal error: $e');
      }
      _stateController.add('error:$e');
    }
  }

  void sendInput(ArcadeNetplayInputPacket packet) {
    final dc = _dc;
    if (dc == null || dc.state != RTCDataChannelState.RTCDataChannelOpen) {
      return;
    }
    try {
      dc.send(RTCDataChannelMessage(jsonEncode(packet.toJson())));
    } catch (_) {}
  }

  void sendNetplayStart() {
    final dc = _dc;
    if (dc == null || dc.state != RTCDataChannelState.RTCDataChannelOpen) {
      return;
    }
    try {
      dc.send(RTCDataChannelMessage(jsonEncode({'t': 'netplay_start'})));
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _dc?.close();
    } catch (_) {}
    _dc = null;
    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;
    _pendingRemoteIce.clear();
    _remoteDescriptionSet = false;
  }

  Future<void> _createPeer({required bool isHost}) async {
    await dispose();
    final iceServers = <Map<String, dynamic>>[
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
        ],
      },
    ];
    final turnUrl = kTurnUrl;
    if (turnUrl.isNotEmpty) {
      iceServers.add({
        'urls': turnUrl,
        if (kTurnUsername.isNotEmpty) 'username': kTurnUsername,
        if (kTurnPassword.isNotEmpty) 'credential': kTurnPassword,
      });
    }

    _pc = await createPeerConnection({
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    });

    _pc!.onIceCandidate = (RTCIceCandidate c) {
      if (c.candidate == null || c.candidate!.isEmpty) return;
      _signalOutController.add({
        'type': 'webrtc_ice',
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    };

    _pc!.onConnectionState = (RTCPeerConnectionState state) {
      _stateController.add('pc:$state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _stateController.add('ice_failed');
      }
    };

    if (!isHost) {
      _pc!.onDataChannel = (RTCDataChannel dc) {
        _attachDataChannel(dc);
      };
    }
  }

  void _attachDataChannel(RTCDataChannel dc) {
    _dc = dc;
    dc.onDataChannelState = (RTCDataChannelState state) {
      _stateController.add('dc:$state');
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _stateController.add('connected');
      }
    };
    dc.onMessage = (RTCDataChannelMessage message) {
      if (message.isBinary) return;
      try {
        final map = jsonDecode(message.text) as Map<String, dynamic>;
        if (map['t'] == 'netplay_start') {
          _stateController.add('netplay_start');
          return;
        }
        final packet = ArcadeNetplayInputPacket.tryParse(map);
        if (packet != null && !_inputController.isClosed) {
          _inputController.add(packet);
        }
      } catch (_) {}
    };
  }

  Future<void> _flushPendingIce() async {
    for (final ice in _pendingRemoteIce) {
      try {
        await _pc?.addCandidate(ice);
      } catch (_) {}
    }
    _pendingRemoteIce.clear();
  }
}

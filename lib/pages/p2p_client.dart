import "dart:convert";
import "dart:typed_data";

import "package:appf/providers/socket_provider.dart";
import "package:appf/providers/user_provider.dart";
import "package:flutter/material.dart";
import "package:flutter_background/flutter_background.dart";
import "package:permission_handler/permission_handler.dart";
import "package:provider/provider.dart";
import "package:web_socket_channel/web_socket_channel.dart";
import "package:flutter_webrtc/flutter_webrtc.dart";

import "../utils/global.dart";

class P2pClient extends StatefulWidget {
  P2pClient({Key? key}) : super(key: key);

  @override
  _P2pClientState createState() => _P2pClientState();
}

class _P2pClientState extends State<P2pClient> {
  WebSocketChannel? channel;
  SocketProvider? socketProvider;

  MediaStream? _localStream;
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  bool isOpen = false;

  _P2pClientState() {
    connectGolang();
    initRenderer();
  }

  open() async {
    // Permission.
    final Map<String, dynamic> mediaConstraints = {
      "audio": true,
      "video": {"width": 1280, "height": 720}
    };
    try {
      navigator.mediaDevices
          .getUserMedia(mediaConstraints)
          // navigator.mediaDevices.getDisplayMedia(mediaConstraints)
          .then((stream) {
        print("获取到stream流");
        print(stream);
        setState(() {
          _localStream = stream;
          _renderer.srcObject = stream;
        });
      });
    } catch (e) {
      print(e);
    }
    setState(() {
      isOpen = true;
    });
  }

  close() async {
    try {
      await _localStream?.dispose();
      _renderer.srcObject = null;
    } catch (e) {
      print(e);
    }
    setState(() {
      isOpen = false;
    });
  }

  initRenderer() async {
    await _renderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  void dispose() {
    super.dispose();
    _renderer.dispose();
  }

  connectGolang() async {
    context.read<SocketProvider>().initSocket();
  }

  sendDataForSocket() {
    context.read<SocketProvider>().sendDataForSocket();
  }

  //远端媒体流
  MediaStream? _remoteStream;

  //本地连接
  RTCPeerConnection? _localConnection;

  //远端连接
  RTCPeerConnection? _remoteConnection;

  //远端视频渲染对象
  final _remoteRenderer = RTCVideoRenderer();

  //是否连接
  bool _isConnected = false;

  //媒体约束
  final Map<String, dynamic> mediaConstraints = {
    //开启音频
    "audio": true,
    "video": {
      "mandatory": {
        //宽度
        "minWidth": '640',
        //高度
        "minHeight": '480',
        //帧率
        "minFrameRate": '30',
      },
      "facingMode": "environment",
      "optional": [],
    }
  };

  Map<String, dynamic> configuration = {
    //使用google的服务器
    "iceServers": [
      {"url": "stun:stun.l.google.com:19302"},
    ]
  };

  //sdp约束
  final Map<String, dynamic> sdp_constraints = {
    "mandatory": {
      //是否接收语音数据
      "OfferToReceiveAudio": true,
      //是否接收视频数据
      "OfferToReceiveVideo": true,
    },
    "optional": [],
  };

  //PeerConnection约束
  final Map<String, dynamic> pc_constraints = {
    "mandatory": {},
    "optional": [
      //如果要与浏览器互通开启DtlsSrtpKeyAgreement,此处不开启
      {"DtlsSrtpKeyAgreement": false},
    ],
  };

  initLocalRtc() async {
    // if (_localConnection != null || _remoteConnection != null) return;
    try {
      _localStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);
      Global.navigatorKey.currentContext!
              .read<SocketProvider>()
              .localConnection =
          await createPeerConnection(configuration, pc_constraints);
      _localConnection = Global.navigatorKey.currentContext!
          .read<SocketProvider>()
          .localConnection;
      setState(() {
        _renderer.srcObject = _localStream;
      });

      // _localConnection!.addStream(_localStream!);
      var tracks = _localStream!.getTracks();
      if (tracks.isNotEmpty) {
        for (var track in tracks) {
          // if(track.kind);
          if (track.kind == "video") {
            _localConnection!.addTrack(track, _localStream!);
          }
        }
      }
      //添加本地Candidate事件监听
      _localConnection!.onIceCandidate = _onLocalCandidate;
      //添加本地Ice连接状态事件监听
      _localConnection!.onIceConnectionState = _onLocalIceConnectionState;
      createDataChannel();
      _localConnection!.onTrack = _onLocalTrack;
      _localConnection!.onDataChannel = _onLocalDataChannel;
      //创建远端连接对象
      // _remoteConnection =
      //     await createPeerConnection(configuration, pc_constraints);
      // //添加远端Candidate事件监听
      // _remoteConnection!.onIceCandidate = _onRemoteCandidate;
      // //监听获取到远端视频流事件
      // _remoteConnection!.onAddStream = _onRemoteAddStream;
      // //添加远端Ice连接状态事件监听
      // _remoteConnection!.onIceConnectionState = _onRemoteIceConnectionState;
    } catch (e) {}
  }

  _onLocalDataChannel(RTCDataChannel channel) {
    channel.onMessage = (RTCDataChannelMessage data) {
      print("on message触发");
      print(data);
      if (data.isBinary) {
        print(data.binary);
      } else {
        print(data.text);
      }
    };
    channel.onDataChannelState = (RTCDataChannelState state) {
      print("channel.onDataChannelState");
      print(state.toString());
    };
  }

  tryConnectOther() async {
    var ur = context.read<UserProvider>();
    var sr = context.read<SocketProvider>();
    if (ur.userList.isNotEmpty) {
      print(ur.userList.first);
      var offer = await _localConnection!.createOffer(pc_constraints);
      print("本地offer内容生成:");
      print(offer);
      _localConnection!.setLocalDescription(offer);
      print("本地setLocalDescription完成");
      var data = {
        "type": eventNames["Offer"],
        "data": {
          "roomId": ur.roomId,
          "to": ur.userList.first["id"],
          "sdp": offer.toMap(),
          "type": eventNames["Offer"],
          "from": ur.username,
        }
      };
      sr.channel!.sink.add(jsonEncode(data));
    } else {
      print("当前房间没有其他人，无法发起链接");
    }
  }

  _onLocalTrack(RTCTrackEvent event) {
    print("本地track接收到新track");
    print(event);
  }

  //远端Ice连接状态
  _onRemoteIceConnectionState(RTCIceConnectionState state) {
    print(state);
  }

  //远端流添加成功回调
  _onRemoteAddStream(MediaStream stream) {
    print('Remote addStream: ' + stream.id);
    //得到远端媒体流
    _remoteStream = stream;
    //将远端视频渲染对象与媒体流绑定
    _remoteRenderer.srcObject = stream;
  }

  //本地Ice连接状态
  _onLocalIceConnectionState(RTCIceConnectionState state) {
    print("本地Ice连接状态");
    print(state);
  }

  //本地Candidate数据回调
  _onLocalCandidate(RTCIceCandidate candidate) {
    print('LocalCandidate: ');
    print(candidate?.candidate);
    print("应该发送到golang服务器");
    //将本地Candidate添加至远端连接
    var sp = context.read<SocketProvider>();
    var up = context.read<UserProvider>();
    var data = {
      "type": eventNames["Candidate"],
      "data": {
        "roomId": up.roomId,
        "candidate": candidate.toMap(),
        "to": up.userList.first["id"],
        "from": up.username,
        "type": eventNames["Candidate"],
      }
    };
    sp.channel!.sink.add(jsonEncode(data));
  }

  //远端Candidate数据回调
  _onRemoteCandidate(RTCIceCandidate candidate) {
    print('RemoteCandidate: ');
    print(candidate?.candidate);
    //将远端Candidate添加至本地连接
    _localConnection?.addCandidate(candidate);
  }

  getRoomId() {
    var userProvider = context.read<UserProvider>();
    print(userProvider.userList);
  }

  // 切换摄像头
  switchCamera() async {
    var deviceInfo = await navigator.mediaDevices.enumerateDevices();
    if (_localStream == null) return;
    var tracks = _localStream!.getTracks();
    if (tracks.isNotEmpty && deviceInfo.isNotEmpty) {
      var deviceId = deviceInfo
          .firstWhere((element) => element.kind == "videoinput")
          .deviceId;
      var track = tracks.firstWhere((element) => element.kind == "video");
      Helper.switchCamera(track, deviceId, _localStream);
    }
  }

  RTCDataChannel? _localSendChannel;

  createDataChannel() async {
    var _dataChannelDict = RTCDataChannelInit();
    //实例化DataChannel初始化对象
    _dataChannelDict = RTCDataChannelInit();
    //创建RTCDataChannel对象时设置的通道的唯一id
    _dataChannelDict.id = 1;
    //表示通过RTCDataChannel的信息的到达顺序需要和发送顺序一致
    _dataChannelDict.ordered = true;
    //最大重传时间
    _dataChannelDict.maxRetransmitTime = -1;
    //最大重传次数
    _dataChannelDict.maxRetransmits = -1;
    //传输协议
    _dataChannelDict.protocol = "sctp";
    //是否由用户代理或应用程序协商频道
    _dataChannelDict.negotiated = false;

    _localSendChannel = await _localConnection!
        .createDataChannel("fuckChannel", _dataChannelDict);
    print("_localSendChannel创建成功");
  }

  sendDataForDataChannel() {
    _localSendChannel!.send(RTCDataChannelMessage("测试发送datachannel"));
  }

  sendBinaryForDataChannel() {
    var units = "sdjfklsd".codeUnits;
    Uint8List i = Uint8List.fromList(units);
    _localSendChannel!.send(RTCDataChannelMessage.fromBinary(i));
  }

  @override
  Widget build(BuildContext context) {
    var userProvider = context.watch<UserProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text("P2P"),
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          Row(
            children: [
              Text("用户名:${userProvider.username}"),
              const SizedBox(
                width: 20,
              ),
              Text("roomId:${userProvider.roomId}"),
            ],
          ),
          ElevatedButton(
              onPressed: connectGolang, child: const Text("链接websocket")),
          ElevatedButton(
              onPressed: sendDataForSocket, child: const Text("主动发送")),
          ElevatedButton(onPressed: open, child: const Text("open")),
          ElevatedButton(onPressed: close, child: const Text("close")),
          ElevatedButton(onPressed: getRoomId, child: const Text("getRoomId")),
          Row(
            children: [
              ElevatedButton(
                  onPressed: initLocalRtc, child: const Text("初始化webrtc")),
              ElevatedButton(
                  onPressed: tryConnectOther, child: const Text("try connect")),
            ],
          ),
          Row(
            children: [
              ElevatedButton(
                  onPressed: switchCamera, child: const Text("switch camera")),
            ],
          ),
          Row(
            children: [
              ElevatedButton(
                  onPressed: sendDataForDataChannel,
                  child: const Text("send text data")),
              ElevatedButton(
                  onPressed: sendBinaryForDataChannel,
                  child: const Text("send ")),
            ],
          ),
          Container(
            height: 322,
            width: double.infinity,
            decoration: const BoxDecoration(color: Colors.black),
            child: RTCVideoView(_renderer),
          ),
          Container(
            height: 322,
            width: double.infinity,
            decoration: const BoxDecoration(color: Colors.yellow),
            child: RTCVideoView(_remoteRenderer),
          )
        ]),
      ),
    );
  }
}

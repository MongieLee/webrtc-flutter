import 'dart:convert';

import 'package:appf/providers/user_provider.dart';
import 'package:appf/utils/global.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const eventNames = {
  "JoinRoom": "joinRoom", // 加入房间
  "Offer": "offer", // Offer消息
  "Answer": "answer", // Answer消息
  "Candidate": "candidate", // Cadidate消息
  "HangUp": "hangUp", // 挂断
  "LeaveRoom": "leaveRoom", // 离开房间
  "UpdateUserList": "updateUserList", // 更新房间用户列表
};

class SocketProvider with ChangeNotifier {
  WebSocketChannel? channel;
  var uri = Uri.parse("wss://mongielee.top:8080/ws");

  //本地连接
  RTCPeerConnection? localConnection;

  //远端连接
  RTCPeerConnection? remoteConnection;

  initSocket() async {
    if (channel == null) {
      channel = WebSocketChannel.connect(uri);
      channel!.ready;
      channel!.stream.listen(handleSocketEvent);
      print("socket已建立链接");
      var userProvider =
          Global.navigatorKey.currentContext!.read<UserProvider>();
      var sendData = {
        "type": eventNames["JoinRoom"],
        "data": {
          "roomId": userProvider.roomId,
          "id": userProvider.username,
          "type": eventNames["JoinRoom"],
          "name": userProvider.username,
          "from": userProvider.username,
        }
      };
      channel!.sink.add(jsonEncode(sendData));
    }
  }

  disconnect() {
    channel!.sink.close();
    channel = null;
  }

  handleSocketEvent(event) {
    var data = jsonDecode(event);
    print("data:");
    print(data);
    switch (data["type"]) {
      case "heartPackage":
        print("接收到socket心跳包");
        break;
      case "candidate":
        handleCandidate(data);
        break;
      case "offer":
        handleOffer(data);
        break;
      case "answer":
        handleAnswer(data);
        break;
      case "hangUp":
        break;
      case "joinRoom":
        break;
      case "leaveRoom":
        break;
      case "isFull":
        Fluttertoast.showToast(msg: "房间已满人，无法加入");
        break;
      case "updateUserList":
        updateRoomInfo(data);
        break;
      default:
        print("获取到的事件");
        print(data["type"]);
        print(data);
        Fluttertoast.showToast(msg: "未知的事件类型");
        break;
    }
  }

  updateRoomInfo(data) {
    print("接收到updateRoomInfo事件:");
    print(data);
    print(data.runtimeType);
    print(data["data"]);
    print(data["data"].runtimeType);
    Global.navigatorKey.currentContext!.read<UserProvider>().userList =
        data["data"];
  }

  handleOffer(data) {
    print("接收到handleOffer事件:");
    print(data);
  }

  handleAnswer(data) {
    print("接收到handleAnswer事件:");
    print(data["sdp"]["sdp"]);
    print(data["sdp"]["type"]);
    var sdp = RTCSessionDescription(data["sdp"]["sdp"], data["sdp"]["type"]);
    localConnection!.setRemoteDescription(sdp);
  }

  handleCandidate(data) {
    print("接收到handleCandidate事件:");
    var a = data["candidate"];
    print(a["candidate"]);
    print(a["sdpMid"]);
    print(a["sdpMLineIndex"]);
    var b = RTCIceCandidate(a["candidate"], a["sdpMid"], a['sdpMLineIndex']);
    localConnection!.addCandidate(b);
  }

  sendDataForSocket() {
    var up = Global.navigatorKey.currentContext!.read<UserProvider>();
    if (channel != null) {
      channel!.sink
          .add('{"type":"fuck","data":{"a":1,"roomId":"${up.roomId}"}');
    }
  }
}

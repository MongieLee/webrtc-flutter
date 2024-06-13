import "package:appf/pages/p2p_client.dart";
import "package:appf/providers/user_provider.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:provider/provider.dart";

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  String username = "";
  String roomId = "";

  handleJoin() {
    var userProvider = context.read<UserProvider>();
    userProvider.updateUsername(username);
    userProvider.updateRoomId(roomId);
    setState(() {
      username = "";
      roomId = "";
    });
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return P2pClient();
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      child: Column(children: [
        SizedBox(
            child: TextField(
          keyboardType: TextInputType.text,
          decoration: InputDecoration(hintText: "请输入用户名"),
          onChanged: (value) {
            setState(() {
              username = value;
            });
          },
        )),
        SizedBox(
            child: TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: "请输入房间号"),
          onChanged: (value) {
            setState(() {
              roomId = value;
            });
          },
        )),
        ElevatedButton(
            onPressed: () {
              if (username.isNotEmpty && roomId.isNotEmpty) {
                handleJoin();
              } else {
                print("用户名和房间号不能为空");
              }
            },
            child: Text("登陆"))
      ]),
    );
  }
}

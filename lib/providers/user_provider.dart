import 'package:flutter/cupertino.dart';

class UserProvider with ChangeNotifier {
  String username = "";
  String roomId = "";

  List userList = [];

  updateUsername(String newUsername) {
    username = newUsername;
    notifyListeners();
  }

  updateRoomId(String newRoomId) {
    roomId = newRoomId;
    notifyListeners();
  }
}

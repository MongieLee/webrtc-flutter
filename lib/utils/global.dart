import 'package:event_bus/event_bus.dart';
import 'package:flutter/cupertino.dart';

class Global {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static EventBus eventBus = EventBus();
}

import 'package:firebase_chat/screens/chat_screen.dart';
import 'package:firebase_chat/screens/login_or_register.dart';
import 'package:firebase_chat/screens/users_list.dart';
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData.dark(),
      // home: MyHomePage(title: 'Flutter Demo Home Page'),
      initialRoute: 'login-or-register',
      routes: {
        'login-or-register': (cxt) => LoginOrRegister(),
        'users-list': (cxt) => UsersList(),
        'chat': (cxt) => ChatScreen(),
      },
    );
  }
}

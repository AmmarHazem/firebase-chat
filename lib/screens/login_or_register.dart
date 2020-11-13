import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LoginOrRegister extends StatefulWidget {
  @override
  _LoginOrRegisterState createState() => _LoginOrRegisterState();
}

class _LoginOrRegisterState extends State<LoginOrRegister> {
  final _fireAuth = FirebaseAuth.instance;
  final _fireStore = Firestore.instance;
  final _fcm = FirebaseMessaging();
  final _emailFieldController = TextEditingController();
  final _passwordFieldController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  StreamSubscription _iosNotificationsSubscription;
  SharedPreferences _prefs;
  bool _loginMode = true;
  Map<String, dynamic> _errors = {};

  @override
  initState() {
    super.initState();

    _handleNotifications();
    Future.delayed(Duration.zero, () async {
      _prefs = await SharedPreferences.getInstance();
      if (_prefs.getBool('isAuth') ?? false) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          'users-list',
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _iosNotificationsSubscription?.cancel();
    super.dispose();
  }

  void _handleNotifications() async {
    if (Platform.isIOS) {
      _iosNotificationsSubscription =
          _fcm.onIosSettingsRegistered.listen((notificationsSettings) async {
        final token = await _fcm.getToken();
        print('--- ios token $token');
      });
      _fcm.requestNotificationPermissions(IosNotificationSettings());
    }
    _fcm.configure(
      onMessage: (Map<String, dynamic> message) async {
        print("onMessage: $message");
        Scaffold.of(context).showSnackBar(SnackBar(
          content: Text('New Notification'),
        ));
      },
      onLaunch: (Map<String, dynamic> message) async {
        print("onLaunch: $message");
      },
      onResume: (Map<String, dynamic> message) async {
        print("onResume: $message");
      },
    );
    // final token = await _fcm.getToken();
    // print(token);
  }

  Future<void> _loginOrRegister() async {
    _errors = {};
    if (!_formKey.currentState.validate()) return;
    try {
      showDialog(
        context: context,
        builder: (cxt) => Center(child: CircularProgressIndicator()),
      );
      if (_loginMode) {
        await _login();
      } else {
        await _register();
      }
      _prefs = await SharedPreferences.getInstance();
      _prefs.setBool('isAuth', true);
      Navigator.pushNamedAndRemoveUntil(
        context,
        'users-list',
        (route) => false,
      );
    } on PlatformException catch (e) {
      print('--- login or register error ');
      print(e);
      Navigator.pop(context);
      if (e.code == 'ERROR_USER_NOT_FOUND') {
        _errors['email'] = e.message;
      } else {
        _errors['password'] = e.message;
      }
      _formKey.currentState.validate();
    }
  }

  Future<void> _login() async {
    await _fireAuth.signInWithEmailAndPassword(
      email: _emailFieldController.text,
      password: _passwordFieldController.text,
    );
  }

  Future<void> _register() async {
    final authRes = await _fireAuth.createUserWithEmailAndPassword(
      email: _emailFieldController.text,
      password: _passwordFieldController.text,
    );
    // await _fireAuth.signInWithEmailAndPassword(
    //   email: _emailFieldController.text,
    //   password: _passwordFieldController.text,
    // );
    _fireStore.collection('users').add({
      'email': _emailFieldController.text,
      'id': authRes.user.uid,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      _loginMode ? 'Login' : 'Register',
                      style: Theme.of(context).textTheme.display1,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailFieldController,
                      validator: (value) {
                        if (_errors['email'] != null) return _errors['email'];
                        return null;
                      },
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      validator: (value) {
                        if (_errors['password'] != null)
                          return _errors['password'];
                        return null;
                      },
                      controller: _passwordFieldController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (!_loginMode) const SizedBox(height: 20),
                    if (!_loginMode)
                      TextFormField(
                        validator: (value) {
                          if (value.isEmpty) {
                            return 'Confirm password';
                          }
                          if (value != _passwordFieldController.text) {
                            return 'Password did not match';
                          }
                          if (_errors['confirm_password'] != null)
                            return _errors['confirm_password'];
                          return null;
                        },
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    const SizedBox(height: 20),
                    RaisedButton(
                      onPressed: _loginOrRegister,
                      child: Text(_loginMode ? 'Login' : 'Register'),
                    ),
                    const SizedBox(height: 20),
                    FlatButton(
                      child: Text(_loginMode ? 'Or Register' : 'Or Login'),
                      onPressed: () => setState(() => _loginMode = !_loginMode),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

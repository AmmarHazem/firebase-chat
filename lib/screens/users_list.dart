import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UsersList extends StatefulWidget {
  @override
  _UsersListState createState() => _UsersListState();
}

class _UsersListState extends State<UsersList> with WidgetsBindingObserver {
  final _fireAuth = FirebaseAuth.instance;
  final _fireStore = Firestore.instance;
  FirebaseUser _currentUser;
  var _online = false;
  // List<Map> _currentUserConversations = [];

  @override
  initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    Future.delayed(Duration.zero, () async {
      _currentUser = await _fireAuth.currentUser();
      _setOnlineState(true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setOnlineState(bool online) async {
    if (online == _online) return;
    setState(() {
      _online = online;
    });
    final snapshot = await _fireStore
        .collection('users')
        .where('id', isEqualTo: _currentUser.uid)
        .getDocuments();
    snapshot.documentChanges[0].document.reference.updateData({
      'online': online,
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _setOnlineState(false);
        break;
      case AppLifecycleState.resumed:
        _setOnlineState(true);
        break;
    }
  }

  // void _getCurrentUserConversations() async {
  //   final snapshot = await _fireStore
  //       .collection('conversations')
  //       .where('users', arrayContains: _currentUser.uid)
  //       .getDocuments();
  //   snapshot.documents
  //       .forEach((doc) => _currentUserConversations.add(doc.data));
  // }

  Future<void> _logout(BuildContext context) async {
    await _fireAuth.signOut();
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('isAuth');
    Navigator.pushNamedAndRemoveUntil(
      context,
      'login-or-register',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select a user to chat with'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () => _logout(context),
          )
        ],
      ),
      body: SafeArea(
        child: StreamBuilder(
          stream: _fireStore
              .collection('users')
              .orderBy('created_at', descending: true)
              .snapshots(),
          builder: (cxt, AsyncSnapshot<QuerySnapshot> snapshot) {
            List<Widget> listViewItems = [];
            if (snapshot.hasData && _currentUser != null) {
              listViewItems = snapshot.data.documents
                  .where((doc) => doc.data['email'] != _currentUser.email)
                  .map<Widget>((doc) {
                bool online = doc.data['online'];
                return ListTile(
                  title: Text(doc.data['email']),
                  subtitle: Row(
                    children: <Widget>[
                      AnimatedContainer(
                        duration: Duration(milliseconds: 400),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: online ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      AnimatedSwitcher(
                        duration: Duration(milliseconds: 400),
                        child: online
                            ? Text(
                                'Online',
                              key: ValueKey('online'),
                                style: Theme.of(context)
                                    .textTheme
                                    .caption
                                    .copyWith(
                                      color: Colors.white,
                                    ),
                              )
                            : Text(
                                'Offline',
                                key: ValueKey('offline'),
                                style: Theme.of(context).textTheme.caption,
                              ),
                      ),
                    ],
                  ),
                  onTap: () => Navigator.pushNamed(
                    context,
                    'chat',
                    arguments: doc.data,
                  ),
                );
              }).toList();
            } else {
              return Center(child: CircularProgressIndicator());
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 15),
              separatorBuilder: (cxt, index) => const SizedBox(height: 10),
              itemBuilder: (cxt, index) => listViewItems[index],
              itemCount: listViewItems.length,
            );
          },
        ),
      ),
    );
  }
}

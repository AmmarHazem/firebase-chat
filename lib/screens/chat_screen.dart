import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageFieldController = TextEditingController();
  final _fireStore = Firestore.instance;
  var _typing = false;
  FirebaseUser _currentUser;
  Map<String, dynamic> _otherUser;
  String _conversationId;

  @override
  initState() {
    super.initState();

    _messageFieldController.addListener(_setTyping);
    Future.delayed(Duration.zero, () async {
      _otherUser = ModalRoute.of(context).settings.arguments ?? {};
      _currentUser = await FirebaseAuth.instance.currentUser();
      _getConversation();
    });
  }

  void _setTyping() async {
    final typing = _messageFieldController.text.isNotEmpty;
    if (typing == _typing) return;
    _typing = typing;
    _fireStore
        .collection('conversations')
        .document(_conversationId)
        .updateData({
      '${_currentUser.uid}_typing': _messageFieldController.text.isNotEmpty,
    });
  }

  Future<void> _getConversation() async {
    final data = await _fireStore.collection('conversations').where(
      'users',
      arrayContainsAny: [_currentUser.email, _otherUser['email']],
    ).getDocuments();
    var foundConversation = false;
    if (data.documents != null && data.documents.isNotEmpty) {
      data.documents.forEach((doc) {
        List<String> userIds = <String>[...doc.data['users']];
        if (userIds.contains(_currentUser.email) &&
            userIds.contains(_otherUser['email'])) {
          _conversationId = doc.documentID;
          foundConversation = true;
        }
      });
    }
    if (!foundConversation) {
      final docRef = await _fireStore.collection('conversations').add({
        'users': [_currentUser.email, _otherUser['email']],
        'created_at': DateTime.now().toIso8601String(),
        '${_currentUser.uid}_typing': false,
        '${_otherUser['id']}_typing': false,
      });
      _conversationId = docRef.documentID;
    }
    setState(() {});
  }

  Future<void> _sendMessage() async {
    if (_messageFieldController.text.isEmpty) return;
    _fireStore.collection('messages').add({
      'conversationId': _conversationId,
      'text': _messageFieldController.text,
      'email': _currentUser.email,
      'created_at': DateTime.now().toIso8601String(),
    });
    _messageFieldController.text = '';
  }

  Widget _streamBuilder(context, AsyncSnapshot<QuerySnapshot> snapshot) {
    Widget child;
    if (snapshot.hasData && snapshot.data.documents.isNotEmpty) {
      final messages = snapshot.data.documents;
      final List<Widget> listViewItems = messages.reversed.map<Widget>((doc) {
        final email = doc.data['email'];
        return Message(
          email: email ?? '',
          isSent: (email ?? '') == _currentUser.email,
          text: doc.data['text'] ?? '',
        );
      }).toList();
      child = ListView.separated(
        reverse: true,
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),
        separatorBuilder: (cxt, index) => const SizedBox(height: 15),
        itemBuilder: (context, index) => listViewItems[index],
        itemCount: listViewItems.length,
      );
    } else if (snapshot.hasData && snapshot.data.documents.isEmpty) {
      child = Center(
        child: Text('No previous messages.'),
      );
    } else {
      child = CircularProgressIndicator();
    }
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 200),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map args = ModalRoute.of(context).settings.arguments ?? {};
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder(
            stream: _otherUser == null
                ? null
                : _fireStore
                    .collection('users')
                    .where('id', isEqualTo: _otherUser['id'])
                    .snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              Map data = {};
              if (snapshot.hasData) {
                data = snapshot.data.documents[0].data;
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(args['email']),
                  AnimatedSwitcher(
                    transitionBuilder: (child, animation) {
                      final positionAnimation = Tween<Offset>(
                        begin: Offset(0, 2),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        curve: Curves.easeInCubic,
                        parent: animation,
                      ));
                      return SlideTransition(
                        position: positionAnimation,
                        child: child,
                      );
                    },
                    duration: Duration(milliseconds: 400),
                    child: (data['online'] ?? false)
                        ? Row(
                            children: <Widget>[
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Online',
                                style: Theme.of(context).textTheme.caption,
                              ),
                            ],
                          )
                        : const SizedBox(),
                  ),
                ],
              );
            }),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 200),
                child: _conversationId == null
                    ? Center(child: CircularProgressIndicator())
                    : StreamBuilder(
                        stream: _fireStore
                            .collection('messages')
                            .where(
                              'conversationId',
                              isEqualTo: _conversationId,
                            )
                            .orderBy('created_at')
                            .snapshots(),
                        builder: _streamBuilder,
                      ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 15),
              height: 20,
              child: StreamBuilder(
                stream: _conversationId != null
                    ? _fireStore
                        .collection('conversations')
                        .document(_conversationId)
                        .snapshots()
                    : null,
                builder: (cxt, AsyncSnapshot<DocumentSnapshot> snapshot) {
                  if (snapshot.hasData) {
                    if (snapshot.data.data['${_otherUser['id']}_typing'] ??
                        false) {
                      return Row(
                        children: <Widget>[
                          Text(
                            '${_otherUser['email']} is typing...',
                            style: Theme.of(context).textTheme.caption,
                          ),
                        ],
                      );
                    }
                  }
                  return const SizedBox();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 10,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _messageFieldController,
                      decoration: InputDecoration(border: OutlineInputBorder()),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Message extends StatelessWidget {
  final String text;
  final String email;
  final bool isSent;

  const Message({
    Key key,
    @required this.text,
    @required this.isSent,
    @required this.email,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (cxt, constraints) {
        return Row(
          mainAxisAlignment:
              isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: <Widget>[
            Column(
              crossAxisAlignment:
                  isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                      bottomLeft:
                          !isSent ? Radius.circular(0) : Radius.circular(15),
                      bottomRight:
                          isSent ? Radius.circular(0) : Radius.circular(15),
                    ),
                    color: isSent
                        ? Theme.of(context).accentColor
                        : Theme.of(context).primaryColor,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 8,
                  ),
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(maxWidth: constraints.maxWidth * 0.6),
                    child: Text(
                      text,
                      style: TextStyle(
                        color: isSent ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ),
                Text(email),
              ],
            ),
          ],
        );
      },
    );
  }
}

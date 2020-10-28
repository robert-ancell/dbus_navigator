import 'package:flutter/material.dart';
import 'package:dbus/dbus.dart';

void main() {
  runApp(DbusNavigator());
}

class DbusNavigator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'D-Bus Navigator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BusView(DBusClient.system()),
    );
  }
}

class BusView extends StatefulWidget {
  final DBusClient client;

  BusView(this.client);

  @override
  _BusViewState createState() => _BusViewState(client.listNames());
}

class _BusViewState extends State<BusView> {
  String _selectedName;
  Future<List<String>> names;

  _BusViewState(this.names);

  set selectedName(String value) {
    setState(() {
      _selectedName = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Row(
      children: <Widget>[
        BusNameList(names, nameSelected: (name) {
          selectedName = name;
        }),
        BusObjectBrowser(widget.client, _selectedName),
      ],
    ));
  }
}

class BusNameList extends StatelessWidget {
  final Future<List<String>> names;
  final void Function(String) nameSelected;

  const BusNameList(this.names, {this.nameSelected, Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
        future: names,
        builder: (context, snapshot) {
          var children = <Widget>[];
          if (snapshot.hasData) {
            var names = snapshot.data;
            names.sort();
            for (var name in names) {
              if (name.startsWith(':')) {
                continue;
              }
              children.add(FlatButton(
                onPressed: () {
                  nameSelected(name);
                },
                child: Text(name),
              ));
            }
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: children);
        });
  }
}

Future<List<String>> _introspectObjects(
    DBusClient client, String name, DBusObjectPath path) async {
  var names = <String>[];

  var node = await DBusRemoteObject(client, name, path).introspect();
  for (var child in node.children) {
    var newPath = path.value;
    if (newPath != '/') {
      newPath += '/';
    }
    newPath += child.name;
    var childNames =
        await _introspectObjects(client, name, DBusObjectPath(newPath));
    names.addAll(childNames);
  }

  if (node.interfaces.isNotEmpty) {
    names.add(path.value);
  }

  return names;
}

class BusObjectBrowser extends StatelessWidget {
  final DBusClient client;
  final String name;

  BusObjectBrowser(this.client, this.name, {Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
        future: _introspectObjects(client, name, DBusObjectPath('/')),
        builder: (context, snapshot) {
          var children = <Widget>[];
          if (snapshot.hasData) {
            var names = snapshot.data;
            names.sort();
            children.addAll(names.map((name) => Text(name)));
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: children);
        });
  }
}

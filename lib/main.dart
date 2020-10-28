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

bool isStandardInterface(String name) {
  return name == 'org.freedesktop.DBus.Introspectable' ||
      name == 'org.freedesktop.DBus.ObjectManager' ||
      name == 'org.freedesktop.DBus.Peer' ||
      name == 'org.freedesktop.DBus.Properties';
}

Future<Map<String, List<DBusIntrospectInterface>>> _introspectObjects(
    DBusClient client, String name, DBusObjectPath path) async {
  var names = <String, List<DBusIntrospectInterface>>{};

  var node = await DBusRemoteObject(client, name, path).introspect();
  for (var child in node.children) {
    var newPath = path.value;
    if (newPath != '/') {
      newPath += '/';
    }
    newPath += child.name;
    var children =
        await _introspectObjects(client, name, DBusObjectPath(newPath));
    names.addAll(children);
  }

  if (node.interfaces.where((i) => !isStandardInterface(i.name)).isNotEmpty) {
    names[path.value] = node.interfaces;
  }

  return names;
}

class BusObjectBrowser extends StatelessWidget {
  final DBusClient client;
  final String name;

  BusObjectBrowser(this.client, this.name, {Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, List<DBusIntrospectInterface>>>(
        future: _introspectObjects(client, name, DBusObjectPath('/')),
        builder: (context, snapshot) {
          var children = <Widget>[];
          if (snapshot.hasData) {
            var objects = snapshot.data;
            var names = objects.keys.toList();
            names.sort();
            for (var name in names) {
              children.add(BusObjectView(name, objects[name]));
            }
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: children);
        });
  }
}

class BusObjectView extends StatelessWidget {
  final String name;
  final List<DBusIntrospectInterface> interfaces;

  BusObjectView(this.name, this.interfaces);

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(name),
          Padding(
            padding: EdgeInsets.only(left: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: interfaces
                  .where((i) => !isStandardInterface(i.name))
                  .map((interface) => BusInterfaceView(interface))
                  .toList(),
            ),
          ),
        ]);
  }
}

class BusInterfaceView extends StatelessWidget {
  final DBusIntrospectInterface interface;

  BusInterfaceView(this.interface);

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(interface.name),
          Padding(
            padding: EdgeInsets.only(left: 20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: interface.properties
                        .map((property) => BusPropertyView(property))
                        .toList(),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: interface.methods
                        .map((method) => BusMethodView(method))
                        .toList(),
                  ),
                ]),
          ),
        ]);
  }
}

class BusPropertyView extends StatelessWidget {
  final DBusIntrospectProperty property;

  BusPropertyView(this.property);

  @override
  Widget build(BuildContext context) {
    return Text(property.name);
  }
}

class BusMethodView extends StatelessWidget {
  final DBusIntrospectMethod method;

  BusMethodView(this.method);

  @override
  Widget build(BuildContext context) {
    return Text('${method.name}()');
  }
}

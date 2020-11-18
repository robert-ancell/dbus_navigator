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
        home:
            Scaffold(body: BusView(DBusClient.system(), DBusClient.session())));
  }
}

class BusView extends StatefulWidget {
  final DBusClient systemClient;
  final DBusClient sessionClient;

  BusView(this.systemClient, this.sessionClient);

  @override
  _BusViewState createState() => _BusViewState(systemClient, sessionClient);
}

class _BusViewState extends State<BusView> {
  final DBusClient systemClient;
  final DBusClient sessionClient;
  Future<List<String>> systemNames;
  Future<List<String>> sessionNames;
  DBusClient selectedClient;
  String selectedName;

  _BusViewState(this.systemClient, this.sessionClient) {
    systemNames = systemClient.listNames();
    sessionNames = sessionClient.listNames();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Flexible(
          child: ListView(
            children: <Widget>[
              Text('System Bus', style: Theme.of(context).textTheme.headline5),
              BusNameList(systemNames, nameSelected: (name) {
                setState(() {
                  selectedClient = systemClient;
                  selectedName = name;
                });
              }),
              Text('Session Bus', style: Theme.of(context).textTheme.headline5),
              BusNameList(sessionNames, nameSelected: (name) {
                setState(() {
                  selectedClient = sessionClient;
                  selectedName = name;
                });
              }),
            ],
          ),
        ),
        Expanded(
          child: ListView(children: <Widget>[
            BusObjectBrowser(selectedClient, selectedName),
          ]),
        ),
      ],
    );
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

Future<Map<DBusObjectPath, List<DBusIntrospectInterface>>> _introspectObjects(
    DBusClient client, String name, DBusObjectPath path) async {
  var paths = <DBusObjectPath, List<DBusIntrospectInterface>>{};

  var node = await DBusRemoteObject(client, name, path).introspect();
  for (var child in node.children) {
    var newPath = path.value;
    if (newPath != '/') {
      newPath += '/';
    }
    newPath += child.name;
    var children =
        await _introspectObjects(client, name, DBusObjectPath(newPath));
    paths.addAll(children);
  }

  if (node.interfaces.where((i) => !isStandardInterface(i.name)).isNotEmpty) {
    paths[path] = node.interfaces;
  }

  return paths;
}

class BusObjectBrowser extends StatelessWidget {
  final DBusClient client;
  final String name;

  BusObjectBrowser(this.client, this.name, {Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<DBusObjectPath, List<DBusIntrospectInterface>>>(
        future: _introspectObjects(client, name, DBusObjectPath('/')),
        builder: (context, snapshot) {
          var children = <Widget>[];
          if (snapshot.hasData) {
            var objects = snapshot.data;
            var paths = objects.keys.toList();
            paths.sort((a, b) => a.value.compareTo(b.value));
            for (var path in paths) {
              children.add(BusObjectView(client, name, path, objects[path]));
            }
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: children);
        });
  }
}

class BusObjectView extends StatelessWidget {
  final DBusClient client;
  final String name;
  final DBusObjectPath path;
  final List<DBusIntrospectInterface> interfaces;

  BusObjectView(this.client, this.name, this.path, this.interfaces);

  @override
  Widget build(BuildContext context) {
    var object = DBusRemoteObject(client, name, path);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(path.value),
          Padding(
            padding: EdgeInsets.only(left: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: interfaces
                  .where((i) => !isStandardInterface(i.name))
                  .map((interface) => BusInterfaceView(object, interface))
                  .toList(),
            ),
          ),
        ]);
  }
}

class BusInterfaceView extends StatefulWidget {
  final DBusRemoteObject object;
  final DBusIntrospectInterface interface;

  BusInterfaceView(this.object, this.interface);

  @override
  _BusInterfaceViewState createState() =>
      _BusInterfaceViewState(object, interface);
}

class _BusInterfaceViewState extends State<BusInterfaceView> {
  final DBusRemoteObject object;
  final DBusIntrospectInterface interface;
  final properties = <String, DBusValue>{};

  _BusInterfaceViewState(this.object, this.interface) {
    _readAllProperties();
  }

  void _readAllProperties() {
    object
        .getAllProperties(interface.name)
        .then((properties) => _updateProperties(properties));
  }

  void _readProperty(String name) {
    object
        .getProperty(interface.name, name)
        .then((value) => _updateProperties(<String, DBusValue>{name: value}));
  }

  void _updateProperties(Map<String, DBusValue> newProperties) {
    setState(() => {properties.addAll(newProperties)});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(widget.interface.name),
          Padding(
            padding: EdgeInsets.only(left: 20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.interface.properties
                        .map((property) => BusPropertyView(
                            property, properties[property.name],
                            readClicked: () => _readProperty(property.name),
                            writeClicked: () => print('write')))
                        .toList(),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.interface.methods
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
  final DBusValue value;
  final void Function() readClicked;
  final void Function() writeClicked;

  BusPropertyView(this.property, this.value,
      {this.readClicked, this.writeClicked});

  @override
  Widget build(BuildContext context) {
    String label;
    if (value != null) {
      label = '${property.name} = ${value.toNative()}';
    } else {
      label = property.name;
    }
    var children = <Widget>[Expanded(child: Text(label))];
    if (property.access != DBusPropertyAccess.read) {
      children.add(FlatButton(
        onPressed: () => writeClicked(),
        child: Icon(Icons.edit),
      ));
    }
    if (property.access != DBusPropertyAccess.write) {
      children.add(FlatButton(
        onPressed: () => readClicked(),
        child: Icon(Icons.refresh),
      ));
    }
    return Row(
      children: children,
    );
  }
}

class BusMethodView extends StatelessWidget {
  final DBusIntrospectMethod method;

  BusMethodView(this.method);

  @override
  Widget build(BuildContext context) {
    var inputArgs = <String>[];
    var outputArgs = <String>[];
    var index = 0;
    for (var arg in method.args) {
      var argName = arg.name;
      argName ??= 'arg_$index';
      if (arg.direction == DBusArgumentDirection.in_) {
        inputArgs.add(argName);
      } else {
        outputArgs.add(argName);
      }
      index++;
    }
    var text = '${method.name}(${inputArgs.join(', ')})';
    if (outputArgs.isNotEmpty) {
      text += ' → ${outputArgs.join(', ')}';
    }
    return Text(text);
  }
}

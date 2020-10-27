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

  const BusView(this.client);

  @override
  _BusViewState createState() => _BusViewState();
}

class _BusViewState extends State<BusView> {
  String _selectedName;

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
        // FIXME: We don't want to regenerate this every time a name is selected
        BusNameList(widget.client, nameSelected: (name) {
          selectedName = name;
        }),
        BusObjectBrowser(widget.client, _selectedName),
      ],
    ));
  }
}

class BusNameList extends StatelessWidget {
  final DBusClient client;
  final void Function(String) nameSelected;

  const BusNameList(this.client, {this.nameSelected, Key key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
        future: client.listNames(),
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

class BusObjectBrowser extends StatelessWidget {
  final DBusClient client;
  final String name;

  BusObjectBrowser(this.client, this.name, {Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text('$name');
  }
}

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

class BusView extends StatelessWidget {
  final DBusClient client;

  const BusView(this.client);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Row(
      children: <Widget>[
        BusNameList(client, nameSelected: (name) {
          print(name);
        }),
        Text('FIXME'),
      ],
    ));
  }
}

class BusNameList extends StatelessWidget {
  final DBusClient client;
  final void Function(String) nameSelected;

  const BusNameList(this.client, {this.nameSelected});

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

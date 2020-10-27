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
      home: MyHomePage(title: 'D-Bus Navigator'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final systemClient = DBusClient.system();

  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: FutureBuilder<List<String>>(
            future: widget.systemClient.listNames(),
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
                      onPressed: () {},
                      child: Align(
                          alignment: Alignment.centerLeft, child: Text(name))));
                }
              }
              return Column(children: children);
            }));
  }
}

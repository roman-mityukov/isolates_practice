import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: Padding(
        padding: EdgeInsets.all(32),
        child: MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  final int number = 40;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        FlatButton(
          color: Colors.white,
          child: Text('Start in event queue'),
          onPressed: () async {
            print(fibonacchi(number));
          },
        ),
        FlatButton(
          color: Colors.white,
          child: Text('Start in compute'),
          onPressed: () async {
            final result = await compute(computeFibonacchi, number);
            print(result);
          },
        ),
        FlatButton(
          color: Colors.white,
          child: Text('Start in isolate'),
          onPressed: () async {
            final result = await compute(computeFibonacchi, number);
            print(result);
          },
        ),
        FlatButton(
          color: Colors.white,
          child: Text('Kill isolate'),
          onPressed: () {},
        )
      ],
    );
  }
}

int kill() {}

int computeFibonacchi(int value) {
  return fibonacchi(value);
}

int fibonacchi(int n) {
  if (n == 0) return 0;

  if (n == 1) return 1;
  return fibonacchi(n - 2) + fibonacchi(n - 1);
}

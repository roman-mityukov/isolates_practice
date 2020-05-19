import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:worker_manager/worker_manager.dart';

void main() async {
  // Executor создает n изолятов, где n - количество ядер процессора.
  // Внутри содержит очередь задач, у которых может быть приоритет. Метод
  // execute возвращает Cancelable. Если отменяется задача, которая еще не
  // исполняется каким-то изолятом, то она просто убирается из очереди. Если
  // выполняется изолятом, то изолят убивается и создается заново.
  await Executor().warmUp();
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
            final result = fibonacchi(number);
            print(result);
          },
        ),
        FlatButton(
          color: Colors.white,
          child: Text('Start in compute'),
          onPressed: () async {
            final result = await compute(fibonacchi, number);
            print(result);
          },
        ),
        FlatButton(
          color: Colors.white,
          child: Text('Start in executor'),
          onPressed: () async {
            final result = await Executor().execute(arg1: 40, fun1: fibonacchi);
            print(result);
          },
        )
      ],
    );
  }
}

int fibonacchi(int n) {
  if (n == 0) return 0;
  if (n == 1) return 1;
  return fibonacchi(n - 2) + fibonacchi(n - 1);
}

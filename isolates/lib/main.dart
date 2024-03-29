import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:isolates/worker_isolate.dart';
import 'package:worker_manager/worker_manager.dart' as WorkerManager;

void main() async {
  // Executor создает n изолятов, где n - количество ядер процессора. Это может
  // быть неприемлимо по потреблению памяти - процесс с одним изолятом
  // условно занимает 50 мб, с 8 изолятами - 250 мб
  // Внутри содержит очередь задач, у которых может быть приоритет. Метод
  // execute возвращает Cancelable. Если отменяется задача, которая еще не
  // исполняется каким-то изолятом, то она просто убирается из очереди. Если
  // выполняется изолятом, то изолят убивается и создается заново.
  await WorkerManager.Executor().warmUp();
  runApp(
    MaterialApp(
      title: 'Flutter Demo',
      home: MyHomePage(),
    ),
  );
}

class MyHomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _StateMyHomePage();
  }
}

class _StateMyHomePage extends State<MyHomePage> {
  final int number = 40;
  WorkerIsolate _workerIsolate;
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Column(
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
              _showResult(result);
            },
          ),
          FlatButton(
            color: Colors.white,
            child: Text('Start in compute'),
            onPressed: () async {
              final result = await compute(fibonacchi, number);
              _showResult(result);
            },
          ),
          FlatButton(
            color: Colors.white,
            child: Text('Start in executor'),
            onPressed: () async {
              final result = await WorkerManager.Executor()
                  .execute(arg1: 40, fun1: fibonacchi);
              _showResult(result);
            },
          ),
          FlatButton(
            color: Colors.white,
            child: Text('Start in isolate'),
            onPressed: () async {
              try {
                if (_workerIsolate == null) {
                  _workerIsolate = WorkerIsolate();
                  await _workerIsolate.init();
                }

                final result =
                    await _workerIsolate.execute(Task(fibonacchi, 40));
                _showResult(result);
                _workerIsolate?.kill();
              } on IllegalStateException catch (_) {
                _scaffoldKey.currentState?.showSnackBar(
                  SnackBar(
                    content: Text(
                      'IllegalStateException',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          FlatButton(
            color: Colors.white,
            child: Text('Kill isolate'),
            onPressed: () async {
              _workerIsolate?.kill();
              _workerIsolate = null;
            },
          )
        ],
      ),
    );
  }

  void _showResult(Object result) {
    _scaffoldKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(result?.toString() ?? 'null'),
      ),
    );
  }
}

int fibonacchi(int n) {
  if (n == 0) return 0;
  if (n == 1) return 1;
  return fibonacchi(n - 2) + fibonacchi(n - 1);
}

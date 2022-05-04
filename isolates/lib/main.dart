import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isolates/worker_isolate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:worker_manager/worker_manager.dart' as WorkerManager;

late String path;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final string = await rootBundle.loadString('assets/data.json');
  path = (await getApplicationDocumentsDirectory()).path;
  final file = File('$path/data.json');
  file.writeAsStringSync(string);

  // Executor создает n изолятов, где n - количество ядер процессора. Это может
  // быть неприемлимо по потреблению памяти - процесс с одним изолятом
  // условно занимает 50 мб, с 8 изолятами - 400 мб
  // Внутри содержит очередь задач, у которых может быть приоритет. Метод
  // execute возвращает Cancelable. Если отменяется задача, которая еще не
  // исполняется каким-то изолятом, то она просто убирается из очереди. Если
  // выполняется изолятом, то изолят убивается и создается заново.
  //await WorkerManager.Executor().warmUp();
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
  WorkerIsolate? _workerIsolate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              ElevatedButton(
                child: Text('Start in main isolate event queue'),
                onPressed: () async {
                  final result = decodeJson(path);
                  _showComplete();
                },
              ),
              ElevatedButton(
                child: Text('Start in compute'),
                onPressed: () async {
                  final result = await compute(decodeJson, path);
                  _showComplete();
                },
              ),
              ElevatedButton(
                child: Text('Start in worker_manager'),
                onPressed: () async {
                  final result = await WorkerManager.Executor()
                      .execute(arg1: path, fun1: decodeJson);
                  _showComplete();
                },
              ),
              ElevatedButton(
                child: Text('Start in isolate'),
                onPressed: () async {
                  try {
                    if (_workerIsolate == null) {
                      _workerIsolate = WorkerIsolate.create();
                      await _workerIsolate?.init();
                    }

                    final result =
                        await _workerIsolate!.execute(Task(decodeJson, path));
                    _showComplete();
                    _workerIsolate?.kill();
                  } on IllegalStateException catch (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
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
              ElevatedButton(
                child: Text('Kill isolate'),
                onPressed: () async {
                  _workerIsolate?.kill();
                  _workerIsolate = null;
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showComplete() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Complete'),
      ),
    );
  }
}

dynamic decodeJson(String path) async {
  final file = File('$path/data.json');
  final string = file.readAsStringSync();
  final json = jsonDecode(string);

  return json;
}

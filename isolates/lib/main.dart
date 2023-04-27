import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isolates/worker_isolate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:worker_manager/worker_manager.dart' as WorkerManager;

late String path;

// Что нужно учесть при использовании изолятов для фоновой работы в приложении
// - Изоляты не поддерживаются на вебе
// - Зависимости нельзя передавать в другой изолят (сложные объекты нельзя передать через SendPort https://api.dart.dev/stable/2.19.6/dart-isolate/SendPort/send.html), каждый изолят должен внутри себя создать зависимости (ведет к перерасходу памяти из-за дублирующихся объектов). Например нельзя передать в другой изолят http-клиент, он должен быть создан и настроен в каждом изоляте
// - Sqflite не работает в дочерних изолятах https://github.com/tekartik/sqflite/blob/master/sqflite/doc/usage_recommendations.md#isolates
// - В изоляты лучше перемещать задачи, которые не требуют много контекста и зависимостей. В нашем случае это 
// 	+ маппинги строк http ответов в объекты. Можно просто использовать dio.transformer, в котором можно парсить json в отдельном изоляте
//	+ ???
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

// Если dart 2.15 и выше, то передача результата из одного изолята в другой
// происходит через shared memory и UI не тормозит из-за сериализации объекта.
// Но тут нужно еще смотреть на объем данных и вызовы GC - UI может тормозить
// из-за уборки больших объемов GC не в UI изоляте https://github.com/dart-lang/sdk/issues/46754.
// Размеры памяти https://groups.google.com/a/dartlang.org/g/announce/c/1xlv22W7fRI
dynamic decodeJson(String path) async {
  final file = File('$path/data.json');
  final string = file.readAsStringSync();
  final json = jsonDecode(string);

  return json;
}

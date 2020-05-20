import 'dart:async';
import 'dart:isolate';

import 'package:async/async.dart';

abstract class WorkerIsolate {
  factory WorkerIsolate() => _WorkerIsolate();

  Future<void> init();

  Future<Object> execute(Task task);

  void kill();
}

class _WorkerIsolate implements WorkerIsolate {
  // Изолят-потомок, который будет создан при инициализации объекта
  // _WorkerIsolate и который будет использоваться для выполнения работы
  Isolate _isolate;

  // Порт, который будет использоваться для отправки сообщений изоляту-потомку
  SendPort _childSendPort;

  // Подписка на ReceivePort(такие порты реализуют Stream) изолята-родителя. В
  // этот порт будут приходить сообщения из изолята-потомка
  StreamSubscription<Object> _isolateSubscription;

  Completer<Object> _result;

  Future<void> init() async {
    if (_result != null && !_result.isCompleted) {
      throw IllegalStateException();
    }

    final initCompleter = Completer();
    final parentReceivePort = ReceivePort();
    _isolate = await Isolate.spawn(_createIsolate, parentReceivePort.sendPort);
    _isolateSubscription = parentReceivePort.listen(
      (message) {
        if (message is SendPort) {
          _childSendPort = message;
          initCompleter.complete();
        } else if (message is ValueResult) {
          _result.complete(message.value);
        } else if (message is ErrorResult) {
          _result.completeError(message.error);
        } else {
          throw IllegalStateException();
        }
      },
    );

    return initCompleter.future;
  }

  Future<Object> execute(Task task) {
    if (_childSendPort == null || _isolateSubscription == null) {
      throw IllegalStateException();
    }

    if (_result != null && !_result.isCompleted) {
      throw IllegalStateException();
    }

    _result = Completer();
    _childSendPort.send(task);
    return _result.future;
  }

  void kill() {
    _isolateSubscription?.cancel();
    _childSendPort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }

  static void _createIsolate(SendPort parentSendPort) {
    final childReceivePort = ReceivePort();
    parentSendPort.send(childReceivePort.sendPort);

    childReceivePort.listen(
      (message) async {
        if (message is Task) {
          try {
            final result = await message.function(message.argument);
            parentSendPort.send(Result.value(result));
          } on dynamic catch (error) {
            try {
              parentSendPort.send(Result.error(error));
            } catch (error) {
              parentSendPort.send(Result.error(
                  'cant send error with too big stackTrace, error is : ${error.toString()}'));
            }
          }
        }
      },
    );
  }
}

class IllegalStateException implements Exception {}

class Task {
  final Function function;
  final Object argument;

  Task(this.function, this.argument);
}

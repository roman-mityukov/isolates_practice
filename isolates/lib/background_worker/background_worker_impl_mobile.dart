import 'dart:async';
import 'dart:isolate';

import 'package:app_builder_mobile/services/background_worker/background_worker.dart';
import 'package:async/async.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

class IsolateSettings {
  final RootIsolateToken rootIsolateToken;
  final SendPort port;

  IsolateSettings(this.rootIsolateToken, this.port);
}

class BackgroundWorkerImpl implements BackgroundWorker {
  static void _createIsolate(IsolateSettings settings) {
    BackgroundIsolateBinaryMessenger.ensureInitialized(
      settings.rootIsolateToken,
    );
    final childReceivePort = ReceivePort();
    settings.port.send(childReceivePort.sendPort);

    void sendResult(String id, Object? result) {
      settings.port.send(Result.value(TaskResponseWithResult(id, result)));
    }

    void sendError(String id, Object error, StackTrace stackTrace) {
      settings.port.send(
        Result.error(TaskResponseWithError(id, error, stackTrace)),
      );
    }

    childReceivePort.listen(
      (message) async {
        if (message is TaskRequest) {
          try {
            final result = message.task.argument != null
                ? message.task.computation(message.task.argument)
                : message.task.computation();

            if (result is Future) {
              result.then(
                (value) {
                  sendResult(message.id, value);
                },
              ).catchError(
                (error, stackTrace) {
                  sendError(message.id, error, stackTrace);
                },
              );
            } else {
              sendResult(message.id, result);
            }
          } catch (error, stackTrace) {
            sendError(message.id, error, stackTrace);
          }
        }
      },
    );
  }

  final _completers = <String, Completer>{};
  final _parentReceivePort = ReceivePort();
  late SendPort _childSendPort;

  @override
  Future<T> execute<T>(Task request) {
    final task = TaskRequest(const Uuid().v1(), request);
    final completer = Completer<T>();
    _completers[task.id] = completer;
    _childSendPort.send(task);
    return completer.future;
  }

  Future<void> init() async {
    final initCompleter = Completer();
    await Isolate.spawn(
      _createIsolate,
      IsolateSettings(RootIsolateToken.instance!, _parentReceivePort.sendPort),
    );

    _parentReceivePort.listen(
      (message) {
        if (message is SendPort) {
          _childSendPort = message;
          initCompleter.complete();
        } else if (message is ValueResult) {
          final taskResult = message.value as TaskResponseWithResult;
          final completer = _completers[taskResult.id]!;
          completer.complete(taskResult.result);
          _completers.remove(taskResult.id);
        } else if (message is ErrorResult) {
          final taskError = message.error as TaskResponseWithError;
          final completer = _completers[taskError.id]!;
          completer.completeError(taskError.error, taskError.stackTrace);
          _completers.remove(taskError.id);
        } else {
          throw UnimplementedError();
        }
      },
    );

    return initCompleter.future;
  }
}

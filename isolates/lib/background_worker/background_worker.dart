import 'dart:async';

import 'package:app_builder_mobile/services/background_worker/background_worker_impl.dart';

abstract class BackgroundWorker {
  Future<T> execute<T>(Task task);
}

class BackgroundWorkerProvider {
  static BackgroundWorkerImpl? _instance;

  static Future<BackgroundWorker> create() async {
    if (_instance == null) {
      _instance = BackgroundWorkerImpl();
      await _instance!.init();
    }

    return _instance!;
  }
}

class Task {
  final Function computation;
  final Object? argument;

  Task({required this.computation, this.argument});
}

class TaskResponseWithError {
  final String id;
  final Object error;
  final StackTrace stackTrace;

  TaskResponseWithError(this.id, this.error, this.stackTrace);
}

class TaskResponseWithResult {
  final String id;
  final Object? result;

  TaskResponseWithResult(this.id, this.result);
}

class TaskRequest {
  final String id;
  final Task task;

  const TaskRequest(this.id, this.task);
}

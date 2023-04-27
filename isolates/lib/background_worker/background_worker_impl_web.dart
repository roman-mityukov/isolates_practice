import 'package:app_builder_mobile/services/background_worker/background_worker.dart';

class BackgroundWorkerImpl implements BackgroundWorker {
  @override
  Future<T> execute<T>(Task request) async {
    return request.argument != null
        ? request.computation(request.argument)
        : request.computation();
  }

  Future<void> init() async {}
}

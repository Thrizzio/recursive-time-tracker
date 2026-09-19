import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/networking/api_client.dart';
import 'package:app/features/activities/data/activities_repository.dart';

class MockActivitiesHttpClientAdapter implements HttpClientAdapter {
  MockActivitiesHttpClientAdapter({required this.handler});

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('ActivitiesRepository', () {
    test('getActivities calls GET /activities and parses list', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockActivitiesHttpClientAdapter(
        handler: (options) async {
          expect(options.path, '/activities');
          expect(options.method, 'GET');
          return ResponseBody.fromString(
            '[{"id":1,"name":"Coding","color":"#38bdf8"},{"id":2,"name":"Reading","color":"#34d399"}]',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );

      final apiClient = ApiClient(
        cookieJar: CookieJar(),
        customDio: dio,
      );
      final repo = ActivitiesRepository(apiClient: apiClient);
      final activities = await repo.getActivities();

      expect(activities.length, 2);
      expect(activities[0].id, 1);
      expect(activities[0].name, 'Coding');
      expect(activities[0].color, '#38bdf8');
      expect(activities[1].id, 2);
      expect(activities[1].name, 'Reading');
      expect(activities[1].color, '#34d399');
    });

    test('createActivity sends POST /activities with trimmed name and color', () async {
      Map<String, dynamic>? sentBody;
      final dio = Dio();
      dio.httpClientAdapter = MockActivitiesHttpClientAdapter(
        handler: (options) async {
          expect(options.path, '/activities');
          expect(options.method, 'POST');
          sentBody = options.data as Map<String, dynamic>;
          return ResponseBody.fromString(
            '{"id":3,"name":"Design","color":"#a78bfa"}',
            201,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );

      final apiClient = ApiClient(
        cookieJar: CookieJar(),
        customDio: dio,
      );
      final repo = ActivitiesRepository(apiClient: apiClient);
      final created = await repo.createActivity(
        name: '  Design  ',
        color: '  #a78bfa  ',
      );

      expect(sentBody, {'name': 'Design', 'color': '#a78bfa'});
      expect(created.id, 3);
      expect(created.name, 'Design');
      expect(created.color, '#a78bfa');
    });
  });
}

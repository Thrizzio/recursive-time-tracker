import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/networking/api_client.dart';
import 'package:app/features/calendar/data/calendar_repository.dart';
import 'package:app/features/calendar/domain/calendar_event_model.dart';

class MockCalendarHttpClientAdapter implements HttpClientAdapter {
  MockCalendarHttpClientAdapter({required this.handler});

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
  group('CalendarEventModel', () {
    test('parses from JSON correctly', () {
      final json = {
        'id': 'ev_123',
        'title': 'Team Standup',
        'start': '2026-09-19T09:00:00Z',
        'end': '2026-09-19T09:30:00Z',
        'location': 'Google Meet',
        'allDay': false,
      };

      final event = CalendarEventModel.fromJson(json);

      expect(event.id, 'ev_123');
      expect(event.title, 'Team Standup');
      expect(event.start, '2026-09-19T09:00:00Z');
      expect(event.end, '2026-09-19T09:30:00Z');
      expect(event.location, 'Google Meet');
      expect(event.allDay, isFalse);
    });

    test('formattedTimeSpan returns All day for all-day events', () {
      const event = CalendarEventModel(
        id: 'ev_allday',
        title: 'Company Holiday',
        start: '2026-09-19',
        end: '2026-09-19',
        allDay: true,
      );

      expect(event.formattedTimeSpan, 'All day');
    });

    test('formattedTimeSpan formats start and end times cleanly', () {
      const event = CalendarEventModel(
        id: 'ev_1',
        title: 'Sprint Planning',
        start: '2026-09-19T14:00:00Z',
        end: '2026-09-19T15:00:00Z',
      );

      expect(event.formattedTimeSpan.isNotEmpty, isTrue);
      expect(event.formattedTimeSpan, contains('–'));
    });

    test('serializes to JSON correctly', () {
      const event = CalendarEventModel(
        id: 'ev_2',
        title: 'Code Review',
        start: '2026-09-19T10:00:00Z',
        end: '2026-09-19T10:30:00Z',
        location: 'Room 401',
        allDay: false,
      );

      final json = event.toJson();
      expect(json['id'], 'ev_2');
      expect(json['title'], 'Code Review');
      expect(json['location'], 'Room 401');
      expect(json['allDay'], isFalse);
    });
  });

  group('CalendarRepository', () {
    test('getTodayEvents sends GET /google/calendar with start and end query parameters', () async {
      Map<String, dynamic>? queryParams;
      final dio = Dio();
      dio.httpClientAdapter = MockCalendarHttpClientAdapter(
        handler: (options) async {
          expect(options.path, '/google/calendar');
          expect(options.method, 'GET');
          queryParams = options.queryParameters;
          return ResponseBody.fromString(
            '[{"id":"ev_1","title":"Daily Sync","start":"2026-09-19T09:00:00Z","end":"2026-09-19T09:30:00Z","allDay":false}]',
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
      final repo = CalendarRepository(apiClient: apiClient);
      final events = await repo.getTodayEvents(DateTime(2026, 9, 19));

      expect(events.length, 1);
      expect(events[0].id, 'ev_1');
      expect(events[0].title, 'Daily Sync');
      expect(queryParams, isNotNull);
      expect(queryParams!.containsKey('start'), isTrue);
      expect(queryParams!.containsKey('end'), isTrue);
    });
  });
}


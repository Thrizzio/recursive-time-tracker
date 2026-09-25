import 'package:flutter/material.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/networking/api_client.dart';
import 'package:app/features/auth/domain/user_model.dart';
import 'package:app/features/auth/presentation/auth_controller.dart';
import 'package:app/features/auth/presentation/auth_state.dart';
import 'package:app/features/tasks/data/tasks_repository.dart';
import 'package:app/features/tasks/domain/task_list_model.dart';
import 'package:app/features/tasks/domain/task_model.dart';
import 'package:app/features/tasks/presentation/tasks_controller.dart';
import 'package:app/features/tasks/presentation/widgets/tasks_card.dart';

class MockTasksHttpClientAdapter implements HttpClientAdapter {
  MockTasksHttpClientAdapter({required this.handler});

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
  group('TaskModel', () {
    test('parses from JSON correctly', () {
      final json = {
        'id': 'task_123',
        'title': 'Complete Phase 4b',
        'notes': 'Implement Tasks & Calendar',
        'due': '2026-09-20T12:00:00Z',
        'status': 'needsAction',
      };

      final task = TaskModel.fromJson(json);

      expect(task.id, 'task_123');
      expect(task.title, 'Complete Phase 4b');
      expect(task.notes, 'Implement Tasks & Calendar');
      expect(task.due, '2026-09-20T12:00:00Z');
      expect(task.status, 'needsAction');
      expect(task.isCompleted, isFalse);
    });

    test('isCompleted returns true when status is completed', () {
      const task = TaskModel(
        id: '1',
        title: 'Done task',
        status: 'completed',
      );
      expect(task.isCompleted, isTrue);
    });

    test('serializes to JSON correctly', () {
      const task = TaskModel(
        id: 't1',
        title: 'Submit report',
        notes: 'Include test run',
        due: '2026-09-21',
        status: 'needsAction',
      );

      final json = task.toJson();
      expect(json['id'], 't1');
      expect(json['title'], 'Submit report');
      expect(json['notes'], 'Include test run');
      expect(json['due'], '2026-09-21');
      expect(json['status'], 'needsAction');
    });

    test('copyWith works correctly', () {
      const task = TaskModel(id: '1', title: 'Task 1');
      final updated = task.copyWith(title: 'Updated Task 1', status: 'completed');

      expect(updated.id, '1');
      expect(updated.title, 'Updated Task 1');
      expect(updated.status, 'completed');
    });
  });

  group('TaskListModel', () {
    test('parses from JSON correctly', () {
      final json = {'id': 'list_999', 'title': 'Work Tasks'};
      final list = TaskListModel.fromJson(json);

      expect(list.id, 'list_999');
      expect(list.title, 'Work Tasks');
    });

    test('serializes to JSON correctly', () {
      const list = TaskListModel(id: 'l1', title: 'Personal');
      expect(list.toJson(), {'id': 'l1', 'title': 'Personal'});
    });
  });

  group('TasksRepository', () {
    late ApiClient apiClient;

    test('getTaskLists sends GET /tasks/lists and maps response', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockTasksHttpClientAdapter(
        handler: (options) async {
          expect(options.path, '/tasks/lists');
          expect(options.method, 'GET');
          return ResponseBody.fromString(
            '[{"id":"list_1","title":"My Tasks"},{"id":"list_2","title":"Projects"}]',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );

      apiClient = ApiClient(
        cookieJar: CookieJar(),
        customDio: dio,
      );
      final repo = TasksRepository(apiClient: apiClient);
      final lists = await repo.getTaskLists();

      expect(lists.length, 2);
      expect(lists[0].id, 'list_1');
      expect(lists[0].title, 'My Tasks');
      expect(lists[1].id, 'list_2');
      expect(lists[1].title, 'Projects');
    });

    test('getTasks sends GET /tasks and maps response', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockTasksHttpClientAdapter(
        handler: (options) async {
          expect(options.path, '/tasks');
          expect(options.method, 'GET');
          return ResponseBody.fromString(
            '[{"id":"t1","title":"Fix bug","status":"needsAction"}]',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );

      apiClient = ApiClient(
        cookieJar: CookieJar(),
        customDio: dio,
      );
      final repo = TasksRepository(apiClient: apiClient);
      final tasks = await repo.getTasks();

      expect(tasks.length, 1);
      expect(tasks[0].id, 't1');
      expect(tasks[0].title, 'Fix bug');
      expect(tasks[0].isCompleted, isFalse);
    });

    test('completeTasks sends POST /tasks/complete with taskIds', () async {
      String? sentBody;
      final dio = Dio();
      dio.httpClientAdapter = MockTasksHttpClientAdapter(
        handler: (options) async {
          expect(options.path, '/tasks/complete');
          expect(options.method, 'POST');
          sentBody = options.data.toString();
          return ResponseBody.fromString(
            '{"success":true}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );

      apiClient = ApiClient(
        cookieJar: CookieJar(),
        customDio: dio,
      );
      final repo = TasksRepository(apiClient: apiClient);
      await repo.completeTasks(['t1', 't2']);

      expect(sentBody, contains('taskIds'));
      expect(sentBody, contains('t1'));
      expect(sentBody, contains('t2'));
    });

    test('selectTaskList sends POST /settings/task-list with taskListId', () async {
      String? sentBody;
      final dio = Dio();
      dio.httpClientAdapter = MockTasksHttpClientAdapter(
        handler: (options) async {
          expect(options.path, '/settings/task-list');
          expect(options.method, 'POST');
          sentBody = options.data.toString();
          return ResponseBody.fromString(
            '{"success":true}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );

      apiClient = ApiClient(
        cookieJar: CookieJar(),
        customDio: dio,
      );
      final repo = TasksRepository(apiClient: apiClient);
      await repo.selectTaskList('list_chosen');

      expect(sentBody, contains('taskListId'));
      expect(sentBody, contains('list_chosen'));
    });
  });

  group('TasksCard Widget', () {
    testWidgets('renders incomplete tasks without standalone complete checkbox',
        (tester) async {
      const user = UserModel(
        id: 1,
        email: 'test@example.com',
        name: 'Test User',
        selectedTaskListId: 'list_123',
      );

      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _MockAuthNotifier(user)),
          tasksProvider.overrideWith(
            (ref) async => [
              const TaskModel(
                id: 'task_abc',
                title: 'Review PR changes',
                notes: 'Focus on Pomodoro integration',
                due: '2026-10-01T00:00:00.000Z',
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: TasksCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify task details are rendered
      expect(find.text('Review PR changes'), findsOneWidget);
      expect(find.text('Focus on Pomodoro integration'), findsOneWidget);
      expect(find.textContaining('Due: Oct 1'), findsOneWidget);

      // Verify timer icon is available to start focus timer
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);

      // CRITICAL REQUIREMENT 3: No standalone complete checkbox/radio exists on the card
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byTooltip('Mark complete'), findsNothing);
    });
  });
}

class _MockAuthNotifier extends AuthNotifier {
  _MockAuthNotifier(this._user);
  final UserModel _user;

  @override
  AuthState build() => Authenticated(_user);
}


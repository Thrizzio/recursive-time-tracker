# app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Notes on Dependencies

### `path_provider_foundation: 2.3.2` Dependency Override
In `pubspec.yaml`, `path_provider_foundation: 2.3.2` is pinned under `dependency_overrides`.

**Reason**: Dart's experimental Native Assets build hook mechanism (introduced in `path_provider_foundation >= 2.4.0` via `package:objective_c`) fails on Windows when the repository directory path contains spaces (such as `C:\DEV WORK\...`). Overriding to version `2.3.2` bypasses the `objective_c` native asset build hook, ensuring consistent and reproducible Android builds across all host development environments.


/// The only network boundary used by the source engine.
///
/// A concrete implementation will enforce timeouts, request limits and the
/// imported-source allow list. Tests use an in-memory implementation instead.
abstract interface class BookSourceGateway {
  Future<String> get(Uri url);
}

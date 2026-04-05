import 'package:sqlite3/wasm.dart';

WasmSqlite3? _sqlite;

Future<WasmSqlite3> _loadSqlite() async {
  if (_sqlite != null) return _sqlite!;

  // ✅ هذا هو المكان الذي تضع فيه loadFromUrl
  final sqlite = await WasmSqlite3.loadFromUrl(
    Uri.base.resolve('sqlite3.wasm'), // الأفضل عادة
  );

  final fs = await IndexedDbFileSystem.open(dbName: 'my_app');
  sqlite.registerVirtualFileSystem(fs, makeDefault: true);

  _sqlite = sqlite;
  return sqlite;
}

Future<CommonDatabase> openAppDatabase(String fileName) async {
  final sqlite = await _loadSqlite();
  return sqlite.open(fileName);
}

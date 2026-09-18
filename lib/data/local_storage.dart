import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/models.dart';

class LocalStorage {
  LocalStorage(this.root);

  final Directory root;

  static Future<LocalStorage> open() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'businesses'));
    await dir.create(recursive: true);
    return LocalStorage(support);
  }

  Directory businessDir(String businessId) {
    final dir = Directory(p.join(root.path, 'businesses', businessId));
    dir.createSync(recursive: true);
    return dir;
  }

  Directory customerDir(String businessId, String customerId) {
    final dir = Directory(p.join(businessDir(businessId).path, 'customers', customerId));
    dir.createSync(recursive: true);
    return dir;
  }

  Directory folder(String businessId, String customerId, FolderType type) {
    final dir = Directory(p.join(customerDir(businessId, customerId).path, type.name));
    dir.createSync(recursive: true);
    return dir;
  }

  Directory templatesDir(String businessId) {
    final dir = Directory(p.join(businessDir(businessId).path, 'templates'));
    dir.createSync(recursive: true);
    return dir;
  }

  Directory logosDir(String businessId) {
    final dir = Directory(p.join(businessDir(businessId).path, 'logos'));
    dir.createSync(recursive: true);
    return dir;
  }

  String relativeToRoot(File file) => p.relative(file.path, from: root.path);

  File resolve(String relativeOrAbsolute) {
    final asIs = File(relativeOrAbsolute);
    if (asIs.isAbsolute) return asIs;
    return File(p.join(root.path, relativeOrAbsolute));
  }

  Future<File> copyBytes(List<int> bytes, File dest) async {
    await dest.parent.create(recursive: true);
    return dest.writeAsBytes(bytes, flush: true);
  }

  Future<File> copyFile(File source, File dest) async {
    await dest.parent.create(recursive: true);
    return source.copy(dest.path);
  }

  File uniqueFile(Directory dir, String baseName) {
    final safe = baseName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    var candidate = File(p.join(dir.path, safe));
    if (!candidate.existsSync()) return candidate;
    final dot = safe.lastIndexOf('.');
    final stem = dot > 0 ? safe.substring(0, dot) : safe;
    final ext = dot > 0 ? safe.substring(dot) : '';
    var i = 2;
    while (candidate.existsSync()) {
      candidate = File(p.join(dir.path, '${stem}_$i$ext'));
      i++;
    }
    return candidate;
  }
}

String guessMime(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.pdf')) return 'application/pdf';
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  if (n.endsWith('.xls')) return 'application/vnd.ms-excel';
  if (n.endsWith('.csv')) return 'text/csv';
  if (n.endsWith('.txt')) return 'text/plain';
  return 'application/octet-stream';
}

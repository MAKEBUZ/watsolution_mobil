import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/storage_config.dart';

class StorageService {
  final String bucket;
  StorageService({String? bucketName}) : bucket = bucketName ?? kInvoicesBucket;

  StorageFileApi _api() => Supabase.instance.client.storage.from(bucket);

  Future<List<FileObject>> list({String path = ''}) async {
    return await _api().list(path: path);
  }

  String getPublicUrl(String path) {
    return _api().getPublicUrl(path);
  }

  Future<String> createSignedUrl(String path, Duration expires) async {
    return await _api().createSignedUrl(path, expires.inSeconds);
  }

  Future<Uint8List> downloadBytes(String path) async {
    final data = await _api().download(path);
    return data;
  }

  Future<String> uploadBytes(
    String path,
    Uint8List bytes, {
    String? contentType,
    bool upsert = true,
  }) async {
    return await _api().uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: upsert,
      ),
    );
  }

  Future<List<FileObject>> remove(List<String> paths) async {
    return await _api().remove(paths);
  }
}
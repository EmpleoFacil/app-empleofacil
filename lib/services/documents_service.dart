import 'dart:typed_data';

import '../models/document.dart';
import 'api_service.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class DocumentsService {
  final ApiService _api;

  DocumentsService(this._api);

  Future<List<DocumentType>> getDocumentTypes() async {
    final response = await _api.get('/documents/types');
    final list = response as List;
    return list.map((json) => DocumentType.fromJson(json)).toList();
  }

  Future<List<CandidateDocument>> getMyDocuments() async {
    final response = await _api.get('/documents/me');
    final list = response as List;
    return list.map((json) => CandidateDocument.fromJson(json)).toList();
  }

  Future<CandidateDocument> upload({
    required String type,
    required http.MultipartFile file,
    bool replace = true,
  }) async {
    final request = _buildRequest(type: type, replace: replace);
    request.files.add(file);

    final response = await _api.postForm('/documents/upload', request);
    return CandidateDocument.fromJson(response);
  }

  Future<CandidateDocument> uploadBytes({
    required String type,
    required Uint8List bytes,
    required String filename,
    bool replace = true,
  }) async {
    final request = _buildRequest(type: type, replace: replace);
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    final response = await _api.postForm('/documents/upload', request);
    return CandidateDocument.fromJson(response);
  }

  http.MultipartRequest _buildRequest({
    required String type,
    required bool replace,
  }) {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/documents/upload'),
    );
    request.fields['type'] = type;
    request.fields['replace'] = replace.toString();
    return request;
  }
}

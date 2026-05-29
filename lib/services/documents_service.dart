import '../models/document.dart';
import 'api_service.dart';

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
    required String fileUrl,
  }) async {
    final response = await _api.post('/documents/upload', {
      'type': type,
      'fileUrl': fileUrl,
    });
    return CandidateDocument.fromJson(response);
  }
}

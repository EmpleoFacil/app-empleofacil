import '../models/application.dart';
import 'api_service.dart';

class ApplicationsService {
  final ApiService _api;

  ApplicationsService(this._api);

  Future<List<Application>> getMyApplications() async {
    final response = await _api.get('/applications/me');
    final list = response as List;
    return list.map((json) => Application.fromJson(json)).toList();
  }

  Future<ApplicationSummary> getSummary() async {
    final response = await _api.get('/applications/me/summary');
    return ApplicationSummary.fromJson(response);
  }

  Future<Map<String, dynamic>> getStatusSummary() async {
    final response = await _api.get('/applications/me/status-summary');
    return response as Map<String, dynamic>;
  }

  Future<Application> getById(String id) async {
    final response = await _api.get('/applications/$id');
    return Application.fromJson(response);
  }

  Future<Map<String, dynamic>?> getByJobForMe(String jobId) async {
    final response = await _api.get('/applications/job/$jobId/me');
    return response as Map<String, dynamic>?;
  }

  Future<Application> apply(String jobId) async {
    final response = await _api.post('/applications', {'jobId': jobId});
    return Application.fromJson(response);
  }
}

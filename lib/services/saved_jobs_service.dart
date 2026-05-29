import '../models/job.dart';
import 'api_service.dart';

class SavedJobsService {
  final ApiService _api;

  SavedJobsService(this._api);

  Future<List<Job>> getMySavedJobs() async {
    final response = await _api.get('/saved-jobs/me');
    final items = (response as Map<String, dynamic>)['items'] as List;
    return items.map((json) => Job.fromJson(json)).toList();
  }

  Future<void> save(String jobId) async {
    await _api.post('/saved-jobs', {'jobId': jobId});
  }

  Future<void> unsave(String jobId) async {
    await _api.get('/saved-jobs/$jobId'); // DELETE via custom endpoint
  }
}

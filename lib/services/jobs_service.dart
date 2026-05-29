import '../models/job.dart';
import 'api_service.dart';

class JobsService {
  final ApiService _api;

  JobsService(this._api);

  Future<List<JobCategory>> getCategories() async {
    final response = await _api.get('/jobs/categories');
    final list = response as List;
    return list.map((json) => JobCategory.fromJson(json)).toList();
  }

  Future<List<Job>> getRecommended({String? categoryId}) async {
    final endpoint = categoryId != null 
        ? '/jobs/recommended?category=$categoryId' 
        : '/jobs/recommended';
    final response = await _api.get(endpoint);
    final list = response as List;
    return list.map((json) => Job.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> search({
    String? query,
    String? city,
    String? categoryId,
    int page = 1,
  }) async {
    final params = <String, String>{};
    if (query != null && query.isNotEmpty) params['search'] = query;
    if (city != null && city.isNotEmpty) params['city'] = city;
    if (categoryId != null) params['category'] = categoryId;
    params['page'] = page.toString();

    final queryString = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final response = await _api.get('/jobs/search?$queryString');
    return response as Map<String, dynamic>;
  }

  Future<Job> getById(String id) async {
    final response = await _api.get('/jobs/$id');
    return Job.fromJson(response);
  }
}

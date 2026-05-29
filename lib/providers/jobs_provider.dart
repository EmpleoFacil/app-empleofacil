import 'package:flutter/foundation.dart';
import '../models/job.dart';
import '../services/jobs_service.dart';
import '../services/api_service.dart';

class JobsProvider with ChangeNotifier {
  final JobsService _jobsService;
  
  List<JobCategory> _categories = [];
  List<Job> _recommendedJobs = [];
  List<Job> _savedJobs = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedCategoryId;

  JobsProvider(ApiService apiService) : _jobsService = JobsService(apiService);

  List<JobCategory> get categories => _categories;
  List<Job> get recommendedJobs => _recommendedJobs;
  List<Job> get savedJobs => _savedJobs;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedCategoryId => _selectedCategoryId;

  Future<void> loadCategories() async {
    if (_categories.isNotEmpty) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _categories = await _jobsService.getCategories();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRecommendedJobs({String? categoryId}) async {
    _isLoading = true;
    _error = null;
    _selectedCategoryId = categoryId;
    notifyListeners();

    try {
      _recommendedJobs = await _jobsService.getRecommended(categoryId: categoryId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Job?> getJobById(String id) async {
    try {
      return await _jobsService.getById(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  void filterByCategory(String? categoryId) {
    _selectedCategoryId = categoryId;
    loadRecommendedJobs(categoryId: categoryId);
  }
}

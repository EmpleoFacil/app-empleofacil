import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/job.dart';
import '../providers/auth_provider.dart';
import '../providers/jobs_provider.dart';
import '../services/api_service.dart';
import '../services/applications_service.dart';
import '../services/messages_service.dart';
import '../services/saved_jobs_service.dart';
import '../widgets/bottom_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  int _unreadCount = 0;
  int _applicationsInReview = 0;
  bool _showSaved = false;
  List<Job> _savedJobs = [];
  String? _firstName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.init();
    final jobsProvider = context.read<JobsProvider>();
    await jobsProvider.loadCategories();
    await jobsProvider.loadRecommendedJobs();
    await _loadCandidateName();
    await _loadUnreadCount();
    await _loadApplicationsSummary();
  }

  Future<void> _loadCandidateName() async {
    try {
      final api = context.read<ApiService>();
      final response = await api.get('/candidates/me');
      final fullName = (response?['fullName'] ?? '') as String;
      final first = fullName.isNotEmpty ? fullName.split(' ').first : 'Hola';
      if (mounted) setState(() => _firstName = first);
    } catch (_) {
      // Silenciar error de nombre para no bloquear home
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final api = context.read<ApiService>();
      final authProvider = context.read<AuthProvider>();
      if (authProvider.isAuthenticated) {
        final messagesService = MessagesService(api);
        final count = await messagesService.getUnreadCount();
        if (mounted) setState(() => _unreadCount = count);
      }
    } catch (_) {}
  }

  Future<void> _loadApplicationsSummary() async {
    try {
      final api = context.read<ApiService>();
      final applicationsService = ApplicationsService(api);
      final summary = await applicationsService.getStatusSummary();
      if (mounted) {
        setState(() => _applicationsInReview = summary['enRevision'] as int? ?? 0);
      }
    } catch (_) {}
  }

  Future<void> _loadSavedJobs() async {
    try {
      final api = context.read<ApiService>();
      final savedJobsService = SavedJobsService(api);
      final jobs = await savedJobsService.getMySavedJobs();
      if (mounted) setState(() => _savedJobs = jobs);
    } catch (_) {}
  }

  void _toggleSaved() {
    setState(() => _showSaved = !_showSaved);
    if (_showSaved && _savedJobs.isEmpty) {
      _loadSavedJobs();
    }
  }

  IconData _getCategoryIcon(String? icon) {
    switch (icon) {
      case 'shield': return Icons.shield_outlined;
      case 'broom': return Icons.cleaning_services_outlined;
      case 'keys': return Icons.vpn_key_outlined;
      case 'box': return Icons.inventory_2_outlined;
      case 'headset': return Icons.headset_mic_outlined;
      case 'clipboard': return Icons.assignment_outlined;
      default: return Icons.work_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildSearchBar(),
                        const SizedBox(height: 16),
                        _buildCategoryChips(),
                        const SizedBox(height: 16),
                        _buildApplicationsCard(),
                        const SizedBox(height: 20),
                        _buildJobsHeader(),
                        const SizedBox(height: 12),
                        _buildJobsList(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Empleo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _firstName != null ? 'Hola, $_firstName' : 'Hola',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Estas vacantes podrían interesarte',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, size: 28),
                onPressed: () => context.go('/messages'),
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar trabajo, empresa o lugar',
          hintStyle: TextStyle(color: AppColors.textSecondary),
          prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onSubmitted: (query) {
          if (query.isNotEmpty) {
            context.go('/jobs/search?q=$query');
          }
        },
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Consumer<JobsProvider>(
      builder: (context, jobsProvider, _) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...jobsProvider.categories.take(4).map((category) {
                final isSelected = jobsProvider.selectedCategoryId == category.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: isSelected,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getCategoryIcon(category.icon),
                          size: 16,
                          color: isSelected ? Colors.white : AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(category.name),
                      ],
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: Colors.white,
                    selectedColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
                    ),
                    onSelected: (_) {
                      jobsProvider.filterByCategory(
                        isSelected ? null : category.id,
                      );
                    },
                  ),
                );
              }),
              ChoiceChip(
                selected: false,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.tune, size: 16, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text('Más'),
                  ],
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppColors.border),
                ),
                onSelected: (_) => _showFiltersSheet(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFiltersSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Consumer<JobsProvider>(
        builder: (context, jobsProvider, _) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtrar por categoría',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: jobsProvider.categories.map((category) {
                    final isSelected = jobsProvider.selectedCategoryId == category.id;
                    return FilterChip(
                      selected: isSelected,
                      label: Text(category.name),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                      onSelected: (_) {
                        jobsProvider.filterByCategory(isSelected ? null : category.id);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildApplicationsCard() {
    return GestureDetector(
      onTap: () => context.go('/applications'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.assignment_outlined, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tus postulaciones',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$_applicationsInReview en revisión',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildJobsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Vacantes recomendadas',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        TextButton(
          onPressed: _toggleSaved,
          child: Row(
            children: [
              Icon(
                _showSaved ? Icons.bookmark : Icons.bookmark_border,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                _showSaved ? 'Ver todas' : 'Guardadas',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJobsList() {
    return Consumer<JobsProvider>(
      builder: (context, jobsProvider, _) {
        if (jobsProvider.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final jobs = _showSaved ? _savedJobs : jobsProvider.recommendedJobs;

        if (jobs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.work_off_outlined, size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    _showSaved ? 'No tienes vacantes guardadas' : 'No hay vacantes disponibles',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: jobs.map((job) => _JobCard(job: job)).toList(),
        );
      },
    );
  }
}

class _JobCard extends StatefulWidget {
  final Job job;

  const _JobCard({required this.job});

  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard> {
  bool _isSaving = false;

  Future<void> _toggleSave() async {
    setState(() => _isSaving = true);
    try {
      final api = context.read<ApiService>();
      final savedJobsService = SavedJobsService(api);
      
      if (widget.job.isSaved) {
        await savedJobsService.unsave(widget.job.id);
      } else {
        await savedJobsService.save(widget.job.id);
      }
      
      // Refresh jobs to update isSaved status
      final jobsProvider = context.read<JobsProvider>();
      await jobsProvider.loadRecommendedJobs(categoryId: jobsProvider.selectedCategoryId);
      
      if (mounted) setState(() => _isSaving = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/jobs/${widget.job.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(Icons.business, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.job.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.job.company?.name ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.job.hasApplied)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F5EF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Ya aplicaste',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: Icon(
                      widget.job.isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: widget.job.isSaved ? AppColors.primary : AppColors.textSecondary,
                    ),
                    onPressed: _isSaving ? null : _toggleSave,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  widget.job.city ?? 'Nicaragua',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 16),
                Icon(Icons.attach_money, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.job.salaryRange,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

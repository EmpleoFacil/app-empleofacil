class Job {
  final String id;
  final String title;
  final String? description;
  final List<String> requirements;
  final List<String> benefits;
  final String? city;
  final String? country;
  final int? salaryMin;
  final int? salaryMax;
  final String? currency;
  final String? employmentType;
  final String? modality;
  final String status;
  final Company? company;
  final JobCategory? category;
  final bool isSaved;
  final bool hasApplied;
  final String? applicationId;
  final String? applicationStatus;

  Job({
    required this.id,
    required this.title,
    this.description,
    this.requirements = const [],
    this.benefits = const [],
    this.city,
    this.country,
    this.salaryMin,
    this.salaryMax,
    this.currency,
    this.employmentType,
    this.modality,
    required this.status,
    this.company,
    this.category,
    this.isSaved = false,
    this.hasApplied = false,
    this.applicationId,
    this.applicationStatus,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      requirements: (json['requirements'] as List?)?.cast<String>() ?? [],
      benefits: (json['benefits'] as List?)?.cast<String>() ?? [],
      city: json['city'] as String?,
      country: json['country'] as String?,
      salaryMin: json['salaryMin'] as int?,
      salaryMax: json['salaryMax'] as int?,
      currency: json['currency'] as String? ?? 'NIO',
      employmentType: json['employmentType'] as String?,
      modality: json['modality'] as String?,
      status: json['status'] as String,
      company: json['company'] != null ? Company.fromJson(json['company']) : null,
      category: json['category'] != null ? JobCategory.fromJson(json['category']) : null,
      isSaved: json['isSaved'] as bool? ?? false,
      hasApplied: json['hasApplied'] as bool? ?? false,
      applicationId: json['applicationId'] as String?,
      applicationStatus: json['applicationStatus'] as String?,
    );
  }

  String get salaryRange {
    if (salaryMin == null && salaryMax == null) return 'Salario no especificado';
    final curr = currency ?? 'C\$';
    if (salaryMin != null && salaryMax != null) {
      return '$curr${_formatNumber(salaryMin!)} a $curr${_formatNumber(salaryMax!)}';
    }
    if (salaryMin != null) return 'Desde $curr${_formatNumber(salaryMin!)}';
    return 'Hasta $curr${_formatNumber(salaryMax!)}';
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}

class Company {
  final String id;
  final String name;
  final String? logoUrl;

  Company({
    required this.id,
    required this.name,
    this.logoUrl,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] as String,
      name: json['name'] as String,
      logoUrl: json['logoUrl'] as String?,
    );
  }
}

class JobCategory {
  final String id;
  final String name;
  final String? icon;

  JobCategory({
    required this.id,
    required this.name,
    this.icon,
  });

  factory JobCategory.fromJson(Map<String, dynamic> json) {
    return JobCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
    );
  }
}

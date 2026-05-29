class CandidateDocument {
  final String id;
  final String type;
  final String? fileUrl;
  final String status;
  final DateTime? uploadedAt;

  CandidateDocument({
    required this.id,
    required this.type,
    this.fileUrl,
    required this.status,
    this.uploadedAt,
  });

  factory CandidateDocument.fromJson(Map<String, dynamic> json) {
    return CandidateDocument(
      id: json['id'] as String,
      type: json['type'] as String,
      fileUrl: json['fileUrl'] as String?,
      status: json['status'] as String,
      uploadedAt: json['uploadedAt'] != null 
          ? DateTime.parse(json['uploadedAt'] as String) 
          : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'uploaded':
        return 'Cargado';
      case 'approved':
        return 'Aprobado';
      case 'rejected':
        return 'Rechazado';
      default:
        return status;
    }
  }
}

class DocumentType {
  final String id;
  final String label;
  final bool isRequired;

  DocumentType({
    required this.id,
    required this.label,
    required this.isRequired,
  });

  factory DocumentType.fromJson(Map<String, dynamic> json) {
    return DocumentType(
      id: json['id'] as String,
      label: json['label'] as String,
      isRequired: json['isRequired'] as bool? ?? false,
    );
  }
}

import 'job.dart';

class Application {
  final String id;
  final String jobId;
  final String candidateId;
  final String status;
  final DateTime appliedAt;
  final Job? job;
  final Interview? nextInterview;
  final Message? latestMessage;

  Application({
    required this.id,
    required this.jobId,
    required this.candidateId,
    required this.status,
    required this.appliedAt,
    this.job,
    this.nextInterview,
    this.latestMessage,
  });

  factory Application.fromJson(Map<String, dynamic> json) {
    final interviews = json['interviews'] as List?;
    final messages = json['messages'] as List?;
    final embeddedInterview = json['nextInterview'] ?? json['interview'];

    Interview? nextInterview;
    if (embeddedInterview is Map<String, dynamic>) {
      nextInterview = Interview.fromJson(embeddedInterview);
    } else if (interviews != null && interviews.isNotEmpty) {
      nextInterview = Interview.fromJson(interviews.first as Map<String, dynamic>);
    }

    return Application(
      id: json['id'] as String,
      jobId: json['jobId'] as String,
      candidateId: json['candidateId'] as String,
      status: json['status'] as String,
      appliedAt: DateTime.parse(json['appliedAt'] as String),
      job: json['job'] != null ? Job.fromJson(json['job']) : null,
      nextInterview: nextInterview,
      latestMessage: messages != null && messages.isNotEmpty 
          ? Message.fromJson(messages.first) 
          : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'applied':
        return 'Postulado';
      case 'reviewing':
        return 'En revisión';
      case 'preselected':
        return 'Preseleccionado';
      case 'interview_scheduled':
        return 'Entrevista programada';
      case 'interview_confirmed':
        return 'Entrevista confirmada';
      case 'hired':
        return 'Contratado';
      case 'rejected':
        return 'No seleccionado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return status;
    }
  }
}

class ApplicationSummary {
  final int total;
  final int enRevision;
  final int entrevista;
  final int noSeleccionado;
  final int postulado;

  ApplicationSummary({
    required this.total,
    required this.enRevision,
    required this.entrevista,
    required this.noSeleccionado,
    required this.postulado,
  });

  factory ApplicationSummary.fromJson(Map<String, dynamic> json) {
    return ApplicationSummary(
      total: json['total'] as int? ?? 0,
      enRevision: json['enRevision'] as int? ?? 0,
      entrevista: json['entrevista'] as int? ?? 0,
      noSeleccionado: json['noSeleccionado'] as int? ?? 0,
      postulado: json['postulado'] as int? ?? 0,
    );
  }
}

class Interview {
  final String id;
  final DateTime date;
  final String modality;
  final String? location;
  final String? meetingUrl;
  final String status;

  Interview({
    required this.id,
    required this.date,
    required this.modality,
    this.location,
    this.meetingUrl,
    required this.status,
  });

  factory Interview.fromJson(Map<String, dynamic> json) {
    return Interview(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      modality: json['modality'] as String,
      location: json['location'] as String?,
      meetingUrl: json['meetingUrl'] as String?,
      status: json['status'] as String,
    );
  }
}

class Message {
  final String id;
  final String title;
  final String body;
  final String type;
  final String status;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.status,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String? ?? '',
      type: json['type'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

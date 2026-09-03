import 'company.dart';
import 'enums.dart';
import 'profile.dart';

class Job {
  const Job({
    required this.id,
    required this.jobNumber,
    required this.jobType,
    required this.jobCategory,
    required this.purpose,
    this.companyId,
    this.assignedTo,
    this.customerName,
    this.customerMobile,
    this.location,
    this.lat,
    this.lng,
    required this.startAt,
    required this.endAt,
    required this.status,
    this.assignedBy,
    this.reviewedBy,
    this.reviewedAt,
    this.checkoutNote,
    this.clientId,
    required this.createdAt,
    this.company,
    this.assignee,
  });

  final String id;
  final int jobNumber;
  final String jobType;
  final String jobCategory;
  final String purpose;
  final String? companyId;
  final String? assignedTo;
  final String? customerName;
  final String? customerMobile;
  final String? location;
  final double? lat;
  final double? lng;
  final DateTime startAt;
  final DateTime endAt;
  final JobStatus status;
  final String? assignedBy;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? checkoutNote;
  final String? clientId;
  final DateTime createdAt;
  final Company? company;
  final Profile? assignee;

  String get title => purpose.isNotEmpty ? purpose : jobType;
  String get displayId => jobNumber.toString();

  factory Job.fromMap(Map<String, dynamic> map) {
    Company? company;
    final rawCompany = map['companies'];
    if (rawCompany is Map<String, dynamic>) {
      company = Company.fromMap(rawCompany);
    }

    Profile? assignee;
    final rawAssignee = map['assignee'];
    if (rawAssignee is Map<String, dynamic>) {
      assignee = Profile.fromMap(rawAssignee);
    }

    return Job(
      id: map['id'] as String,
      jobNumber: (map['job_number'] as num?)?.toInt() ?? 0,
      jobType: (map['job_type'] as String?) ?? '',
      jobCategory: (map['job_category'] as String?) ?? '',
      purpose: (map['purpose'] as String?) ?? '',
      companyId: map['company_id'] as String?,
      assignedTo: map['assigned_to'] as String?,
      customerName: map['customer_name'] as String?,
      customerMobile: map['customer_mobile'] as String?,
      location: map['location'] as String?,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      startAt: DateTime.tryParse('${map['start_at']}') ?? DateTime.now(),
      endAt: DateTime.tryParse('${map['end_at']}') ?? DateTime.now(),
      status: JobStatusX.fromDb(map['status'] as String?),
      assignedBy: map['assigned_by'] as String?,
      reviewedBy: map['reviewed_by'] as String?,
      reviewedAt: map['reviewed_at'] == null
          ? null
          : DateTime.tryParse(map['reviewed_at'].toString()),
      checkoutNote: map['checkout_note'] as String?,
      clientId: map['client_id'] as String?,
      createdAt: DateTime.tryParse('${map['created_at']}') ?? DateTime.now(),
      company: company,
      assignee: assignee,
    );
  }
}

class JobProof {
  const JobProof({
    required this.id,
    required this.jobId,
    required this.kind,
    required this.storagePath,
    required this.sortOrder,
  });

  final String id;
  final String jobId;
  final ProofKind kind;
  final String storagePath;
  final int sortOrder;

  factory JobProof.fromMap(Map<String, dynamic> map) {
    return JobProof(
      id: map['id'] as String,
      jobId: map['job_id'] as String,
      kind: (map['kind'] as String?) == 'signature'
          ? ProofKind.signature
          : ProofKind.photo,
      storagePath: map['storage_path'] as String,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/partnership_request_model.dart';

String partnershipCardStatus({
  required DocumentSnapshot<Map<String, dynamic>> linkSnap,
  required PartnershipRequestModel? request,
}) {
  if (linkSnap.exists) {
    final linkStatus =
        (linkSnap.data()?['status'] as String?)?.toLowerCase() ?? 'active';
    if (linkStatus == 'active' || linkStatus == 'approved') {
      return 'Already Partners';
    }
  }

  if (request == null) return 'Not Invited';

  switch (request.status) {
    case 'pending':
      return 'Request Pending';
    case 'accepted':
      return 'Already Partners';
    case 'rejected':
      return 'Request Rejected';
    case 'removed':
      return 'Not Invited';
    default:
      return 'Not Invited';
  }
}

String supplierPartnershipCardStatus({
  required DocumentSnapshot<Map<String, dynamic>> linkSnap,
  required PartnershipRequestModel? request,
}) {
  final status = partnershipCardStatus(linkSnap: linkSnap, request: request);
  if (status == 'Not Invited') return 'Not Requested';
  return status;
}

int _compareTimestamps(dynamic a, dynamic b) {
  DateTime? toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  final da = toDate(a);
  final db = toDate(b);
  if (da == null && db == null) return 0;
  if (da == null) return 1;
  if (db == null) return -1;
  return db.compareTo(da);
}

/// Picks the newest partnership request doc for a company/supplier pair.
PartnershipRequestModel? newestPartnershipRequest(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  if (docs.isEmpty) return null;
  final sorted = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs)
    ..sort(
      (a, b) => _compareTimestamps(
        a.data()['createdAt'],
        b.data()['createdAt'],
      ),
    );
  final doc = sorted.first;
  return PartnershipRequestModel.fromMap(doc.id, doc.data());
}

List<PartnershipRequestModel> sortPartnershipRequestsNewest(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final sorted = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs)
    ..sort(
      (a, b) => _compareTimestamps(
        a.data()['createdAt'],
        b.data()['createdAt'],
      ),
    );
  return sorted
      .map((d) => PartnershipRequestModel.fromMap(d.id, d.data()))
      .toList();
}

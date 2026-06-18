import 'package:cloud_firestore/cloud_firestore.dart';

class PaginationHelper<T> {
  final List<T> items;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  const PaginationHelper({
    required this.items,
    this.lastDocument,
    required this.hasMore,
  });

  static PaginationHelper<T> fromSnapshot<T>(
    QuerySnapshot snapshot,
    T Function(DocumentSnapshot) mapper,
    int pageSize,
  ) {
    final items = snapshot.docs.map(mapper).toList();
    return PaginationHelper(
      items: items,
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length >= pageSize,
    );
  }
}

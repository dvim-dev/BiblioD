import 'dart:convert';

class SyncManifest {
  final String clientId;
  final String clientName;
  final int revision;
  final String lastModified;
  final int booksCount;
  final String dbSha256;

  const SyncManifest({
    required this.clientId,
    required this.clientName,
    required this.revision,
    required this.lastModified,
    required this.booksCount,
    required this.dbSha256,
  });

  Map<String, dynamic> toMap() => {
    'client_id': clientId,
    'client_name': clientName,
    'revision': revision,
    'last_modified': lastModified,
    'books_count': booksCount,
    'db_sha256': dbSha256,
  };

  String toJson() => jsonEncode(toMap());

  factory SyncManifest.fromMap(Map<String, dynamic> map) {
    return SyncManifest(
      clientId: map['client_id'] as String? ?? '',
      clientName: map['client_name'] as String? ?? '',
      revision: (map['revision'] as num?)?.toInt() ?? 0,
      lastModified: map['last_modified'] as String? ?? '',
      booksCount: (map['books_count'] as num?)?.toInt() ?? 0,
      dbSha256: map['db_sha256'] as String? ?? '',
    );
  }

  factory SyncManifest.fromJson(String source) {
    return SyncManifest.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }
}

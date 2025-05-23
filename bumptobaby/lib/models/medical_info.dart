import 'package:cloud_firestore/cloud_firestore.dart';

class MedicalInfo {
  final String id;
  final String title;
  final String abstract;
  final String source;
  final String url;
  final List<double> embedding;
  final DateTime publishedDate;
  final Map<String, dynamic>? metadata;

  MedicalInfo({
    required this.id,
    required this.title,
    required this.abstract,
    required this.source,
    required this.url,
    required this.embedding,
    required this.publishedDate,
    this.metadata,
  });

  // Convert to JSON for Firebase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'abstract': abstract,
      'source': source,
      'url': url,
      'embedding': embedding,
      'publishedDate': publishedDate.toIso8601String(),
      'metadata': metadata,
    };
  }

  // Create from Firebase document
  factory MedicalInfo.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MedicalInfo(
      id: doc.id,
      title: data['title'] ?? '',
      abstract: data['abstract'] ?? '',
      source: data['source'] ?? 'PubMed',
      url: data['url'] ?? '',
      embedding: List<double>.from(data['embedding'] ?? []),
      publishedDate: DateTime.parse(data['publishedDate'] ?? DateTime.now().toIso8601String()),
      metadata: data['metadata'],
    );
  }
}

class MedicalFactCheck {
  final String id;
  final String claimText;
  final bool isMisinformation;
  final String explanation;
  final List<MedicalInfo> relatedSources;
  final DateTime checkedAt;

  MedicalFactCheck({
    required this.id,
    required this.claimText,
    required this.isMisinformation,
    required this.explanation,
    required this.relatedSources,
    required this.checkedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'claimText': claimText,
      'isMisinformation': isMisinformation,
      'explanation': explanation,
      'relatedSourceIds': relatedSources.map((source) => source.id).toList(),
      'checkedAt': checkedAt.toIso8601String(),
    };
  }

  factory MedicalFactCheck.fromFirestore(
    DocumentSnapshot doc,
    List<MedicalInfo> availableSources,
  ) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    List<String> sourceIds = List<String>.from(data['relatedSourceIds'] ?? []);
    
    List<MedicalInfo> sources = availableSources
        .where((source) => sourceIds.contains(source.id))
        .toList();

    return MedicalFactCheck(
      id: doc.id,
      claimText: data['claimText'] ?? '',
      isMisinformation: data['isMisinformation'] ?? false,
      explanation: data['explanation'] ?? '',
      relatedSources: sources,
      checkedAt: DateTime.parse(data['checkedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
} 
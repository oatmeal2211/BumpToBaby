import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bumptobaby/models/medical_info.dart';

class PubMedRagService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _qwenApiKey;
  final String? _pubmedApiKey;
  
  // Collection references
  final CollectionReference _medicalInfoCollection;
  final CollectionReference _factChecksCollection;
  
  // DashScope API endpoint (OpenAI-compatible mode)
  final String _dashscopeBaseUrl = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1";
  
  // Constructor
  PubMedRagService() 
    : _qwenApiKey = dotenv.env['DASHSCOPE_API_KEY'],
      _pubmedApiKey = dotenv.env['PUBMED_API_KEY'],
      _medicalInfoCollection = FirebaseFirestore.instance.collection('medical_info'),
      _factChecksCollection = FirebaseFirestore.instance.collection('fact_checks');
  
  // Fetch data from PubMed
  Future<List<Map<String, dynamic>>> fetchPubMedData(String query, {int maxResults = 50}) async {
    if (_pubmedApiKey == null) {
      throw Exception("PubMed API Key not found. Make sure your .env file is set up correctly.");
    }
    
    try {
      // First search for article IDs
      final searchUrl = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=$query&retmax=$maxResults&retmode=json&api_key=$_pubmedApiKey';
      final searchResponse = await http.get(Uri.parse(searchUrl));
      
      if (searchResponse.statusCode != 200) {
        throw Exception('Failed to search PubMed: ${searchResponse.statusCode}');
      }
      
      final searchData = jsonDecode(searchResponse.body);
      final List<dynamic> idList = searchData['esearchresult']['idlist'];
      
      if (idList.isEmpty) {
        return [];
      }
      
      // Then fetch details for those IDs
      final ids = idList.join(',');
      final fetchUrl = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=$ids&retmode=xml&rettype=abstract&api_key=$_pubmedApiKey';
      final fetchResponse = await http.get(Uri.parse(fetchUrl));
      
      if (fetchResponse.statusCode != 200) {
        throw Exception('Failed to fetch PubMed articles: ${fetchResponse.statusCode}');
      }
      
      // Parse XML response
      // Note: A proper XML parser would be better, but for simplicity using regex to extract key fields
      final xml = fetchResponse.body;
      List<Map<String, dynamic>> articles = [];
      
      for (String id in idList) {
        final titleRegex = RegExp('<ArticleTitle>(.*?)</ArticleTitle>');
        final abstractRegex = RegExp('<AbstractText>(.*?)</AbstractText>');
        final dateRegex = RegExp('<PubDate>(.*?)</PubDate>');
        
        final titleMatch = titleRegex.firstMatch(xml);
        final abstractMatch = abstractRegex.firstMatch(xml);
        final dateMatch = dateRegex.firstMatch(xml);
        
        if (titleMatch != null) {
          articles.add({
            'id': id,
            'title': titleMatch.group(1) ?? '',
            'abstract': abstractMatch?.group(1) ?? '',
            'date': dateMatch?.group(1) ?? '',
            'url': 'https://pubmed.ncbi.nlm.nih.gov/$id/',
            'source': 'PubMed',
          });
        }
      }
      
      return articles;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching PubMed data: $e');
      }
      rethrow;
    }
  }
  
  // Generate embedding using Qwen API via DashScope
  Future<List<double>> generateEmbedding(String text) async {
    if (_qwenApiKey == null) {
      throw Exception("DashScope API Key not found. Make sure your .env file is set up correctly with DASHSCOPE_API_KEY.");
    }
    
    try {
      final response = await http.post(
        Uri.parse('$_dashscopeBaseUrl/embeddings'),
        headers: {
          'Authorization': 'Bearer $_qwenApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'input': text,
          'model': 'text-embedding-v3',
        }),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to generate embedding: ${response.statusCode}, ${response.body}');
      }
      
      final data = jsonDecode(response.body);
      return List<double>.from(data['data'][0]['embedding']);
    } catch (e) {
      if (kDebugMode) {
        print('Error generating embedding: $e');
      }
      rethrow;
    }
  }
  
  // Store medical information with embeddings in Firebase
  Future<void> storeMedicalInfo(Map<String, dynamic> articleData) async {
    try {
      // Generate embedding for title + abstract
      final text = '${articleData['title']} ${articleData['abstract']}';
      final embedding = await generateEmbedding(text);
      
      // Parse date string to DateTime (simplistic approach)
      DateTime publishedDate;
      try {
        publishedDate = DateTime.parse(articleData['date']);
      } catch (_) {
        publishedDate = DateTime.now(); // Fallback
      }
      
      // Create MedicalInfo object
      final medicalInfo = MedicalInfo(
        id: articleData['id'],
        title: articleData['title'],
        abstract: articleData['abstract'],
        source: articleData['source'],
        url: articleData['url'],
        embedding: embedding,
        publishedDate: publishedDate,
      );
      
      // Store in Firestore
      await _medicalInfoCollection.doc(articleData['id']).set(medicalInfo.toJson());
      
    } catch (e) {
      if (kDebugMode) {
        print('Error storing medical info: $e');
      }
      rethrow;
    }
  }
  
  // Batch process and store multiple articles
  Future<void> batchStoreMedicalInfo(List<Map<String, dynamic>> articles) async {
    for (var article in articles) {
      try {
        await storeMedicalInfo(article);
      } catch (e) {
        if (kDebugMode) {
          print('Error storing article ${article['id']}: $e');
        }
        // Continue with next article even if one fails
      }
    }
  }
  
  // Seed initial data from PubMed on common pregnancy and infant topics
  Future<void> seedInitialData() async {
    final topics = [
      'pregnancy nutrition',
      'breastfeeding benefits',
      'infant vaccination safety',
      'pregnancy exercise',
      'postpartum depression',
      'infant sleep safety',
      'gestational diabetes',
      'preeclampsia',
      'infant development milestones',
      'pregnancy ultrasound'
    ];
    
    for (var topic in topics) {
      try {
        final articles = await fetchPubMedData(topic, maxResults: 10);
        await batchStoreMedicalInfo(articles);
        if (kDebugMode) {
          print('Stored ${articles.length} articles for topic: $topic');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error seeding data for topic $topic: $e');
        }
      }
    }
  }
  
  // Search for similar content in our database
  Future<List<MedicalInfo>> findSimilarContent(String query, {int limit = 5}) async {
    try {
      // Generate embedding for the query
      final queryEmbedding = await generateEmbedding(query);
      
      // Get all medical info documents
      // Note: For production, you'd want to use a vector database like Pinecone
      // This is a simple approach that works for smaller datasets
      final snapshot = await _medicalInfoCollection.get();
      
      List<MedicalInfo> allDocs = snapshot.docs
          .map((doc) => MedicalInfo.fromFirestore(doc))
          .toList();
      
      // Calculate cosine similarity for each document
      List<Map<String, dynamic>> similarities = allDocs.map((doc) {
        double similarity = _calculateCosineSimilarity(queryEmbedding, doc.embedding);
        return {'doc': doc, 'similarity': similarity};
      }).toList();
      
      // Sort by similarity (descending)
      similarities.sort((a, b) => b['similarity'].compareTo(a['similarity']));
      
      // Take top results
      return similarities
          .take(limit)
          .map((item) => item['doc'] as MedicalInfo)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error finding similar content: $e');
      }
      rethrow;
    }
  }
  
  // Calculate cosine similarity between two embeddings
  double _calculateCosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw Exception('Embeddings must have the same dimension');
    }
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    return dotProduct / (math.sqrt(normA) * math.sqrt(normB));
  }
  
  // Check content for medical misinformation using RAG
  Future<MedicalFactCheck> checkForMisinformation(String content) async {
    try {
      // Find similar medical info
      final similarContent = await findSimilarContent(content);
      
      if (similarContent.isEmpty) {
        // Not enough reference data to check
        return MedicalFactCheck(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          claimText: content,
          isMisinformation: false, // Default to not misinformation if we can't verify
          explanation: "Insufficient reference data to validate this claim.",
          relatedSources: [],
          checkedAt: DateTime.now(),
        );
      }
      
      // Use Qwen to analyze the content against the medical info
      final analysisResult = await _analyzeContentWithQwen(content, similarContent);
      
      // Store the fact check result
      final factCheck = MedicalFactCheck(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        claimText: content,
        isMisinformation: analysisResult['is_misinformation'],
        explanation: analysisResult['explanation'],
        relatedSources: similarContent,
        checkedAt: DateTime.now(),
      );
      
      // Store in Firestore
      await _factChecksCollection.add(factCheck.toJson());
      
      return factCheck;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking for misinformation: $e');
      }
      
      // Return a default response on error
      return MedicalFactCheck(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        claimText: content,
        isMisinformation: false,
        explanation: "Unable to verify this claim due to a technical error.",
        relatedSources: [],
        checkedAt: DateTime.now(),
      );
    }
  }
  
  // Analyze content using Qwen API via DashScope
  Future<Map<String, dynamic>> _analyzeContentWithQwen(
    String content, 
    List<MedicalInfo> relatedSources
  ) async {
    if (_qwenApiKey == null) {
      throw Exception("DashScope API Key not found. Make sure your .env file is set up correctly with DASHSCOPE_API_KEY.");
    }
    
    try {
      // Format the related sources as context
      String context = relatedSources.map((source) {
        return """
Source: ${source.title}
Abstract: ${source.abstract}
URL: ${source.url}
Published: ${source.publishedDate.toString()}
""";
      }).join('\n---\n');
      
      // Create prompt for Qwen
      String prompt = """
You are a medical fact-checking assistant. Your task is to analyze whether the user's content contains medical misinformation.

Here is relevant medical information from trusted sources:
$context

User content to analyze:
"$content"

Analyze whether the user's content contains medical misinformation related to pregnancy or infant care.
Your response must be in the following JSON format:
{
  "is_misinformation": true/false,
  "explanation": "Your detailed explanation of why this is or isn't misinformation, citing specific scientific evidence"
}

Focus on factual accuracy, not tone or style. Only mark content as misinformation if it directly contradicts established medical consensus.
""";

      // Call Qwen API through DashScope's OpenAI-compatible endpoint
      final response = await http.post(
        Uri.parse('$_dashscopeBaseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_qwenApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'qwen-plus',
          'messages': [
            {'role': 'system', 'content': 'You are an expert medical fact-checking assistant.'},
            {'role': 'user', 'content': prompt}
          ],
          'response_format': {'type': 'json_object'}
        }),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to analyze content: ${response.statusCode}, ${response.body}');
      }
      
      final data = jsonDecode(response.body);
      final responseContent = data['choices'][0]['message']['content'];
      
      // Parse the JSON response
      final analysisResult = jsonDecode(responseContent);
      return {
        'is_misinformation': analysisResult['is_misinformation'] ?? false,
        'explanation': analysisResult['explanation'] ?? 'No explanation provided.'
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error analyzing content with Qwen: $e');
      }
      return {
        'is_misinformation': false,
        'explanation': 'Unable to analyze content due to a technical error.'
      };
    }
  }
} 
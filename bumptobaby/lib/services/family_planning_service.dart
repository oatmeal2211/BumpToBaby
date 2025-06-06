import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bumptobaby/models/family_planning.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

class FamilyPlanningService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  
  // Save or update family planning data
  Future<void> saveFamilyPlanningData(FamilyPlanningData data) async {
    try {
      // Always save to local storage first
      await _saveLocalData(data);
      
      // Then try to save to Firebase if authenticated
      if (currentUserId != null) {
        try {
          await _firestore
              .collection('familyPlanning')
              .doc(currentUserId)
              .set(data.toMap(), SetOptions(merge: true));
        } catch (e) {
          print('Error saving to Firebase: $e');
          // Don't rethrow, we already saved to local storage
        }
      }
    } catch (e) {
      print('Error saving family planning data: $e');
      rethrow;
    }
  }
  
  // Get family planning data for current user
  Future<FamilyPlanningData?> getFamilyPlanningData() async {
    try {
      // First try to get from local storage for faster loading
      final localData = await _getLocalData();
      
      if (currentUserId != null) {
        // Try to get from Firebase if authenticated
        try {
          DocumentSnapshot doc = await _firestore
              .collection('familyPlanning')
              .doc(currentUserId)
              .get();
              
          if (doc.exists) {
            final firebaseData = FamilyPlanningData.fromMap(doc.data() as Map<String, dynamic>);
            
            // If we have both local and Firebase data, merge them
            if (localData != null) {
              // Use the most recent data
              final mergedData = _mergeData(localData, firebaseData);
              // Save the merged data back to both storages
              await saveFamilyPlanningData(mergedData);
              return mergedData;
            }
            
            return firebaseData;
          }
        } catch (e) {
          print('Error getting data from Firebase: $e');
        }
      }
      
      return localData;
    } catch (e) {
      print('Error getting family planning data: $e');
      return await _getLocalData();
    }
  }
  
  // Merge local and Firebase data, taking the most recent information
  FamilyPlanningData _mergeData(FamilyPlanningData local, FamilyPlanningData firebase) {
    // Combine period dates without duplicates
    final allPeriodDates = Set<DateTime>.from(local.periodDates);
    allPeriodDates.addAll(firebase.periodDates);
    
    // Combine pill dates without duplicates
    final allPillDates = Set<DateTime>.from(local.pillTakenDates);
    allPillDates.addAll(firebase.pillTakenDates);
    
    // Combine injection dates without duplicates
    final allInjectionDates = Set<DateTime>.from(local.injectionDates);
    allInjectionDates.addAll(firebase.injectionDates);
    
    // Combine contraceptive methods without duplicates
    final allMethods = Set<String>.from(local.contraceptiveMethodsUsed);
    allMethods.addAll(firebase.contraceptiveMethodsUsed);
    
    // Use the most recent planning goal (prefer Firebase's value)
    final planningGoal = firebase.planningGoal.isNotEmpty 
        ? firebase.planningGoal 
        : local.planningGoal;
    
    // Use the most recent last period date
    final lastPeriodDate = _getMostRecentDate(local.lastPeriodDate, firebase.lastPeriodDate);
    
    // Use the most recent cycle duration
    final cycleDuration = firebase.cycleDuration > 0 
        ? firebase.cycleDuration 
        : local.cycleDuration;
    
    return FamilyPlanningData(
      userId: firebase.userId,
      planningGoal: planningGoal,
      contraceptiveMethodsUsed: allMethods.toList(),
      lastPeriodDate: lastPeriodDate,
      cycleDuration: cycleDuration,
      periodDates: allPeriodDates.toList(),
      pillTakenDates: allPillDates.toList(),
      injectionDates: allInjectionDates.toList(),
    );
  }
  
  // Get the most recent date between two dates
  DateTime _getMostRecentDate(DateTime date1, DateTime date2) {
    return date1.isAfter(date2) ? date1 : date2;
  }
  
  // Update planning goal
  Future<void> updatePlanningGoal(String goal) async {
    try {
      // First get existing data
      final data = await getFamilyPlanningData() ?? FamilyPlanningData(
        userId: currentUserId ?? 'anonymous',
        planningGoal: goal,
        lastPeriodDate: DateTime.now(),
      );
      
      // Update the goal
      final updatedData = FamilyPlanningData(
        userId: data.userId,
        planningGoal: goal,
        contraceptiveMethodsUsed: data.contraceptiveMethodsUsed,
        lastPeriodDate: data.lastPeriodDate,
        cycleDuration: data.cycleDuration,
        periodDates: data.periodDates,
        pillTakenDates: data.pillTakenDates,
        injectionDates: data.injectionDates,
      );
      
      // Save the updated data
      await saveFamilyPlanningData(updatedData);
    } catch (e) {
      print('Error updating planning goal: $e');
      rethrow;
    }
  }
  
  // Add contraceptive method
  Future<void> addContraceptiveMethod(String method) async {
    try {
      // First get existing data
      final data = await getFamilyPlanningData() ?? FamilyPlanningData(
        userId: currentUserId ?? 'anonymous',
        planningGoal: 'undecided',
        lastPeriodDate: DateTime.now(),
      );
      
      // Update the methods
      final updatedMethods = List<String>.from(data.contraceptiveMethodsUsed);
      if (!updatedMethods.contains(method)) {
        updatedMethods.add(method);
      }
      
      final updatedData = FamilyPlanningData(
        userId: data.userId,
        planningGoal: data.planningGoal,
        contraceptiveMethodsUsed: updatedMethods,
        lastPeriodDate: data.lastPeriodDate,
        cycleDuration: data.cycleDuration,
        periodDates: data.periodDates,
        pillTakenDates: data.pillTakenDates,
        injectionDates: data.injectionDates,
      );
      
      // Save the updated data
      await saveFamilyPlanningData(updatedData);
    } catch (e) {
      print('Error adding contraceptive method: $e');
      rethrow;
    }
  }
  
  // Record period date
  Future<void> recordPeriod(DateTime date) async {
    try {
      // First get existing data
      final data = await getFamilyPlanningData() ?? FamilyPlanningData(
        userId: currentUserId ?? 'anonymous',
        planningGoal: 'undecided',
        lastPeriodDate: date,
      );
      
      // Update the periods
      final updatedPeriods = List<DateTime>.from(data.periodDates);
      if (!_containsDate(updatedPeriods, date)) {
        updatedPeriods.add(date);
      }
      
      final updatedData = FamilyPlanningData(
        userId: data.userId,
        planningGoal: data.planningGoal,
        contraceptiveMethodsUsed: data.contraceptiveMethodsUsed,
        lastPeriodDate: date,
        cycleDuration: data.cycleDuration,
        periodDates: updatedPeriods,
        pillTakenDates: data.pillTakenDates,
        injectionDates: data.injectionDates,
      );
      
      // Save the updated data
      await saveFamilyPlanningData(updatedData);
    } catch (e) {
      print('Error recording period: $e');
      rethrow;
    }
  }
  
  // Record pill taken
  Future<void> recordPillTaken(DateTime date) async {
    try {
      // First get existing data
      final data = await getFamilyPlanningData() ?? FamilyPlanningData(
        userId: currentUserId ?? 'anonymous',
        planningGoal: 'undecided',
        lastPeriodDate: DateTime.now(),
      );
      
      // Update the pills
      final updatedPills = List<DateTime>.from(data.pillTakenDates);
      if (!_containsDate(updatedPills, date)) {
        updatedPills.add(date);
      }
      
      final updatedData = FamilyPlanningData(
        userId: data.userId,
        planningGoal: data.planningGoal,
        contraceptiveMethodsUsed: data.contraceptiveMethodsUsed,
        lastPeriodDate: data.lastPeriodDate,
        cycleDuration: data.cycleDuration,
        periodDates: data.periodDates,
        pillTakenDates: updatedPills,
        injectionDates: data.injectionDates,
      );
      
      // Save the updated data
      await saveFamilyPlanningData(updatedData);
    } catch (e) {
      print('Error recording pill: $e');
      rethrow;
    }
  }
  
  // Record injection
  Future<void> recordInjection(DateTime date) async {
    try {
      // First get existing data
      final data = await getFamilyPlanningData() ?? FamilyPlanningData(
        userId: currentUserId ?? 'anonymous',
        planningGoal: 'undecided',
        lastPeriodDate: DateTime.now(),
      );
      
      // Update the injections
      final updatedInjections = List<DateTime>.from(data.injectionDates);
      if (!_containsDate(updatedInjections, date)) {
        updatedInjections.add(date);
      }
      
      final updatedData = FamilyPlanningData(
        userId: data.userId,
        planningGoal: data.planningGoal,
        contraceptiveMethodsUsed: data.contraceptiveMethodsUsed,
        lastPeriodDate: data.lastPeriodDate,
        cycleDuration: data.cycleDuration,
        periodDates: data.periodDates,
        pillTakenDates: data.pillTakenDates,
        injectionDates: updatedInjections,
      );
      
      // Save the updated data
      await saveFamilyPlanningData(updatedData);
    } catch (e) {
      print('Error recording injection: $e');
      rethrow;
    }
  }
  
  // Helper method to check if a date exists in a list (ignoring time)
  bool _containsDate(List<DateTime> dates, DateTime date) {
    return dates.any((d) => 
      d.year == date.year && 
      d.month == date.month && 
      d.day == date.day
    );
  }
  
  // Save data to local storage
  Future<void> _saveLocalData(FamilyPlanningData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert DateTime objects to ISO strings for JSON serialization
      final serializedData = {
        'userId': data.userId,
        'planningGoal': data.planningGoal,
        'contraceptiveMethodsUsed': data.contraceptiveMethodsUsed,
        'lastPeriodDate': data.lastPeriodDate.toIso8601String(),
        'cycleDuration': data.cycleDuration,
        'periodDates': data.periodDates.map((date) => date.toIso8601String()).toList(),
        'pillTakenDates': data.pillTakenDates.map((date) => date.toIso8601String()).toList(),
        'injectionDates': data.injectionDates.map((date) => date.toIso8601String()).toList(),
      };
      
      final jsonString = jsonEncode(serializedData);
      await prefs.setString('family_planning_data', jsonString);
      print('Successfully saved to local storage: ${jsonString.substring(0, min(100, jsonString.length))}...');
    } catch (e) {
      print('Error saving to local storage: $e');
      rethrow;
    }
  }
  
  // Get data from local storage
  Future<FamilyPlanningData?> _getLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('family_planning_data');
      
      if (jsonString == null) {
        return null;
      }
      
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Convert ISO strings back to DateTime objects
      return FamilyPlanningData(
        userId: jsonData['userId'] ?? 'anonymous',
        planningGoal: jsonData['planningGoal'] ?? 'undecided',
        contraceptiveMethodsUsed: List<String>.from(jsonData['contraceptiveMethodsUsed'] ?? []),
        lastPeriodDate: DateTime.parse(jsonData['lastPeriodDate']),
        cycleDuration: jsonData['cycleDuration'] ?? 28,
        periodDates: (jsonData['periodDates'] as List?)
            ?.map((dateStr) => DateTime.parse(dateStr))
            .toList() ?? [],
        pillTakenDates: (jsonData['pillTakenDates'] as List?)
            ?.map((dateStr) => DateTime.parse(dateStr))
            .toList() ?? [],
        injectionDates: (jsonData['injectionDates'] as List?)
            ?.map((dateStr) => DateTime.parse(dateStr))
            .toList() ?? [],
      );
    } catch (e) {
      print('Error getting from local storage: $e');
      return null;
    }
  }
  
  // Calculate fertile days based on last period and cycle length
  List<DateTime> calculateFertileDays(DateTime lastPeriod, int cycleDuration) {
    List<DateTime> fertileDays = [];
    
    // Ovulation typically occurs 14 days before the next period
    int ovulationDay = cycleDuration - 14;
    
    // Fertile window is typically 5 days before ovulation and the day of ovulation
    for (int i = ovulationDay - 5; i <= ovulationDay; i++) {
      fertileDays.add(lastPeriod.add(Duration(days: i)));
    }
    
    return fertileDays;
  }
  
  // AI-enhanced fertility prediction that considers historical data and contraceptive use
  Future<Map<String, dynamic>> getAIEnhancedPredictions() async {
    try {
      final data = await getFamilyPlanningData();
      if (data == null) {
        throw Exception('No data available for AI predictions');
      }
      
      // Get basic predictions first
      final basicFertileDays = calculateFertileDays(data.lastPeriodDate, data.cycleDuration);
      final basicNextPeriods = predictNextPeriods(data.lastPeriodDate, data.cycleDuration, count: 3);
      
      // Enhanced predictions considering historical data
      List<DateTime> enhancedFertileDays = List.from(basicFertileDays);
      List<DateTime> enhancedNextPeriods = List.from(basicNextPeriods);
      
      // Cycle irregularity detection
      String? irregularityMessage;
      int averageCycle = data.cycleDuration;
      bool hasIrregularity = false;
      
      // If we have enough historical period data (at least 3 periods)
      if (data.periodDates.length >= 3) {
        // Sort period dates in ascending order
        final sortedPeriods = List<DateTime>.from(data.periodDates)..sort((a, b) => a.compareTo(b));
        List<int> cycleLengths = [];
        
        for (int i = 1; i < sortedPeriods.length; i++) {
          cycleLengths.add(sortedPeriods[i].difference(sortedPeriods[i-1]).inDays);
        }
        
        // Calculate average cycle length from actual data
        int totalDays = 0;
        int cyclesToCount = 0;
        
        for (int i = 0; i < cycleLengths.length; i++) {
          final difference = cycleLengths[i];
          // Only count reasonable cycle lengths (21-40 days)
          if (difference >= 21 && difference <= 40) {
            totalDays += difference;
            cyclesToCount++;
          }
        }
        
        // If we have valid cycles, use the average cycle length
        if (cyclesToCount > 0) {
          averageCycle = (totalDays / cyclesToCount).round();
          
          // Recalculate predictions with the data-driven cycle length
          enhancedNextPeriods = predictNextPeriods(data.lastPeriodDate, averageCycle, count: 3);
          
          // Calculate ovulation with the new average
          final ovulationDay = averageCycle - 14;
          enhancedFertileDays = [];
          
          // Adjust fertile window based on the new average cycle
          for (int i = ovulationDay - 5; i <= ovulationDay; i++) {
            enhancedFertileDays.add(data.lastPeriodDate.add(Duration(days: i)));
          }
          
          // Detect irregularities in the last 2-3 cycles
          if (cycleLengths.length >= 2) {
            final lastCycle = cycleLengths.last;
            final secondLastCycle = cycleLengths[cycleLengths.length - 2];
            
            // Check if both of the last two cycles are significantly different from average
            if ((lastCycle - averageCycle).abs() > 5 && (secondLastCycle - averageCycle).abs() > 5) {
              if (lastCycle > averageCycle && secondLastCycle > averageCycle) {
                irregularityMessage = "Your last 2 cycles were longer than usual";
                hasIrregularity = true;
              } else if (lastCycle < averageCycle && secondLastCycle < averageCycle) {
                irregularityMessage = "Your last 2 cycles were shorter than usual";
                hasIrregularity = true;
              } else {
                irregularityMessage = "Your recent cycles have been irregular";
                hasIrregularity = true;
              }
            }
            // Check if just the last cycle is very different
            else if ((lastCycle - averageCycle).abs() > 7) {
              if (lastCycle > averageCycle) {
                irregularityMessage = "Your last cycle was longer than usual";
                hasIrregularity = true;
              } else {
                irregularityMessage = "Your last cycle was shorter than usual";
                hasIrregularity = true;
              }
            }
          }
        }
      }
      
      // PMS prediction based on historical data
      DateTime? pmsPredictionStart;
      if (enhancedNextPeriods.isNotEmpty) {
        // PMS typically starts 7-10 days before period
        pmsPredictionStart = enhancedNextPeriods.first.subtract(Duration(days: 7));
      }
      
      // Consider contraceptive methods and adjust predictions
      if (data.contraceptiveMethodsUsed.contains('pill') && data.pillTakenDates.isNotEmpty) {
        // If using pills consistently, reduce fertility window by 1-2 days
        if (_isPillUsedConsistently(data.pillTakenDates)) {
          enhancedFertileDays = enhancedFertileDays.sublist(1); // Reduce fertile window
        }
      }
      
      if (data.contraceptiveMethodsUsed.contains('injection') && data.injectionDates.isNotEmpty) {
        // If recent injection (within last 3 months), significantly reduce fertility
        final mostRecentInjection = data.injectionDates.reduce((a, b) => a.isAfter(b) ? a : b);
        final daysSinceInjection = DateTime.now().difference(mostRecentInjection).inDays;
        
        if (daysSinceInjection < 90) { // Typical injection effectiveness period
          // Mark as very low fertility
          enhancedFertileDays = [];
        }
      }
      
      // Calculate prediction confidence (higher with more historical data)
      double confidenceScore = 0.6; // Base confidence
      
      // Increase confidence with more historical data
      if (data.periodDates.length >= 6) {
        confidenceScore = 0.85;
      } else if (data.periodDates.length >= 3) {
        confidenceScore = 0.75;
      }
      
      // Decrease confidence if cycle lengths are highly variable
      if (data.periodDates.length >= 3) {
        final sortedPeriods = List<DateTime>.from(data.periodDates)..sort((a, b) => a.compareTo(b));
        List<int> cycleLengths = [];
        
        for (int i = 1; i < sortedPeriods.length; i++) {
          cycleLengths.add(sortedPeriods[i].difference(sortedPeriods[i-1]).inDays);
        }
        
        // Calculate standard deviation of cycle lengths
        final mean = cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
        final variance = cycleLengths.map((length) => pow(length - mean, 2)).reduce((a, b) => a + b) / cycleLengths.length;
        final stdDev = sqrt(variance);
        
        // If standard deviation is high, reduce confidence
        if (stdDev > 5) {
          confidenceScore -= 0.15;
          // If we haven't already detected irregularity
          if (!hasIrregularity) {
            irregularityMessage = "Your cycle length varies significantly";
            hasIrregularity = true;
          }
        }
      }
      
      // Check if ovulation might be late this cycle
      bool possibleLateOvulation = false;
      String? ovulationMessage;
      if (data.periodDates.length >= 3) {
        final today = DateTime.now();
        final daysSinceLastPeriod = today.difference(data.lastPeriodDate).inDays;
        
        // If we're past the expected ovulation day but not yet at the next period
        if (daysSinceLastPeriod > averageCycle - 14 && daysSinceLastPeriod < averageCycle) {
          possibleLateOvulation = true;
          ovulationMessage = "Ovulation may have been late this cycle. Want to adjust your fertile window prediction?";
        }
      }
      
      return {
        'enhancedFertileDays': enhancedFertileDays,
        'enhancedNextPeriods': enhancedNextPeriods,
        'confidenceScore': confidenceScore,
        'usingAI': true,
        'averageCycle': averageCycle,
        'irregularityMessage': irregularityMessage,
        'hasIrregularity': hasIrregularity,
        'pmsPredictionStart': pmsPredictionStart?.toIso8601String(),
        'possibleLateOvulation': possibleLateOvulation,
        'ovulationMessage': ovulationMessage,
      };
    } catch (e) {
      print('Error in AI predictions: $e');
      // Fall back to basic predictions
      return {
        'usingAI': false,
      };
    }
  }
  
  // Helper to check if pills are taken consistently
  bool _isPillUsedConsistently(List<DateTime> pillDates) {
    if (pillDates.isEmpty) return false;
    
    // Check last 28 days
    final today = DateTime.now();
    final oneMonthAgo = today.subtract(Duration(days: 28));
    
    // Count pills taken in last 28 days
    final recentPills = pillDates.where((date) => 
      date.isAfter(oneMonthAgo) && date.isBefore(today)
    ).length;
    
    // If at least 24 out of 28 days, consider consistent
    return recentPills >= 24;
  }
  
  // Predict next periods based on last period and cycle length
  List<DateTime> predictNextPeriods(DateTime lastPeriod, int cycleDuration, {int count = 3}) {
    List<DateTime> predictedPeriods = [];
    
    for (int i = 1; i <= count; i++) {
      predictedPeriods.add(lastPeriod.add(Duration(days: cycleDuration * i)));
    }
    
    return predictedPeriods;
  }
  
  // Delete a period date
  Future<void> deletePeriod(DateTime date) async {
    try {
      // First get existing data
      final data = await getFamilyPlanningData();
      if (data == null) {
        throw Exception('No data found to update');
      }
      
      // Remove the period date
      final updatedPeriods = data.periodDates.where((d) => 
        !(d.year == date.year && d.month == date.month && d.day == date.day)
      ).toList();
      
      // Update last period date if needed
      DateTime lastPeriodDate = data.lastPeriodDate;
      if (data.lastPeriodDate.year == date.year && 
          data.lastPeriodDate.month == date.month && 
          data.lastPeriodDate.day == date.day) {
        // Find the most recent period date
        if (updatedPeriods.isNotEmpty) {
          lastPeriodDate = updatedPeriods.reduce((a, b) => a.isAfter(b) ? a : b);
        } else {
          // If no periods left, set to today minus 14 days as default
          lastPeriodDate = DateTime.now().subtract(Duration(days: 14));
        }
      }
      
      // Create updated data
      final updatedData = FamilyPlanningData(
        userId: data.userId,
        planningGoal: data.planningGoal,
        contraceptiveMethodsUsed: data.contraceptiveMethodsUsed,
        lastPeriodDate: lastPeriodDate,
        cycleDuration: data.cycleDuration,
        periodDates: updatedPeriods,
        pillTakenDates: data.pillTakenDates,
        injectionDates: data.injectionDates,
      );
      
      // Save the updated data
      await saveFamilyPlanningData(updatedData);
    } catch (e) {
      print('Error deleting period: $e');
      rethrow;
    }
  }
  
  // Delete a pill taken date
  Future<void> deletePill(DateTime date) async {
    try {
      // First get existing data
      final data = await getFamilyPlanningData();
      if (data == null) {
        throw Exception('No data found to update');
      }
      
      // Remove the pill date
      final updatedPills = data.pillTakenDates.where((d) => 
        !(d.year == date.year && d.month == date.month && d.day == date.day)
      ).toList();
      
      // Create updated data
      final updatedData = FamilyPlanningData(
        userId: data.userId,
        planningGoal: data.planningGoal,
        contraceptiveMethodsUsed: data.contraceptiveMethodsUsed,
        lastPeriodDate: data.lastPeriodDate,
        cycleDuration: data.cycleDuration,
        periodDates: data.periodDates,
        pillTakenDates: updatedPills,
        injectionDates: data.injectionDates,
      );
      
      // Save the updated data
      await saveFamilyPlanningData(updatedData);
    } catch (e) {
      print('Error deleting pill: $e');
      rethrow;
    }
  }
  
  // Delete an injection date
  Future<void> deleteInjection(DateTime date) async {
    try {
      // First get existing data
      final data = await getFamilyPlanningData();
      if (data == null) {
        throw Exception('No data found to update');
      }
      
      // Remove the injection date
      final updatedInjections = data.injectionDates.where((d) => 
        !(d.year == date.year && d.month == date.month && d.day == date.day)
      ).toList();
      
      // Create updated data
      final updatedData = FamilyPlanningData(
        userId: data.userId,
        planningGoal: data.planningGoal,
        contraceptiveMethodsUsed: data.contraceptiveMethodsUsed,
        lastPeriodDate: data.lastPeriodDate,
        cycleDuration: data.cycleDuration,
        periodDates: data.periodDates,
        pillTakenDates: data.pillTakenDates,
        injectionDates: updatedInjections,
      );
      
      // Save the updated data
      await saveFamilyPlanningData(updatedData);
    } catch (e) {
      print('Error deleting injection: $e');
      rethrow;
    }
  }
} 
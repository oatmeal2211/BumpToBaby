import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bumptobaby/models/family_planning.dart';
import 'package:bumptobaby/services/family_planning_service.dart';
import 'package:bumptobaby/widgets/family_planning_widgets.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class FamilyPlanningScreen extends StatefulWidget {
  const FamilyPlanningScreen({Key? key}) : super(key: key);

  @override
  _FamilyPlanningScreenState createState() => _FamilyPlanningScreenState();
}

class _FamilyPlanningScreenState extends State<FamilyPlanningScreen> with SingleTickerProviderStateMixin {
  final FamilyPlanningService _planningService = FamilyPlanningService();
  late TabController _tabController;
  
  // User data
  String _planningGoal = 'undecided';
  DateTime _lastPeriodDate = DateTime.now().subtract(Duration(days: 14));
  int _cycleDuration = 28;
  List<DateTime> _periodDates = [];
  List<DateTime> _pillTakenDates = [];
  
  // AI-enhanced predictions
  List<DateTime> _enhancedFertileDays = [];
  List<DateTime> _enhancedNextPeriods = [];
  double _predictionConfidence = 0.6;
  bool _usingAI = false;
  String? _irregularityMessage;
  bool _hasIrregularity = false;
  DateTime? _pmsPredictionStart;
  bool _possibleLateOvulation = false;
  String? _ovulationMessage;
  
  // UI state
  bool _isLoading = true;
  bool _isFirstEntry = true;  // Track if this is the first time user opens the screen
  bool _hasLoggedPeriod = false;  // Track if user has logged any period data
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _isSaving = false;
  int _selectedTabIndex = 0; // Track selected tab for educational content
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final data = await _planningService.getFamilyPlanningData();
      
      if (data != null) {
        setState(() {
          _planningGoal = data.planningGoal;
          _lastPeriodDate = data.lastPeriodDate;
          _cycleDuration = data.cycleDuration;
          _periodDates = data.periodDates;
          _pillTakenDates = data.pillTakenDates;
          _hasLoggedPeriod = true;
          _isFirstEntry = false;
        });
        
        // Load AI-enhanced predictions
        _loadAIPredictions();
      } else {
        setState(() {
          _isFirstEntry = true;
          _hasLoggedPeriod = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Load AI-enhanced predictions
  Future<void> _loadAIPredictions() async {
    try {
      final predictions = await _planningService.getAIEnhancedPredictions();
      
      if (predictions['usingAI'] == true) {
        setState(() {
          _enhancedFertileDays = predictions['enhancedFertileDays'];
          _enhancedNextPeriods = predictions['enhancedNextPeriods'];
          _predictionConfidence = predictions['confidenceScore'];
          _usingAI = true;
          _irregularityMessage = predictions['irregularityMessage'];
          _hasIrregularity = predictions['hasIrregularity'] ?? false;
          _possibleLateOvulation = predictions['possibleLateOvulation'] ?? false;
          _ovulationMessage = predictions['ovulationMessage'];
          
          // Parse PMS prediction start date if available
          if (predictions['pmsPredictionStart'] != null) {
            _pmsPredictionStart = DateTime.parse(predictions['pmsPredictionStart']);
          }
        });
      } else {
        // Fallback to basic predictions
        setState(() {
          _enhancedFertileDays = _planningService.calculateFertileDays(_lastPeriodDate, _cycleDuration);
          _enhancedNextPeriods = _planningService.predictNextPeriods(_lastPeriodDate, _cycleDuration);
          _predictionConfidence = 0.6;
          _usingAI = false;
        });
      }
    } catch (e) {
      print('Error loading AI predictions: $e');
      // Use basic predictions as fallback
      setState(() {
        _enhancedFertileDays = _planningService.calculateFertileDays(_lastPeriodDate, _cycleDuration);
        _enhancedNextPeriods = _planningService.predictNextPeriods(_lastPeriodDate, _cycleDuration);
        _predictionConfidence = 0.6;
        _usingAI = false;
      });
    }
  }
  
  Future<void> _savePlanningGoal(String goal) async {
    if (_isSaving) return; // Prevent multiple simultaneous saves
    
    setState(() {
      _isSaving = true;
      _planningGoal = goal;
    });
    
    try {
      if (_isFirstEntry) {
        // Create new data
        final data = FamilyPlanningData(
          userId: _planningService.currentUserId ?? 'anonymous',
          planningGoal: goal,
          lastPeriodDate: _lastPeriodDate,
        );
        
        await _planningService.saveFamilyPlanningData(data);
        if (mounted) {
          setState(() {
            _isFirstEntry = false;
          });
        }
      } else {
        // Update existing data
        await _planningService.updatePlanningGoal(goal);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Planning goal updated successfully')),
        );
      }
    } catch (e) {
      // Handle error
      print('Error saving planning goal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save your selection. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
  
  Future<void> _recordPeriod(DateTime date) async {
    if (_isSaving) return; // Prevent multiple simultaneous saves
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // Update local state first for immediate UI feedback
      setState(() {
        _lastPeriodDate = date;
        if (!_periodDates.any((d) => 
          d.year == date.year && 
          d.month == date.month && 
          d.day == date.day
        )) {
          _periodDates = [..._periodDates, date];
          _hasLoggedPeriod = true;  // User has now logged a period
        }
      });
      
      // Create data object with all current state
      final data = FamilyPlanningData(
        userId: _planningService.currentUserId ?? 'anonymous',
        planningGoal: _planningGoal,
        lastPeriodDate: date,
        cycleDuration: _cycleDuration,
        periodDates: _periodDates,
        pillTakenDates: _pillTakenDates,
      );
      
      // Save all data at once
      await _planningService.saveFamilyPlanningData(data);
      
      // Force a rebuild of the UI
      if (mounted) {
        setState(() {}); // Trigger UI update
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Period recorded successfully')),
        );
        
        // Debug info
        print('Period recorded for ${DateFormat('MMM d, yyyy').format(date)}');
      }
    } catch (e) {
      print('Error recording period: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record period. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
  
  Future<void> _recordPillTaken(DateTime date) async {
    if (_isSaving) return; // Prevent multiple simultaneous saves
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // Update local state first for immediate UI feedback
      setState(() {
        if (!_pillTakenDates.any((d) => 
          d.year == date.year && 
          d.month == date.month && 
          d.day == date.day
        )) {
          _pillTakenDates = [..._pillTakenDates, date];
        }
      });
      
      // Create data object with all current state
      final data = FamilyPlanningData(
        userId: _planningService.currentUserId ?? 'anonymous',
        planningGoal: _planningGoal,
        lastPeriodDate: _lastPeriodDate,
        cycleDuration: _cycleDuration,
        periodDates: _periodDates,
        pillTakenDates: _pillTakenDates,
      );
      
      // Save all data at once
      await _planningService.saveFamilyPlanningData(data);
      
      // Force a rebuild of the UI
      if (mounted) {
        setState(() {}); // Trigger UI update
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pill recorded successfully')),
        );
        
        // Debug info
        print('Pill recorded for ${DateFormat('MMM d, yyyy').format(date)}');
      }
    } catch (e) {
      print('Error recording pill: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record pill. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
  
  Future<void> _recordInjection(DateTime date) async {
    if (_isSaving) return; // Prevent multiple simultaneous saves
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // Update local state first for immediate UI feedback
      setState(() {
        if (!_pillTakenDates.any((d) => 
          d.year == date.year && 
          d.month == date.month && 
          d.day == date.day
        )) {
          _pillTakenDates = [..._pillTakenDates, date];
        }
      });
      
      // Create data object with all current state
      final data = FamilyPlanningData(
        userId: _planningService.currentUserId ?? 'anonymous',
        planningGoal: _planningGoal,
        lastPeriodDate: _lastPeriodDate,
        cycleDuration: _cycleDuration,
        periodDates: _periodDates,
        pillTakenDates: _pillTakenDates,
      );
      
      // Save all data at once
      await _planningService.saveFamilyPlanningData(data);
      
      // Force a rebuild of the UI
      if (mounted) {
        setState(() {}); // Trigger UI update
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Injection recorded successfully')),
        );
        
        // Debug info
        print('Injection recorded for ${DateFormat('MMM d, yyyy').format(date)}');
      }
    } catch (e) {
      print('Error recording injection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record injection. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
  
  bool _isPeriodDay(DateTime day) {
    return _periodDates.any((date) => 
      date.year == day.year && 
      date.month == day.month && 
      date.day == day.day
    );
  }
  
  bool _isPillTakenDay(DateTime day) {
    return _pillTakenDates.any((date) => 
      date.year == day.year && 
      date.month == day.month && 
      date.day == day.day
    );
  }
  
  bool _isInjectionDay(DateTime day) {
    return _pillTakenDates.any((date) => 
      date.year == day.year && 
      date.month == day.month && 
      date.day == day.day
    );
  }
  
  bool _isFertileDay(DateTime day) {
    // Use AI-enhanced fertile days if available, otherwise fall back to basic calculation
    final fertileDays = _usingAI ? _enhancedFertileDays : _planningService.calculateFertileDays(_lastPeriodDate, _cycleDuration);
    
    return fertileDays.any((date) => 
      date.year == day.year && 
      date.month == day.month && 
      date.day == day.day
    );
  }
  
  // Check if a day is in the PMS window
  bool _isPMSDay(DateTime day) {
    if (_pmsPredictionStart == null || _enhancedNextPeriods.isEmpty) return false;
    
    final nextPeriod = _enhancedNextPeriods.first;
    
    // PMS window is between PMS start and period start
    return !day.isBefore(_pmsPredictionStart!) && 
           day.isBefore(nextPeriod) && 
           !isSameDay(day, nextPeriod);
  }
  
  void _showDayActionSheet(DateTime day) {
    final bool isPeriod = _isPeriodDay(day);
    final bool isPill = _isPillTakenDay(day);
    final bool isFertile = _isFertileDay(day);
    
    // Get cycle phase information for this day
    final phaseInfo = CyclePhase.getPhaseInfo(
      day, 
      _lastPeriodDate, 
      _enhancedNextPeriods.isNotEmpty ? _enhancedNextPeriods : _planningService.predictNextPeriods(_lastPeriodDate, _cycleDuration),
      _enhancedFertileDays.isNotEmpty ? _enhancedFertileDays : _planningService.calculateFertileDays(_lastPeriodDate, _cycleDuration)
    );
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('MMMM d, yyyy').format(day),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              // Cycle phase information
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(phaseInfo['color']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(phaseInfo['color']).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.circle, size: 12, color: Color(phaseInfo['color'])),
                        SizedBox(width: 8),
                        Text(
                          phaseInfo['phaseName'],
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Color(phaseInfo['color']),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      phaseInfo['description'],
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.withOpacity(0.2),
                  child: Icon(
                    isPeriod ? Icons.check_circle : Icons.calendar_today, 
                    color: Colors.red
                  ),
                ),
                title: Text(isPeriod ? 'Remove Period Record' : 'Record Period'),
                onTap: () {
                  Navigator.pop(context);
                  if (isPeriod) {
                    _deletePeriod(day);
                  } else {
                    _recordPeriod(day);
                  }
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.withOpacity(0.2),
                  child: Icon(
                    isPill ? Icons.check_circle : Icons.medication, 
                    color: Colors.orange
                  ),
                ),
                title: Text(isPill ? 'Remove Pill Record' : 'Record Pill Taken'),
                onTap: () {
                  Navigator.pop(context);
                  if (isPill) {
                    _deletePill(day);
                  } else {
                    _recordPillTaken(day);
                  }
                },
              ),
              Divider(),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.2),
                  child: Icon(Icons.edit, color: Colors.blue),
                ),
                title: Text('Update Family Planning Goal'),
                onTap: () {
                  Navigator.pop(context);
                  _showPlanningGoalDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Delete a period record
  Future<void> _deletePeriod(DateTime date) async {
    if (_isSaving) return; // Prevent multiple simultaneous operations
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // Update local state first for immediate UI feedback
      setState(() {
        _periodDates = _periodDates.where((d) => 
          !(d.year == date.year && 
            d.month == date.month && 
            d.day == date.day)
        ).toList();
        
        // If this was the last period date, we need to update the last period date
        if (_lastPeriodDate.year == date.year && 
            _lastPeriodDate.month == date.month && 
            _lastPeriodDate.day == date.day) {
          // Find the most recent period date
          if (_periodDates.isNotEmpty) {
            _lastPeriodDate = _periodDates.reduce((a, b) => a.isAfter(b) ? a : b);
          } else {
            // If no periods left, set to today minus 14 days as default
            _lastPeriodDate = DateTime.now().subtract(Duration(days: 14));
          }
        }
      });
      
      // Create data object with all current state
      final data = FamilyPlanningData(
        userId: _planningService.currentUserId ?? 'anonymous',
        planningGoal: _planningGoal,
        lastPeriodDate: _lastPeriodDate,
        cycleDuration: _cycleDuration,
        periodDates: _periodDates,
        pillTakenDates: _pillTakenDates,
      );
      
      // Save all data at once
      await _planningService.saveFamilyPlanningData(data);
      
      // Force a rebuild of the UI
      if (mounted) {
        setState(() {}); // Trigger UI update
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Period record deleted successfully')),
        );
        
        // Debug info
        print('Period deleted for ${DateFormat('MMM d, yyyy').format(date)}');
      }
    } catch (e) {
      print('Error deleting period: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete period record. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
  
  // Delete a pill record
  Future<void> _deletePill(DateTime date) async {
    if (_isSaving) return; // Prevent multiple simultaneous operations
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // Update local state first for immediate UI feedback
      setState(() {
        _pillTakenDates = _pillTakenDates.where((d) => 
          !(d.year == date.year && 
            d.month == date.month && 
            d.day == date.day)
        ).toList();
      });
      
      // Create data object with all current state
      final data = FamilyPlanningData(
        userId: _planningService.currentUserId ?? 'anonymous',
        planningGoal: _planningGoal,
        lastPeriodDate: _lastPeriodDate,
        cycleDuration: _cycleDuration,
        periodDates: _periodDates,
        pillTakenDates: _pillTakenDates,
      );
      
      // Save all data at once
      await _planningService.saveFamilyPlanningData(data);
      
      // Force a rebuild of the UI
      if (mounted) {
        setState(() {}); // Trigger UI update
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pill record deleted successfully')),
        );
        
        // Debug info
        print('Pill deleted for ${DateFormat('MMM d, yyyy').format(date)}');
      }
    } catch (e) {
      print('Error deleting pill: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete pill record. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
  
  // Delete an injection record
  Future<void> _deleteInjection(DateTime date) async {
    if (_isSaving) return; // Prevent multiple simultaneous operations
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // Update local state first for immediate UI feedback
      setState(() {
        _pillTakenDates = _pillTakenDates.where((d) => 
          !(d.year == date.year && 
            d.month == date.month && 
            d.day == date.day)
        ).toList();
      });
      
      // Create data object with all current state
      final data = FamilyPlanningData(
        userId: _planningService.currentUserId ?? 'anonymous',
        planningGoal: _planningGoal,
        lastPeriodDate: _lastPeriodDate,
        cycleDuration: _cycleDuration,
        periodDates: _periodDates,
        pillTakenDates: _pillTakenDates,
      );
      
      // Save all data at once
      await _planningService.saveFamilyPlanningData(data);
      
      // Force a rebuild of the UI
      if (mounted) {
        setState(() {}); // Trigger UI update
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Injection record deleted successfully')),
        );
        
        // Debug info
        print('Injection deleted for ${DateFormat('MMM d, yyyy').format(date)}');
      }
    } catch (e) {
      print('Error deleting injection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete injection record. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
  
  // Show dialog to update planning goal
  void _showPlanningGoalDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Update Family Planning Goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlanningGoalSelector(
                selectedGoal: _planningGoal,
                onGoalSelected: (goal) {
                  Navigator.pop(context);
                  _savePlanningGoal(goal);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
  
  // Debug function to print the current state
  void _debugData() {
    print('===== FAMILY PLANNING DEBUG =====');
    print('Planning Goal: $_planningGoal');
    print('Last Period: ${_lastPeriodDate.toString()}');
    print('Cycle Duration: $_cycleDuration days');
    print('Period Dates: ${_periodDates.map((d) => d.toString()).join(', ')}');
    print('Pill Dates: ${_pillTakenDates.map((d) => d.toString()).join(', ')}');
    print('================================');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Debug info printed to console')),
    );
  }
  
  Widget _buildInitialSetupView() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to Family Planning',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF8AAE),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Let\'s set up your family planning profile to provide personalized recommendations.',
            style: GoogleFonts.poppins(
              fontSize: 16,
            ),
          ),
          SizedBox(height: 24),
          PlanningGoalSelector(
            selectedGoal: _planningGoal,
            onGoalSelected: _savePlanningGoal,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isFirstEntry = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFF8AAE),
              minimumSize: Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Continue',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContraceptiveOptionsTab() {
    // For users who want more children, show conception tips
    if (_planningGoal == 'want_more_children') {
      return _buildConceptionTipsTab();
    }
    
    // For undecided users, show a balanced view with both options
    if (_planningGoal == 'undecided') {
      return _buildUndecidedOptionsTab();
    }
    
    List<Map<String, dynamic>> contraceptiveOptions = [];
    
    // Different options based on planning goal
    if (_planningGoal == 'no_more_children') {
      contraceptiveOptions = [
        {
          'title': 'Hormonal IUD',
          'description': 'A small T-shaped device inserted into the uterus that releases hormones.',
          'effectiveness': '99% effective',
          'icon': Icons.health_and_safety,
          'color': Colors.teal,
          'gender': 'Female',
          'details': 'Lasts 3-7 years depending on type. May reduce period pain and bleeding. Requires insertion by a healthcare provider.'
        },
        {
          'title': 'Copper IUD',
          'description': 'A small T-shaped device inserted into the uterus that doesn\'t contain hormones.',
          'effectiveness': '99% effective',
          'color': Colors.amber,
          'icon': Icons.device_thermostat,
          'gender': 'Female',
          'details': 'Can last up to 10-12 years. May cause heavier periods. Immediately reversible upon removal.'
        },
        {
          'title': 'Female Sterilization',
          'description': 'Permanent surgical procedure that blocks the fallopian tubes.',
          'effectiveness': '99% effective',
          'color': Colors.purple,
          'icon': Icons.medical_services,
          'gender': 'Female',
          'details': 'Tubal ligation or "getting your tubes tied" is a permanent method. The procedure can be done laparoscopically with minimal recovery time.'
        },
        {
          'title': 'Vasectomy',
          'description': 'Permanent surgical procedure that blocks sperm from leaving the body.',
          'effectiveness': '99% effective',
          'color': Colors.blue,
          'icon': Icons.medical_services,
          'gender': 'Male',
          'details': 'A minor outpatient procedure with quick recovery. Takes about 3 months to be fully effective. More simple and less invasive than female sterilization.'
        },
        {
          'title': 'Hormonal Implant',
          'description': 'A small rod inserted under the skin of the upper arm that releases hormones.',
          'effectiveness': '99% effective',
          'color': Colors.pink,
          'icon': Icons.medication,
          'gender': 'Female',
          'details': 'Lasts up to 3-5 years. Can be removed at any time with quick return to fertility. May cause irregular bleeding.'
        },
        {
          'title': 'Male Condoms',
          'description': 'Barrier method that also protects against STIs.',
          'effectiveness': '85% effective',
          'color': Colors.indigo,
          'icon': Icons.health_and_safety,
          'gender': 'Male',
          'details': 'No prescription needed. Can be used alongside other methods for extra protection. Available in different materials for those with latex allergies.'
        },
      ];
    } else {
      contraceptiveOptions = [
        {
          'title': 'Birth Control Pills',
          'description': 'Daily pill containing hormones that prevent pregnancy.',
          'effectiveness': '91% effective',
          'icon': Icons.medication,
          'color': Colors.orange,
        },
        {
          'title': 'Contraceptive Injection',
          'description': 'Hormone injection given every 3 months.',
          'effectiveness': '94% effective',
          'color': Colors.purple,
          'icon': Icons.vaccines,
        },
        {
          'title': 'Condoms',
          'description': 'Barrier method that also protects against STIs.',
          'effectiveness': '85% effective',
          'color': Colors.blue,
          'icon': Icons.health_and_safety,
        },
      ];
    }
    
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Contraceptive Options',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                icon: Icon(Icons.edit),
                label: Text('Update Goal'),
                onPressed: _showPlanningGoalDialog,
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            _planningGoal == 'want_more_children'
                ? 'Temporary methods to help you plan your next pregnancy'
                : _planningGoal == 'no_more_children'
                    ? 'Long-term and permanent options for those who don\'t want more children'
                    : 'Options to consider while you decide on your family planning goals',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: contraceptiveOptions.length,
              itemBuilder: (context, index) {
                final option = contraceptiveOptions[index];
                return ContraceptiveOptionCard(
                  title: option['title'],
                  description: option['description'],
                  effectiveness: option['effectiveness'],
                  icon: option['icon'],
                  color: option['color'],
                  gender: option['gender'] ?? '',
                  onTap: () {
                    // Show detailed information
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (context) {
                        return Container(
                          padding: EdgeInsets.all(24),
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: option['color'].withOpacity(0.2),
                                    child: Icon(option['icon'], color: option['color']),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          option['title'],
                                          style: GoogleFonts.poppins(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (option['gender'] != null && option['gender'].isNotEmpty)
                                          Container(
                                            margin: EdgeInsets.only(top: 4),
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: option['gender'] == 'Female' ? Colors.pink.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              option['gender'],
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: option['gender'] == 'Female' ? Colors.pink : Colors.blue,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: option['color'].withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Effectiveness: ${option['effectiveness']}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: option['color'],
                                  ),
                                ),
                              ),
                              SizedBox(height: 20),
                              Text(
                                'Description',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                option['description'],
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 16),
                              if (option['details'] != null) ...[
                                Text(
                                  'Details',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  option['details'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  // New tab for undecided users with balanced information
  Widget _buildUndecidedOptionsTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reproductive Health',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                icon: Icon(Icons.edit),
                label: Text('Update Goal'),
                onPressed: _showPlanningGoalDialog,
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Information to help you make informed decisions about your reproductive health',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _buildInfoCard(
                  'Understanding Your Cycle',
                  'Your menstrual cycle is more than just your period. Understanding it can help with family planning decisions.',
                  Icons.autorenew,
                  Colors.teal,
                  [
                    'The average cycle is 28 days, but can range from 21-35 days',
                    'Ovulation typically occurs 12-14 days before your next period',
                    'Tracking your cycle helps identify patterns and irregularities',
                    'Symptoms like mood changes and cramps can vary throughout your cycle'
                  ],
                ),
                SizedBox(height: 16),
                _buildInfoCard(
                  'Fertility Awareness',
                  'Knowing when you\'re most likely to conceive can help whether you\'re trying to get pregnant or not.',
                  Icons.calendar_today,
                  Colors.green,
                  [
                    'The "fertile window" is typically 6 days ending with ovulation',
                    'Fertility signs include changes in cervical mucus and basal body temperature',
                    'Tracking these signs can help predict your most fertile days',
                    'This knowledge is useful regardless of your family planning goals'
                  ],
                ),
                SizedBox(height: 16),
                _buildInfoCard(
                  'Contraceptive Basics',
                  'Different methods work in different ways and have varying effectiveness rates.',
                  Icons.health_and_safety,
                  Colors.blue,
                  [
                    'Barrier methods (condoms) prevent sperm from reaching the egg',
                    'Hormonal methods (pills, patches) prevent ovulation',
                    'IUDs provide long-term protection without daily maintenance',
                    'Emergency contraception is available if other methods fail'
                  ],
                ),
                SizedBox(height: 16),
                _buildInfoCard(
                  'Preconception Health',
                  'Preparing your body for pregnancy can improve outcomes if you decide to have children.',
                  Icons.favorite,
                  Colors.red,
                  [
                    'Taking folic acid before conception reduces birth defect risks',
                    'Maintaining a healthy weight improves fertility and pregnancy outcomes',
                    'Avoiding alcohol, tobacco, and certain medications is recommended',
                    'Regular check-ups can identify and address potential issues'
                  ],
                ),
                SizedBox(height: 16),
                _buildInfoCard(
                  'Making Your Decision',
                  'Take time to consider your options and talk with healthcare providers.',
                  Icons.psychology,
                  Colors.purple,
                  [
                    'Consider your life goals, relationship status, and financial situation',
                    'Discuss options with your partner if applicable',
                    'Consult healthcare providers for personalized advice',
                    'Remember that decisions can be revisited as circumstances change'
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoCard(String title, String subtitle, IconData icon, Color color, List<String> bulletPoints) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.2),
                  child: Icon(icon, color: color),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 12),
            ...bulletPoints.map((point) => Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: 8, color: color),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      point,
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }
  
  // New tab for conception tips for those who want more children
  Widget _buildConceptionTipsTab() {
    // Show different content based on planning goal
    if (_planningGoal == 'want_more_children') {
      return _buildConceptionPlanningView();
    } else if (_planningGoal == 'no_more_children') {
      return _buildContraceptionPlanningView();
    } else {
      return _buildUndecidedPlanningView();
    }
  }
  
  // View for users who want more children
  Widget _buildConceptionPlanningView() {
    final fertileDays = _hasLoggedPeriod ? 
      (_usingAI ? _enhancedFertileDays : _planningService.calculateFertileDays(_lastPeriodDate, _cycleDuration)) : 
      <DateTime>[];
    
    final nextPeriods = _hasLoggedPeriod ? 
      (_usingAI ? _enhancedNextPeriods : _planningService.predictNextPeriods(_lastPeriodDate, _cycleDuration)) : 
      <DateTime>[];
    
    // Calculate estimated ovulation day
    final ovulationDay = DateTime(
      _lastPeriodDate.year,
      _lastPeriodDate.month,
      _lastPeriodDate.day + (_cycleDuration - 14)
    );
    
    return Padding(
      padding: EdgeInsets.all(20),
      child: ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Conception Planning',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF8AAE),
                  ),
                ),
              ),
              TextButton.icon(
                icon: Icon(Icons.edit, color: Color(0xFFFF8AAE)),
                label: Text(
                  'Update Goal',
                  style: GoogleFonts.poppins(
                    color: Color(0xFFFF8AAE),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: _showPlanningGoalDialog,
              ),
            ],
          ),
          SizedBox(height: 16),
          Card(
            elevation: 4,
            shadowColor: Color(0xFFFF8AAE).withOpacity(0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFF7ED957).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.favorite, color: Color(0xFF7ED957), size: 24),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Your Fertility Window',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  if (fertileDays.isNotEmpty)
                    _buildInfoRow(
                      'Most fertile days',
                      '${DateFormat('MMM d').format(fertileDays.first)} - ${DateFormat('MMM d').format(fertileDays.last)}',
                      Icons.calendar_today,
                      Color(0xFF7ED957),
                    ),
                  SizedBox(height: 12),
                  _buildInfoRow(
                    'Estimated ovulation',
                    '${DateFormat('MMM d').format(ovulationDay)}',
                    Icons.star,
                    Color(0xFF7ED957),
                  ),
                  SizedBox(height: 12),
                  _buildInfoRow(
                    'Next period',
                    nextPeriods.isNotEmpty ? DateFormat('MMM d').format(nextPeriods.first) : "Unknown",
                    Icons.event,
                    Color(0xFFFF5C8A),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.tips_and_updates, color: Color(0xFF6C9FFF), size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'For the best chances of conception, try to have intercourse every 1-2 days during your fertile window.',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Color(0xFF555555),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Conception Tips',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF8AAE),
            ),
          ),
          SizedBox(height: 12),
          _buildConceptionTipCard(
            'Track Your Cervical Mucus',
            'It becomes clear and stretchy like egg whites during your most fertile days.',
            Icons.opacity,
            Color(0xFF6C9FFF),
          ),
          SizedBox(height: 12),
          _buildConceptionTipCard(
            'Maintain a Healthy Diet',
            'Include foods rich in folic acid, iron, and antioxidants to improve egg quality.',
            Icons.restaurant,
            Color(0xFFFF9D6C),
          ),
          SizedBox(height: 12),
          _buildConceptionTipCard(
            'Manage Stress Levels',
            'Practice yoga, meditation, or other relaxation techniques to reduce stress hormones.',
            Icons.spa,
            Color(0xFFAA6DE0),
          ),
          SizedBox(height: 12),
          _buildConceptionTipCard(
            'Time Intercourse Correctly',
            'Focus on the 5 days before ovulation and the day of ovulation itself.',
            Icons.schedule,
            Color(0xFF7ED957),
          ),
          SizedBox(height: 12),
          _buildConceptionTipCard(
            'Consider Prenatal Vitamins',
            'Start taking prenatal vitamins with folic acid at least 3 months before trying to conceive.',
            Icons.medication,
            Color(0xFFFF5C8A),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
  
  // View for users who don't want more children
  Widget _buildContraceptionPlanningView() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Contraception Planning',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF8AAE),
                  ),
                ),
              ),
              TextButton.icon(
                icon: Icon(Icons.edit, color: Color(0xFFFF8AAE)),
                label: Text(
                  'Update Goal',
                  style: GoogleFonts.poppins(
                    color: Color(0xFFFF8AAE),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: _showPlanningGoalDialog,
              ),
            ],
          ),
          SizedBox(height: 16),
          Card(
            elevation: 4,
            shadowColor: Color(0xFFFF8AAE).withOpacity(0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFF6C9FFF).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.shield, color: Color(0xFF6C9FFF), size: 24),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Contraception Effectiveness',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildEffectivenessBar(
                    'Hormonal IUD',
                    0.99,
                    Color(0xFF7ED957),
                  ),
                  SizedBox(height: 12),
                  _buildEffectivenessBar(
                    'Implant',
                    0.99,
                    Color(0xFF7ED957),
                  ),
                  SizedBox(height: 12),
                  _buildEffectivenessBar(
                    'Birth Control Pills',
                    0.91,
                    Color(0xFFFF9D6C),
                  ),
                  SizedBox(height: 12),
                  _buildEffectivenessBar(
                    'Condoms',
                    0.85,
                    Color(0xFFFF9D6C),
                  ),
                  SizedBox(height: 12),
                  _buildEffectivenessBar(
                    'Fertility Awareness',
                    0.76,
                    Color(0xFFFF5C8A),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF6C9FFF), size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Effectiveness rates shown are with typical use. Perfect use rates may be higher.',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Color(0xFF555555),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Recommended Methods',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF8AAE),
            ),
          ),
          SizedBox(height: 12),
          _buildContraceptionMethodCard(
            'Long-Acting Reversible Contraception',
            'IUDs and implants provide the highest effectiveness with minimal maintenance.',
            Icons.watch_later,
            Color(0xFF6C9FFF),
          ),
          SizedBox(height: 12),
          _buildContraceptionMethodCard(
            'Consider Permanent Options',
            "If you're certain you don't want more children, vasectomy or tubal ligation may be right for you.",
            Icons.medical_services,
            Color(0xFF7ED957),
          ),
          SizedBox(height: 12),
          _buildContraceptionMethodCard(
            'Hormonal Methods',
            'Pills, patches, and rings can be good options with regular, consistent use.',
            Icons.medication,
            Color(0xFFFF9D6C),
          ),
          SizedBox(height: 12),
          _buildContraceptionMethodCard(
            'Barrier Methods',
            'Condoms provide protection against STIs in addition to pregnancy prevention.',
            Icons.security,
            Color(0xFFAA6DE0),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
  
  // View for undecided users
  Widget _buildUndecidedPlanningView() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Family Planning',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF8AAE),
                  ),
                ),
              ),
              TextButton.icon(
                icon: Icon(Icons.edit, color: Color(0xFFFF8AAE)),
                label: Text(
                  'Update Goal',
                  style: GoogleFonts.poppins(
                    color: Color(0xFFFF8AAE),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: _showPlanningGoalDialog,
              ),
            ],
          ),
          SizedBox(height: 16),
          Card(
            elevation: 4,
            shadowColor: Color(0xFFFF8AAE).withOpacity(0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFFAA6DE0).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.psychology, color: Color(0xFFAA6DE0), size: 24),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Making Your Decision',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    "It's normal to feel uncertain about your family planning goals. Take your time to consider what's right for you and your family.",
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Color(0xFF555555),
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Questions to consider:',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        SizedBox(height: 8),
                        _buildQuestionItem('How do children fit into your life vision?'),
                        _buildQuestionItem('What are your financial considerations?'),
                        _buildQuestionItem('How do you and your partner feel about parenting?'),
                        _buildQuestionItem('What support systems do you have available?'),
                        _buildQuestionItem('What are your career and personal goals?'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Helpful Resources',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF8AAE),
            ),
          ),
          SizedBox(height: 12),
          _buildResourceCard(
            'Family Planning Counseling',
            'Professional counselors can help you explore your feelings and options.',
            Icons.support_agent,
            Color(0xFF6C9FFF),
          ),
          SizedBox(height: 12),
          _buildResourceCard(
            'Decision-Making Tools',
            'Structured exercises can help clarify your values and priorities.',
            Icons.checklist,
            Color(0xFF7ED957),
          ),
          SizedBox(height: 12),
          _buildResourceCard(
            'Financial Planning',
            'Understanding the costs of different family planning choices.',
            Icons.account_balance,
            Color(0xFFFF9D6C),
          ),
          SizedBox(height: 12),
          _buildResourceCard(
            'Support Groups',
            'Connect with others facing similar decisions and challenges.',
            Icons.people,
            Color(0xFFAA6DE0),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
  
  Widget _buildQuestionItem(String question) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_right, color: Color(0xFFAA6DE0), size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              question,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Color(0xFF555555),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildConceptionTipCard(String title, String description, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Color(0xFF555555),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildContraceptionMethodCard(String title, String description, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Color(0xFF555555),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildResourceCard(String title, String description, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Color(0xFF555555),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEffectivenessBar(String method, double effectiveness, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              method,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333),
              ),
            ),
            Text(
              '${(effectiveness * 100).toInt()}%',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Color(0xFFEEEEEE),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Container(
                width: MediaQuery.of(context).size.width * 0.5 * effectiveness,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: color,
          ),
        ),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Color(0xFF666666),
              ),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildFertileDaysTab() {
    // Use AI-enhanced predictions if available
    final fertileDays = _hasLoggedPeriod ? 
      (_usingAI ? _enhancedFertileDays : _planningService.calculateFertileDays(_lastPeriodDate, _cycleDuration)) : 
      <DateTime>[];
    
    final nextPeriods = _hasLoggedPeriod ? 
      (_usingAI ? _enhancedNextPeriods : _planningService.predictNextPeriods(_lastPeriodDate, _cycleDuration)) : 
      <DateTime>[];
    
    return Padding(
      padding: EdgeInsets.all(20),
      child: ListView(
        children: [
          Text(
            'Cycle Sync Calendar',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF8AAE),
            ),
          ),
          SizedBox(height: 16),
          if (_hasLoggedPeriod) 
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_usingAI)
                  _buildAIPredictionBadge(),
                _buildEnhancedTrackingSummary(
                  lastPeriod: _lastPeriodDate,
                  fertileDays: fertileDays,
                  nextPeriod: nextPeriods.isNotEmpty ? nextPeriods.first : null,
                  pillsTaken: _pillTakenDates.where((date) => 
                    date.month == DateTime.now().month && 
                    date.year == DateTime.now().year
                  ).length,
                  predictionConfidence: _usingAI ? _predictionConfidence : null,
                ),
              ],
            )
          else
            _buildNoPeriodDataCard(),
            
          // Show irregularity message if exists
          if (_hasIrregularity && _irregularityMessage != null)
            _buildIrregularityCard(_irregularityMessage!),
            
          // Show late ovulation message if detected
          if (_possibleLateOvulation && _ovulationMessage != null)
            _buildOvulationAdjustmentCard(_ovulationMessage!),
            
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Calendar',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF8AAE),
                ),
              ),
              _buildCalendarLegend(),
            ],
          ),
          SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFFF8AAE).withOpacity(0.15),
                  spreadRadius: 1,
                  blurRadius: 10,
                ),
              ],
            ),
            padding: EdgeInsets.all(12),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _showDayActionSheet(selectedDay);
              },
              calendarStyle: CalendarStyle(
                markersMaxCount: 4,
                markerDecoration: BoxDecoration(
                  color: Color(0xFFFF8AAE),
                  shape: BoxShape.circle,
                ),
                cellMargin: EdgeInsets.all(6),
                cellPadding: EdgeInsets.all(6),
                todayDecoration: BoxDecoration(
                  color: Color(0xFFFF8AAE).withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Color(0xFFFF8AAE),
                  shape: BoxShape.circle,
                ),
                weekendTextStyle: GoogleFonts.poppins(
                  color: Color(0xFFFF8AAE),
                ),
                outsideTextStyle: GoogleFonts.poppins(
                  color: Colors.grey.withOpacity(0.5),
                ),
                defaultTextStyle: GoogleFonts.poppins(),
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  bool isPeriod = _isPeriodDay(day);
                  bool isFertile = _hasLoggedPeriod && _isFertileDay(day);
                  bool isPill = _isPillTakenDay(day);
                  bool isPMS = _isPMSDay(day);
                  
                  // If no markers, return null to use default rendering
                  if (!isPeriod && !isFertile && !isPill && !isPMS) {
                    return null;
                  }
                  
                  // Choose background color based on day type
                  Color backgroundColor = Colors.transparent;
                  if (isPeriod) {
                    backgroundColor = Color(0xFFFF5C8A).withOpacity(0.15); // Deeper pink for period
                  } else if (isFertile) {
                    backgroundColor = Color(0xFF7ED957).withOpacity(0.15); // Fresh green for fertile days
                  } else if (isPMS) {
                    backgroundColor = Color(0xFFAA6DE0).withOpacity(0.15); // Soft purple for PMS
                  }
                  
                  return Container(
                    margin: const EdgeInsets.all(4.0),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPeriod ? Color(0xFFFF5C8A).withOpacity(0.3) : 
                               isFertile ? Color(0xFF7ED957).withOpacity(0.3) : 
                               isPMS ? Color(0xFFAA6DE0).withOpacity(0.3) :
                               Colors.transparent,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isPeriod ? Color(0xFFFF5C8A).withOpacity(0.1) : 
                                 isFertile ? Color(0xFF7ED957).withOpacity(0.1) : 
                                 isPMS ? Color(0xFFAA6DE0).withOpacity(0.1) :
                                 Colors.transparent,
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Day number in center
                        Center(
                          child: Text(
                            '${day.day}',
                            style: GoogleFonts.poppins(
                              color: isPeriod ? Color(0xFFFF5C8A) : 
                                     isFertile ? Color(0xFF7ED957) : 
                                     isPMS ? Color(0xFFAA6DE0) :
                                     Colors.black87,
                              fontWeight: isPeriod || isFertile || isPMS ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        
                        // Pill indicator (top right)
                        if (isPill)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Color(0xFFFF9D6C), // Soft orange for pill
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFFFF9D6C).withOpacity(0.3),
                                    blurRadius: 2,
                                    spreadRadius: 0.5,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
                selectedBuilder: (context, day, focusedDay) {
                  bool isPeriod = _isPeriodDay(day);
                  bool isFertile = _hasLoggedPeriod && _isFertileDay(day);
                  bool isPill = _isPillTakenDay(day);
                  bool isInjection = _isInjectionDay(day);
                  
                  return Container(
                    margin: const EdgeInsets.all(4.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF8AAE), Color(0xFFFF5C8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFFF8AAE).withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Day number in center
                        Center(
                          child: Text(
                            '${day.day}',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        
                        // Period indicator (bottom)
                        if (isPeriod)
                          Positioned(
                            bottom: 2,
                            right: 0,
                            left: 0,
                            child: Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Color(0xFFFF5C8A), width: 1),
                                ),
                              ),
                            ),
                          ),
                        
                        // Pill indicator (top right)
                        if (isPill)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Color(0xFFFF9D6C),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                            ),
                          ),
                        
                        // Injection indicator (top left)
                        if (isInjection)
                          Positioned(
                            top: 2,
                            left: 2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.purple,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                            ),
                          ),
                        
                        // Fertile indicator (center bottom)
                        if (isFertile && !isPeriod)
                          Positioned(
                            bottom: 2,
                            right: 0,
                            left: 0,
                            child: Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Color(0xFF7ED957),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
                todayBuilder: (context, day, focusedDay) {
                  bool isPeriod = _isPeriodDay(day);
                  bool isFertile = _hasLoggedPeriod && _isFertileDay(day);
                  bool isPill = _isPillTakenDay(day);
                  bool isInjection = _isInjectionDay(day);
                  
                  // Choose background color based on day type
                  Color backgroundColor = Color(0xFFFF8AAE).withOpacity(0.1);
                  if (isPeriod) {
                    backgroundColor = Color(0xFFFF5C8A).withOpacity(0.15);
                  } else if (isFertile) {
                    backgroundColor = Color(0xFF7ED957).withOpacity(0.15);
                  }
                  
                  return Container(
                    margin: const EdgeInsets.all(4.0),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Color(0xFFFF8AAE),
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFFF8AAE).withOpacity(0.2),
                          blurRadius: 4,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Day number in center
                        Center(
                          child: Text(
                            '${day.day}',
                            style: GoogleFonts.poppins(
                              color: isPeriod ? Color(0xFFFF5C8A) : 
                                     isFertile ? Color(0xFF7ED957) : 
                                     Color(0xFFFF8AAE),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        
                        // Period indicator (bottom)
                        if (isPeriod)
                          Positioned(
                            bottom: 2,
                            right: 0,
                            left: 0,
                            child: Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Color(0xFFFF5C8A),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1),
                                ),
                              ),
                            ),
                          ),
                        
                        // Pill indicator (top right)
                        if (isPill)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Color(0xFFFF9D6C),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                            ),
                          ),
                        
                        // Injection indicator (top left)
                        if (isInjection)
                          Positioned(
                            top: 2,
                            left: 2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Color(0xFFAA6DE0),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                            ),
                          ),
                        
                        // Fertile indicator (center bottom)
                        if (isFertile && !isPeriod)
                          Positioned(
                            bottom: 2,
                            right: 0,
                            left: 0,
                            child: Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Color(0xFF7ED957),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
                // Remove the marker builder as we're handling markers in the day builders
                markerBuilder: (context, date, events) => null,
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF8AAE),
                ),
                leftChevronIcon: Icon(Icons.chevron_left, size: 24, color: Color(0xFFFF8AAE)),
                rightChevronIcon: Icon(Icons.chevron_right, size: 24, color: Color(0xFFFF8AAE)),
                headerPadding: EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: GoogleFonts.poppins(fontSize: 14, color: Color(0xFF666666), fontWeight: FontWeight.w500),
                weekendStyle: GoogleFonts.poppins(fontSize: 14, color: Color(0xFFFF8AAE), fontWeight: FontWeight.w500),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFFF8AAE).withOpacity(0.1), width: 1)),
                ),
              ),
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {
                CalendarFormat.month: 'Month',
              },
              rowHeight: 56, // Slightly taller rows for better spacing and visibility of markers
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildEnhancedLegendItem(Color(0xFFFF5C8A), 'Period', Icons.circle),
                    SizedBox(width: 16),
                    if (_hasLoggedPeriod)
                      _buildEnhancedLegendItem(Color(0xFF7ED957), 'Fertile', Icons.circle),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildEnhancedLegendItem(Color(0xFFFF9D6C), 'Pill', Icons.medication),
                    SizedBox(width: 16),
                    _buildEnhancedLegendItem(Color(0xFFAA6DE0), 'PMS', Icons.mood),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          if (_planningGoal == 'undecided') ...[
            _buildFertilityExplanationCard(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildEnhancedLegendItem(Color color, String label, IconData icon) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Center(
            child: Icon(icon, size: 14, color: color),
          ),
        ),
        SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
  
  // Build AI prediction badge with more authentic AI feel
  Widget _buildAIPredictionBadge() {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6C9FFF), Color(0xFF8A6CFE)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF6C9FFF).withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 18, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'AI-Enhanced Predictions',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${(_predictionConfidence * 100).toInt()}% confidence',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Build ovulation adjustment card
  Widget _buildOvulationAdjustmentCard(String message) {
    return Container(
      margin: EdgeInsets.only(top: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFFE0F0FF),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF6C9FFF).withOpacity(0.15),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.sync, color: Color(0xFF6C9FFF), size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Color(0xFF555555),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _possibleLateOvulation = false;
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: Color(0xFF6C9FFF),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  'Dismiss',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  // Recalculate fertile days with adjusted ovulation
                  _adjustOvulation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6C9FFF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Adjust',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Adjust ovulation prediction
  void _adjustOvulation() {
    final today = DateTime.now();
    final daysFromLastPeriod = today.difference(_lastPeriodDate).inDays;
    
    // Create a temporary adjusted cycle length based on current day
    final adjustedCycle = daysFromLastPeriod + 14; // Assuming ovulation is today, period in 14 days
    
    setState(() {
      _cycleDuration = adjustedCycle;
      _possibleLateOvulation = false;
      
      // Recalculate predictions
      _enhancedFertileDays = _planningService.calculateFertileDays(_lastPeriodDate, adjustedCycle);
      _enhancedNextPeriods = _planningService.predictNextPeriods(_lastPeriodDate, adjustedCycle);
    });
    
    // Save the adjusted cycle duration
    _updateCycleDuration(adjustedCycle);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Fertility window adjusted based on your cycle pattern')),
    );
  }

  Widget _buildFirstTimeSetup() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF8AAE), Color(0xFFFFF0F5)], // Pink to soft pink gradient
          stops: [0.0, 0.3],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20),
            Text(
              'Welcome to Family Planning',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Let\'s set up your preferences to get personalized insights',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            SizedBox(height: 32),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(24),
                child: _buildInitialSetupView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build the learning hub tab
  Widget _buildResourcesTab() {
    // Get educational content based on user's planning goal
    final educationalContent = EducationalContent.getContentForGoal(_planningGoal);
    
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Learning Hub',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF8AAE),
            ),
          ),
          SizedBox(height: 20),
          // Tab selector for content categories
          Container(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: educationalContent.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTabIndex = index;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    margin: EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: _selectedTabIndex == index 
                          ? Color(0xFFFF8AAE)
                          : Color(0xFFFF8AAE).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: _selectedTabIndex == index ? [
                        BoxShadow(
                          color: Color(0xFFFF8AAE).withOpacity(0.25),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ] : null,
                    ),
                    child: Text(
                      educationalContent[index]['title'],
                      style: GoogleFonts.poppins(
                        color: _selectedTabIndex == index 
                            ? Colors.white
                            : Color(0xFFFF8AAE),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 24),
          // Selected content card
          Expanded(
            child: _buildEducationalContentCard(
              educationalContent[_selectedTabIndex],
            ),
          ),
        ],
      ),
    );
  }
  
  // Build educational content card
  Widget _buildEducationalContentCard(Map<String, dynamic> content) {
    final iconData = _getIconData(content['icon']);
    
    return Card(
      elevation: 4,
      shadowColor: Color(0xFFFF8AAE).withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(content['color']).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(iconData, color: Color(content['color']), size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content['title'],
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      Text(
                        content['description'],
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Container(
              height: 1,
              color: Color(0xFFEEEEEE),
              margin: EdgeInsets.symmetric(vertical: 4),
            ),
            SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: content['content'].length,
                itemBuilder: (context, index) {
                  final item = content['content'][index];
                  
                  // Check if this is a myth vs fact format
                  if (item.contains('MYTH:') && item.contains('FACT:')) {
                    final parts = item.split('\n');
                    return Container(
                      margin: EdgeInsets.only(bottom: 20),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.cancel_outlined, color: Color(0xFFFF5C8A), size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  parts[0].replaceAll('MYTH: ', ''),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFFF5C8A),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: Color(0xFF7ED957), size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  parts[1].replaceAll('FACT: ', ''),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF7ED957),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }
                  
                  // Regular bullet point
                  return Container(
                    margin: EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: EdgeInsets.only(top: 6),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Color(content['color']),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              color: Color(0xFF444444),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Convert string icon name to IconData
  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'calendar_today':
        return Icons.calendar_today;
      case 'restaurant':
        return Icons.restaurant;
      case 'medical_services':
        return Icons.medical_services;
      case 'psychology':
        return Icons.psychology;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'medication':
        return Icons.medication;
      case 'watch_later':
        return Icons.watch_later;
      case 'priority_high':
        return Icons.priority_high;
      case 'people':
        return Icons.people;
      case 'balance':
        return Icons.balance;
      case 'info':
        return Icons.info;
      case 'lightbulb':
        return Icons.lightbulb;
      case 'timeline':
        return Icons.timeline;
      case 'autorenew':
        return Icons.autorenew;
      case 'science':
        return Icons.science;
      case 'tips_and_updates':
        return Icons.tips_and_updates;
      case 'favorite':
        return Icons.favorite;
      default:
        return Icons.article;
    }
  }

  // Enhanced tracking summary widget
  Widget _buildEnhancedTrackingSummary({
    required DateTime lastPeriod,
    required List<DateTime> fertileDays,
    DateTime? nextPeriod,
    required int pillsTaken,
    double? predictionConfidence,
  }) {
    final now = DateTime.now();
    final daysSinceLastPeriod = now.difference(lastPeriod).inDays;
    
    // Calculate cycle day
    int cycleDay = daysSinceLastPeriod % _cycleDuration + 1;
    
    // Calculate days until next period
    int daysUntilNextPeriod = nextPeriod != null ? nextPeriod.difference(now).inDays : 0;
    if (daysUntilNextPeriod < 0) daysUntilNextPeriod = 0;
    
    return Card(
      elevation: 4,
      shadowColor: Color(0xFFFF8AAE).withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFFFF0F5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cycle Day',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                    Text(
                      cycleDay.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF8AAE),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: nextPeriod != null && daysUntilNextPeriod <= 3
                        ? Color(0xFFFF5C8A).withOpacity(0.15)
                        : fertileDays.any((d) => isSameDay(d, now))
                            ? Color(0xFF7ED957).withOpacity(0.15)
                            : Color(0xFFFF8AAE).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    nextPeriod != null && daysUntilNextPeriod <= 3
                        ? Icons.water_drop
                        : fertileDays.any((d) => isSameDay(d, now))
                            ? Icons.favorite
                            : Icons.calendar_today,
                    color: nextPeriod != null && daysUntilNextPeriod <= 3
                        ? Color(0xFFFF5C8A)
                        : fertileDays.any((d) => isSameDay(d, now))
                            ? Color(0xFF7ED957)
                            : Color(0xFFFF8AAE),
                    size: 28,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width * 0.7 * (cycleDay / _cycleDuration),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF8AAE), Color(0xFFFF5C8A)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCycleInfoItem(
                  'Last Period',
                  '${DateFormat('MMM d').format(lastPeriod)}',
                  Icons.history,
                  Color(0xFFFF5C8A),
                ),
                _buildCycleInfoItem(
                  'Next Period',
                  nextPeriod != null ? '${DateFormat('MMM d').format(nextPeriod)}' : 'Unknown',
                  Icons.event,
                  Color(0xFFFF5C8A),
                ),
                _buildCycleInfoItem(
                  'Pills Taken',
                  '$pillsTaken this month',
                  Icons.medication,
                  Color(0xFFFF9D6C),
                ),
              ],
            ),
            if (nextPeriod != null) ...[
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: daysUntilNextPeriod <= 3
                      ? Color(0xFFFF5C8A).withOpacity(0.15)
                      : daysUntilNextPeriod <= 7
                          ? Color(0xFFAA6DE0).withOpacity(0.15)
                          : Color(0xFF6C9FFF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      daysUntilNextPeriod <= 3
                          ? Icons.notifications_active
                          : Icons.notifications,
                      color: daysUntilNextPeriod <= 3
                          ? Color(0xFFFF5C8A)
                          : daysUntilNextPeriod <= 7
                              ? Color(0xFFAA6DE0)
                              : Color(0xFF6C9FFF),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      daysUntilNextPeriod == 0
                          ? 'Your period is expected today'
                          : daysUntilNextPeriod == 1
                              ? 'Your period is expected tomorrow'
                              : 'Your period is in $daysUntilNextPeriod days',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: daysUntilNextPeriod <= 3
                            ? Color(0xFFFF5C8A)
                            : daysUntilNextPeriod <= 7
                                ? Color(0xFFAA6DE0)
                                : Color(0xFF6C9FFF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCycleInfoItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Color(0xFF666666),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
      ],
    );
  }

  // New widget to show when no period data is available
  Widget _buildNoPeriodDataCard() {
    return Card(
      elevation: 4,
      shadowColor: Color(0xFFFF8AAE).withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF6C9FFF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.info_outline, color: Color(0xFF6C9FFF), size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'No Period Data Yet',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'To get personalized period and fertility predictions, please log your last period date.',
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Color(0xFF555555),
                height: 1.5,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text(
                'Log Period',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFF8AAE),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: () => _showDayActionSheet(DateTime.now()),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFertilityExplanationCard() {
    return Card(
      elevation: 4,
      shadowColor: Color(0xFFFF8AAE).withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF7ED957).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.lightbulb_outline, color: Color(0xFF7ED957), size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Understanding Fertility',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              "Tracking your fertile days can be helpful whether you're trying to conceive or avoid pregnancy.",
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Color(0xFF555555),
                height: 1.5,
              ),
            ),
            SizedBox(height: 16),
            _buildInfoPoint(
              'Green days indicate your estimated fertile window, when pregnancy is most likely.',
              Color(0xFF7ED957),
            ),
            SizedBox(height: 12),
            _buildInfoPoint(
              'Red markers show days when you recorded your period.',
              Color(0xFFFF5C8A),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Note: This is an estimate based on your cycle data. For more accurate fertility tracking, consider additional methods like tracking basal body temperature or using ovulation tests.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF777777),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoPoint(String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(top: 4),
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.info_outline, color: color, size: 14),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Color(0xFF444444),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
  
  // Build irregularity notification card
  Widget _buildIrregularityCard(String message) {
    return Container(
      margin: EdgeInsets.only(top: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFFFFD6E0),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFF8AAE).withOpacity(0.15),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.info_outline, color: Color(0xFFFF8AAE), size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cycle Insight',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFFFF5C8A),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Color(0xFF555555),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCalendarLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.red.withOpacity(0.5)),
          ),
        ),
        SizedBox(width: 4),
        Text('Period', style: TextStyle(fontSize: 12)),
        SizedBox(width: 8),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.green.withOpacity(0.5)),
          ),
        ),
        SizedBox(width: 4),
        Text('Fertile', style: TextStyle(fontSize: 12)),
      ],
    );
  }
  
  Future<void> _updateCycleDuration(int duration) async {
    setState(() {
      _cycleDuration = duration;
    });
    
    try {
      // Create a new data object with updated cycle duration
      final data = FamilyPlanningData(
        userId: _planningService.currentUserId ?? 'anonymous',
        planningGoal: _planningGoal,
        lastPeriodDate: _lastPeriodDate,
        cycleDuration: duration,
        periodDates: _periodDates,
        pillTakenDates: _pillTakenDates,
      );
      
      // Save the updated data
      await _planningService.saveFamilyPlanningData(data);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cycle duration updated successfully')),
      );
    } catch (e) {
      print('Error updating cycle duration: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update cycle duration. Please try again.')),
      );
    }
  }
  
  void _showCycleSettingsDialog() {
    int tempCycleDuration = _cycleDuration;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Cycle Settings',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF8AAE),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Average cycle length (days):',
                    style: GoogleFonts.poppins(),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove_circle, color: Color(0xFFFF8AAE)),
                        onPressed: () {
                          if (tempCycleDuration > 21) {
                            setDialogState(() {
                              tempCycleDuration--;
                            });
                          }
                        },
                      ),
                      SizedBox(width: 16),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Color(0xFFFF8AAE).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$tempCycleDuration',
                          style: GoogleFonts.poppins(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      IconButton(
                        icon: Icon(Icons.add_circle, color: Color(0xFFFF8AAE)),
                        onPressed: () {
                          if (tempCycleDuration < 35) {
                            setDialogState(() {
                              tempCycleDuration++;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Color(0xFF666666),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    _updateCycleDuration(tempCycleDuration);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF8AAE),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Save',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Family Planning',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFFFF8AAE), // Soft pink color
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8AAE)),
            ))
          : _isFirstEntry
              ? _buildFirstTimeSetup()
              : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF8AAE), Color(0xFFFFF0F5)], // Pink to soft pink gradient
          stops: [0.0, 0.3],
        ),
      ),
      child: Column(
        children: [
          // Tabs
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.7),
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              unselectedLabelStyle: GoogleFonts.poppins(),
              tabs: [
                Tab(text: 'Calendar', icon: Icon(Icons.calendar_today)),
                Tab(text: 'Conception', icon: Icon(Icons.favorite)),
                Tab(text: 'Learning Hub', icon: Icon(Icons.school)),
              ],
            ),
          ),
          
          // Tab content
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFertileDaysTab(),
                  _buildConceptionTipsTab(),
                  _buildResourcesTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 
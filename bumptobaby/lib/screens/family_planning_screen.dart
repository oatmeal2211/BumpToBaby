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
  List<DateTime> _injectionDates = [];
  
  // UI state
  bool _isLoading = true;
  bool _isInitialSetup = true;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _isSaving = false;
  
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
          _isInitialSetup = false;
          _planningGoal = data.planningGoal;
          _lastPeriodDate = data.lastPeriodDate;
          _cycleDuration = data.cycleDuration;
          _periodDates = data.periodDates;
          _pillTakenDates = data.pillTakenDates;
          _injectionDates = data.injectionDates;
        });
      }
    } catch (e) {
      // Handle error
      print('Error loading family planning data: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data. Please try again later.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _savePlanningGoal(String goal) async {
    if (_isSaving) return; // Prevent multiple simultaneous saves
    
    setState(() {
      _isSaving = true;
      _planningGoal = goal;
    });
    
    try {
      if (_isInitialSetup) {
        // Create new data
        final data = FamilyPlanningData(
          userId: _planningService.currentUserId ?? 'anonymous',
          planningGoal: goal,
          lastPeriodDate: _lastPeriodDate,
        );
        
        await _planningService.saveFamilyPlanningData(data);
        if (mounted) {
          setState(() {
            _isInitialSetup = false;
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
        injectionDates: _injectionDates,
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
        injectionDates: _injectionDates,
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
        if (!_injectionDates.any((d) => 
          d.year == date.year && 
          d.month == date.month && 
          d.day == date.day
        )) {
          _injectionDates = [..._injectionDates, date];
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
        injectionDates: _injectionDates,
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
    return _injectionDates.any((date) => 
      date.year == day.year && 
      date.month == day.month && 
      date.day == day.day
    );
  }
  
  bool _isFertileDay(DateTime day) {
    final fertileDays = _planningService.calculateFertileDays(_lastPeriodDate, _cycleDuration);
    return fertileDays.any((date) => 
      date.year == day.year && 
      date.month == day.month && 
      date.day == day.day
    );
  }
  
  void _showDayActionSheet(DateTime day) {
    final bool isPeriod = _isPeriodDay(day);
    final bool isPill = _isPillTakenDay(day);
    final bool isInjection = _isInjectionDay(day);
    
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
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.withOpacity(0.2),
                  child: Icon(
                    isInjection ? Icons.check_circle : Icons.vaccines, 
                    color: Colors.purple
                  ),
                ),
                title: Text(isInjection ? 'Remove Injection Record' : 'Record Injection'),
                onTap: () {
                  Navigator.pop(context);
                  if (isInjection) {
                    _deleteInjection(day);
                  } else {
                    _recordInjection(day);
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
              // Debug option
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  child: Icon(Icons.bug_report, color: Colors.grey),
                ),
                title: Text('Debug Data'),
                onTap: () {
                  Navigator.pop(context);
                  _debugData();
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
        injectionDates: _injectionDates,
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
        injectionDates: _injectionDates,
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
        _injectionDates = _injectionDates.where((d) => 
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
        injectionDates: _injectionDates,
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
    print('Injection Dates: ${_injectionDates.map((d) => d.toString()).join(', ')}');
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
              color: Color(0xFFF8AFAF),
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
                _isInitialSetup = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFF8AFAF),
              minimumSize: Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
    if (_planningGoal == 'want_more_children') {
      return _buildConceptionTipsTab();
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
        },
        {
          'title': 'Copper IUD',
          'description': 'A small T-shaped device inserted into the uterus that doesn\'t contain hormones.',
          'effectiveness': '99% effective',
          'color': Colors.amber,
          'icon': Icons.device_thermostat,
        },
        {
          'title': 'Sterilization',
          'description': 'Permanent surgical procedure for those who don\'t want children.',
          'effectiveness': '99% effective',
          'color': Colors.purple,
          'icon': Icons.medical_services,
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
                                  Text(
                                    option['title'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Effectiveness: ${option['effectiveness']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 16),
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
                              // Add more detailed information here
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
  
  // New tab for conception tips for those who want more children
  Widget _buildConceptionTipsTab() {
    final fertileDays = _planningService.calculateFertileDays(_lastPeriodDate, _cycleDuration);
    final nextPeriods = _planningService.predictNextPeriods(_lastPeriodDate, _cycleDuration);
    
    // Calculate estimated ovulation day
    final ovulationDay = DateTime(
      _lastPeriodDate.year,
      _lastPeriodDate.month,
      _lastPeriodDate.day + (_cycleDuration - 14)
    );
    
    final List<Map<String, dynamic>> conceptionTips = [
      {
        'title': 'Track Your Fertile Window',
        'description': 'Your most fertile days are typically 3 days before ovulation through the day of ovulation.',
        'icon': Icons.calendar_today,
        'color': Colors.green,
      },
      {
        'title': 'Maintain a Healthy Diet',
        'description': 'Eat a balanced diet rich in fruits, vegetables, whole grains, and lean proteins. Consider prenatal vitamins with folic acid.',
        'icon': Icons.restaurant,
        'color': Colors.orange,
      },
      {
        'title': 'Regular Exercise',
        'description': 'Moderate exercise can help maintain a healthy weight and reduce stress, both of which can improve fertility.',
        'icon': Icons.fitness_center,
        'color': Colors.blue,
      },
      {
        'title': 'Limit Alcohol and Caffeine',
        'description': 'Reduce alcohol and caffeine intake, as they can affect fertility and pregnancy outcomes.',
        'icon': Icons.no_drinks,
        'color': Colors.red,
      },
      {
        'title': 'Manage Stress',
        'description': 'High stress levels can affect hormone balance and ovulation. Try relaxation techniques like yoga or meditation.',
        'icon': Icons.spa,
        'color': Colors.purple,
      },
    ];
    
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Conception Planning',
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
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Fertility Window',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  if (fertileDays.isNotEmpty)
                    Text(
                      'Most fertile days: ${DateFormat('MMM d').format(fertileDays.first)} - ${DateFormat('MMM d').format(fertileDays.last)}',
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                  SizedBox(height: 4),
                  Text(
                    'Estimated ovulation: ${DateFormat('MMM d').format(ovulationDay)}',
                    style: GoogleFonts.poppins(fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Next period: ${nextPeriods.isNotEmpty ? DateFormat('MMM d').format(nextPeriods.first) : "Unknown"}',
                    style: GoogleFonts.poppins(fontSize: 16),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'For the best chances of conception, try to have intercourse every 1-2 days during your fertile window.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Conception Tips',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: conceptionTips.length,
              itemBuilder: (context, index) {
                final tip = conceptionTips[index];
                return Card(
                  elevation: 2,
                  margin: EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: tip['color'].withOpacity(0.2),
                          child: Icon(tip['icon'], color: tip['color']),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tip['title'],
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                tip['description'],
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFertileDaysTab() {
    final fertileDays = _planningService.calculateFertileDays(_lastPeriodDate, _cycleDuration);
    final nextPeriods = _planningService.predictNextPeriods(_lastPeriodDate, _cycleDuration);
    
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fertility Tracker',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          TrackingSummary(
            lastPeriod: _lastPeriodDate,
            fertileDays: fertileDays,
            nextPeriod: nextPeriods.isNotEmpty ? nextPeriods.first : null,
            pillsTaken: _pillTakenDates.where((date) => 
              date.month == DateTime.now().month && 
              date.year == DateTime.now().year
            ).length,
            lastInjection: _injectionDates.isNotEmpty ? _injectionDates.last : null,
          ),
          SizedBox(height: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calendar',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      TableCalendar(
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
                        calendarStyle: const CalendarStyle(
                          markersMaxCount: 3,
                          markerDecoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          // Make the calendar more compact
                          cellMargin: EdgeInsets.all(2),
                          cellPadding: EdgeInsets.all(2),
                        ),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            final markers = <Widget>[];
                            
                            if (_isPeriodDay(date)) {
                              markers.add(
                                Positioned(
                                  bottom: 1,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              );
                            }
                            
                            if (_isPillTakenDay(date)) {
                              markers.add(
                                Positioned(
                                  top: 1,
                                  right: 1,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              );
                            }
                            
                            if (_isInjectionDay(date)) {
                              markers.add(
                                Positioned(
                                  top: 1,
                                  left: 1,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.purple,
                                    ),
                                  ),
                                ),
                              );
                            }
                            
                            return markers.isEmpty ? null : Stack(children: markers);
                          },
                          defaultBuilder: (context, day, focusedDay) {
                            if (_isFertileDay(day)) {
                              return Container(
                                margin: const EdgeInsets.all(4.0),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${day.day}',
                                    style: TextStyle(color: Colors.green[800]),
                                  ),
                                ),
                              );
                            }
                            return null;
                          },
                        ),
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          // Make the header more compact
                          titleTextStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          leftChevronIcon: Icon(Icons.chevron_left, size: 20),
                          rightChevronIcon: Icon(Icons.chevron_right, size: 20),
                          headerPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          // Make the days of week more compact
                          weekdayStyle: TextStyle(fontSize: 12),
                          weekendStyle: TextStyle(fontSize: 12),
                        ),
                        calendarFormat: CalendarFormat.month,
                        availableCalendarFormats: const {
                          CalendarFormat.month: 'Month',
                        },
                        rowHeight: 40, // Make rows more compact
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLegendItem(Colors.red, 'Period'),
                            SizedBox(width: 16),
                            _buildLegendItem(Colors.green, 'Fertile'),
                            SizedBox(width: 16),
                            _buildLegendItem(Colors.orange, 'Pill'),
                            SizedBox(width: 16),
                            _buildLegendItem(Colors.purple, 'Injection'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
  
  Widget _buildTrackingTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Track Your Health',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _buildTrackingCard(
                  'Period Tracking',
                  'Record your period dates to predict future cycles',
                  Icons.calendar_today,
                  Colors.red,
                  () {
                    _showDayActionSheet(DateTime.now());
                  },
                ),
                SizedBox(height: 16),
                _buildTrackingCard(
                  'Birth Control Pills',
                  'Track your daily pill intake',
                  Icons.medication,
                  Colors.orange,
                  () {
                    _showDayActionSheet(DateTime.now());
                  },
                ),
                SizedBox(height: 16),
                _buildTrackingCard(
                  'Contraceptive Injections',
                  'Record your injection dates',
                  Icons.vaccines,
                  Colors.purple,
                  () {
                    _showDayActionSheet(DateTime.now());
                  },
                ),
                SizedBox(height: 16),
                _buildTrackingCard(
                  'Cycle Settings',
                  'Adjust your average cycle length',
                  Icons.settings,
                  Colors.blue,
                  () {
                    _showCycleSettingsDialog();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTrackingCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.2),
                radius: 24,
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
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
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
        injectionDates: _injectionDates,
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
              title: Text('Cycle Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Average cycle length (days):'),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove_circle),
                        onPressed: () {
                          if (tempCycleDuration > 21) {
                            setDialogState(() {
                              tempCycleDuration--;
                            });
                          }
                        },
                      ),
                      SizedBox(width: 16),
                      Text(
                        '$tempCycleDuration',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 16),
                      IconButton(
                        icon: Icon(Icons.add_circle),
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
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    _updateCycleDuration(tempCycleDuration);
                    Navigator.pop(context);
                  },
                  child: Text('Save'),
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Family Planning',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Color(0xFFF8AFAF),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_isInitialSetup) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Family Planning',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Color(0xFFF8AFAF),
        ),
        body: _buildInitialSetupView(),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Family Planning',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFFF8AFAF),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              icon: Icon(_planningGoal == 'want_more_children' ? Icons.child_friendly : Icons.compare), 
              text: _planningGoal == 'want_more_children' ? 'Conception' : 'Options'
            ),
            Tab(icon: Icon(Icons.calendar_month), text: 'Fertile Days'),
            Tab(icon: Icon(Icons.track_changes), text: 'Tracking'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildContraceptiveOptionsTab(),
          _buildFertileDaysTab(),
          _buildTrackingTab(),
        ],
      ),
    );
  }

  // Helper method for TableCalendar
  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return false;
    }
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
} 
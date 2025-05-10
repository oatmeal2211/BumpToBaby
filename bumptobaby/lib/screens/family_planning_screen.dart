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
  bool _isFirstEntry = true;  // Track if this is the first time user opens the screen
  bool _hasLoggedPeriod = false;  // Track if user has logged any period data
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
          _isFirstEntry = false;  // User has data, not first entry
          _planningGoal = data.planningGoal;
          _lastPeriodDate = data.lastPeriodDate;
          _cycleDuration = data.cycleDuration;
          _periodDates = data.periodDates;
          _pillTakenDates = data.pillTakenDates;
          _injectionDates = data.injectionDates;
          _hasLoggedPeriod = data.periodDates.isNotEmpty;  // Check if user has logged any periods
        });
      } else {
        // No data found, this is first entry
        setState(() {
          _isFirstEntry = true;
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
                _isFirstEntry = false;
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
    final fertileDays = _hasLoggedPeriod ? _planningService.calculateFertileDays(_lastPeriodDate, _cycleDuration) : <DateTime>[];
    final nextPeriods = _hasLoggedPeriod ? _planningService.predictNextPeriods(_lastPeriodDate, _cycleDuration) : <DateTime>[];
    
    return Padding(
      padding: EdgeInsets.all(16),
      child: ListView(
        children: [
          Text(
            'Fertility Tracker',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          if (_hasLoggedPeriod) 
            TrackingSummary(
              lastPeriod: _lastPeriodDate,
              fertileDays: fertileDays,
              nextPeriod: nextPeriods.isNotEmpty ? nextPeriods.first : null,
              pillsTaken: _pillTakenDates.where((date) => 
                date.month == DateTime.now().month && 
                date.year == DateTime.now().year
              ).length,
              lastInjection: _injectionDates.isNotEmpty ? _injectionDates.last : null,
            )
          else
            _buildNoPeriodDataCard(),
          SizedBox(height: 16),
          Text(
            'Calendar',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
              ],
            ),
            padding: EdgeInsets.all(8),
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
              calendarStyle: const CalendarStyle(
                markersMaxCount: 4,
                markerDecoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                cellMargin: EdgeInsets.all(4),
                cellPadding: EdgeInsets.all(4),
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  bool isPeriod = _isPeriodDay(day);
                  bool isFertile = _hasLoggedPeriod && _isFertileDay(day);  // Only check fertile days if period data exists
                  bool isPill = _isPillTakenDay(day);
                  bool isInjection = _isInjectionDay(day);
                  
                  // If no markers, return null to use default rendering
                  if (!isPeriod && !isFertile && !isPill && !isInjection) {
                    return null;
                  }
                  
                  // Choose background color based on day type
                  Color backgroundColor = Colors.transparent;
                  if (isPeriod) {
                    backgroundColor = Colors.red.withOpacity(0.15);
                  } else if (isFertile) {
                    backgroundColor = Colors.green.withOpacity(0.15);
                  }
                  
                  return Container(
                    margin: const EdgeInsets.all(4.0),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isPeriod ? Colors.red.withOpacity(0.3) : 
                               isFertile ? Colors.green.withOpacity(0.3) : 
                               Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Day number in center
                        Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: isPeriod ? Colors.red[800] : 
                                     isFertile ? Colors.green[800] : 
                                     Colors.black87,
                              fontWeight: isPeriod || isFertile ? FontWeight.bold : FontWeight.normal,
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
                                color: Colors.orange,
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
                      color: Colors.blue.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue,
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Day number in center
                        Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: Colors.blue[800],
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
                                  color: Colors.red,
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
                                color: Colors.orange,
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
                                  color: Colors.green,
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
                  Color backgroundColor = Colors.blue.withOpacity(0.1);
                  if (isPeriod) {
                    backgroundColor = Colors.red.withOpacity(0.15);
                  } else if (isFertile) {
                    backgroundColor = Colors.green.withOpacity(0.15);
                  }
                  
                  return Container(
                    margin: const EdgeInsets.all(4.0),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.5),
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Day number in center
                        Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: isPeriod ? Colors.red[800] : 
                                     isFertile ? Colors.green[800] : 
                                     Colors.blue[800],
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
                                  color: Colors.red,
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
                                color: Colors.orange,
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
                                  color: Colors.green,
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
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                leftChevronIcon: Icon(Icons.chevron_left, size: 20),
                rightChevronIcon: Icon(Icons.chevron_right, size: 20),
                headerPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(fontSize: 12),
                weekendStyle: TextStyle(fontSize: 12),
              ),
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {
                CalendarFormat.month: 'Month',
              },
              rowHeight: 48, // Slightly taller rows for better spacing and visibility of markers
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildEnhancedLegendItem(Colors.red, 'Period', Icons.circle),
                    SizedBox(width: 16),
                    if (_hasLoggedPeriod)
                      _buildEnhancedLegendItem(Colors.green, 'Fertile', Icons.circle),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildEnhancedLegendItem(Colors.orange, 'Pill', Icons.medication),
                    SizedBox(width: 16),
                    _buildEnhancedLegendItem(Colors.purple, 'Injection', Icons.vaccines),
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
  
  // New widget to show when no period data is available
  Widget _buildNoPeriodDataCard() {
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
                Icon(Icons.info_outline, color: Colors.blue, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No Period Data Yet',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Log your period dates to get predictions for your next period and fertile window.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _showDayActionSheet(DateTime.now());
              },
              icon: Icon(Icons.calendar_today),
              label: Text('Record Period'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFF8AFAF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEnhancedLegendItem(Color color, String label, IconData icon) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color, width: 1),
          ),
          child: Center(
            child: Icon(icon, size: 12, color: color),
          ),
        ),
        SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
  
  Widget _buildFertilityExplanationCard() {
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
            Text(
              'Understanding Fertility',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Tracking your fertile days can be helpful whether you\'re trying to conceive or avoid pregnancy.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Green days indicate your estimated fertile window, when pregnancy is most likely.',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Red markers show days when you recorded your period.',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Note: This is an estimate based on your cycle data. For more accurate fertility tracking, consider additional methods like tracking basal body temperature or using ovulation tests.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
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
    
    if (_isFirstEntry) {
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
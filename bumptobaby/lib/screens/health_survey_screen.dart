import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:bumptobaby/models/health_schedule.dart';
import 'package:bumptobaby/models/health_survey.dart';
import 'package:bumptobaby/services/health_ai_service.dart';
import 'package:bumptobaby/services/health_schedule_service.dart';
import 'package:bumptobaby/screens/health_schedule_screen.dart';

class HealthSurveyScreen extends StatefulWidget {
  final bool isUpdate;

  const HealthSurveyScreen({Key? key, this.isUpdate = false}) : super(key: key);

  @override
  _HealthSurveyScreenState createState() => _HealthSurveyScreenState();
}

class _HealthSurveyScreenState extends State<HealthSurveyScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isPregnant = true;
  DateTime? _dueDate;
  DateTime? _babyBirthDate;
  String? _babyGender;
  final TextEditingController _babyWeightController = TextEditingController();
  final TextEditingController _babyHeightController = TextEditingController();
  final TextEditingController _healthConditionsController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  final TextEditingController _parentConcernsController = TextEditingController();
  final TextEditingController _lifestyleController = TextEditingController();
  final TextEditingController _babyEnvironmentController = TextEditingController();
  int _mentalHealthScore = 5;
  int _energyLevel = 5;
  String? _mood;
  final List<String> _moodOptions = ['Happy', 'Calm', 'Tired', 'Anxious', 'Stressed', 'Sad'];
  bool _isLoading = false;
  bool _isLoadingExistingData = false;

  final HealthAIService _healthAIService = HealthAIService();
  final HealthScheduleService _healthScheduleService = HealthScheduleService();

  @override
  void initState() {
    super.initState();
    if (widget.isUpdate) {
      _loadExistingSurveyData();
    }
  }

  Future<void> _loadExistingSurveyData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingExistingData = true;
    });

    try {
      final latestSurvey = await _healthScheduleService.getLatestHealthSurvey(user.uid);
      if (latestSurvey != null) {
        setState(() {
          _isPregnant = latestSurvey.isPregnant;
          _dueDate = latestSurvey.dueDate;
          _babyBirthDate = latestSurvey.babyBirthDate;
          _babyGender = latestSurvey.babyGender;
          
          if (latestSurvey.babyWeight != null) {
            _babyWeightController.text = latestSurvey.babyWeight.toString();
          }
          
          if (latestSurvey.babyHeight != null) {
            _babyHeightController.text = latestSurvey.babyHeight.toString();
          }
          
          if (latestSurvey.healthConditions != null) {
            _healthConditionsController.text = latestSurvey.healthConditions!.join(', ');
          }
          
          if (latestSurvey.allergies != null) {
            _allergiesController.text = latestSurvey.allergies!.join(', ');
          }
          
          if (latestSurvey.medications != null) {
            _medicationsController.text = latestSurvey.medications!.join(', ');
          }
          
          if (latestSurvey.parentConcerns != null) {
            _parentConcernsController.text = latestSurvey.parentConcerns!.join(', ');
          }
          
          if (latestSurvey.lifestyle != null) {
            _lifestyleController.text = latestSurvey.lifestyle!.entries
                .map((e) => "${e.key}: ${e.value}")
                .join(', ');
          }
          
          if (latestSurvey.babyEnvironment != null) {
            _babyEnvironmentController.text = latestSurvey.babyEnvironment!.entries
                .map((e) => "${e.key}: ${e.value}")
                .join(', ');
          }
          
          if (latestSurvey.mentalHealthScore != null) {
            _mentalHealthScore = latestSurvey.mentalHealthScore!;
          }
          
          if (latestSurvey.energyLevel != null) {
            _energyLevel = latestSurvey.energyLevel!;
          }
          
          if (latestSurvey.mood != null) {
            _mood = latestSurvey.mood;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading existing data: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoadingExistingData = false;
      });
    }
  }

  @override
  void dispose() {
    _babyWeightController.dispose();
    _babyHeightController.dispose();
    _healthConditionsController.dispose();
    _allergiesController.dispose();
    _medicationsController.dispose();
    _parentConcernsController.dispose();
    _lifestyleController.dispose();
    _babyEnvironmentController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 280)), // 40 weeks from now
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 300)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFFF8AFAF),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _selectBabyBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _babyBirthDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1095)), // 3 years ago
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFFF8AFAF),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _babyBirthDate) {
      setState(() {
        _babyBirthDate = picked;
      });
    }
  }

  Future<void> _submitSurvey() async {
    if (_isPregnant && _dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your due date')),
      );
      return;
    }

    if (!_isPregnant && _babyBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your baby\'s birth date')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to submit a survey')),
        );
        return;
      }

      Map<String, dynamic>? lifestyle;
      if (_lifestyleController.text.isNotEmpty) {
        lifestyle = {};
        final items = _lifestyleController.text.split(',');
        for (var item in items) {
          final parts = item.split(':');
          if (parts.length == 2) {
            lifestyle[parts[0].trim()] = parts[1].trim();
          } else {
            lifestyle[item.trim()] = true;
          }
        }
      }

      Map<String, dynamic>? babyEnvironment;
      if (_babyEnvironmentController.text.isNotEmpty) {
        babyEnvironment = {};
        final items = _babyEnvironmentController.text.split(',');
        for (var item in items) {
          final parts = item.split(':');
          if (parts.length == 2) {
            babyEnvironment[parts[0].trim()] = parts[1].trim();
          } else {
            babyEnvironment[item.trim()] = true;
          }
        }
      }

      final survey = HealthSurvey(
        userId: user.uid,
        isPregnant: _isPregnant,
        dueDate: _isPregnant ? _dueDate : null,
        babyBirthDate: !_isPregnant ? _babyBirthDate : null,
        babyGender: !_isPregnant ? _babyGender : null,
        babyWeight: !_isPregnant && _babyWeightController.text.isNotEmpty
            ? double.parse(_babyWeightController.text)
            : null,
        babyHeight: !_isPregnant && _babyHeightController.text.isNotEmpty
            ? double.parse(_babyHeightController.text)
            : null,
        healthConditions: _healthConditionsController.text.isNotEmpty
            ? _healthConditionsController.text.split(',').map((e) => e.trim()).toList()
            : null,
        allergies: _allergiesController.text.isNotEmpty
            ? _allergiesController.text.split(',').map((e) => e.trim()).toList()
            : null,
        medications: _medicationsController.text.isNotEmpty
            ? _medicationsController.text.split(',').map((e) => e.trim()).toList()
            : null,
        createdAt: DateTime.now(),
        parentConcerns: _parentConcernsController.text.isNotEmpty
            ? _parentConcernsController.text.split(',').map((e) => e.trim()).toList()
            : null,
        lifestyle: lifestyle,
        babyEnvironment: babyEnvironment,
        mentalHealthScore: _mentalHealthScore,
        energyLevel: _energyLevel,
        mood: _mood,
        lastMentalHealthCheckIn: DateTime.now(),
      );

      await _healthScheduleService.saveHealthSurvey(survey);

      HealthSchedule schedule;
      try {
        schedule = await _healthAIService.generateHealthSchedule(survey, user.uid)
            .timeout(
              Duration(seconds: 45), 
              onTimeout: () {
                if (kDebugMode) {
                  print('AI schedule generation timed out');
                }
                throw TimeoutException('Schedule generation took too long');
              }
            );
      } on TimeoutException catch (_) {
        if (kDebugMode) {
          print('Timeout occurred during schedule generation');
        }
        
        final now = DateTime.now();
        
        // Create a more comprehensive fallback schedule
        List<HealthScheduleItem> fallbackItems = [
          HealthScheduleItem(
            title: 'Health Check-up',
            description: 'Regular health consultation with your healthcare provider.',
            scheduledDate: now.add(Duration(days: 30)),
            category: 'checkup',
          ),
          HealthScheduleItem(
            title: 'Health Profile Review',
            description: 'Review and update your health profile.',
            scheduledDate: now.add(Duration(days: 15)),
            category: 'milestone',
          ),
        ];
        
        // Add personalized items based on survey data
        if (survey.isPregnant) {
          fallbackItems.add(
            HealthScheduleItem(
              title: 'Prenatal Vitamins',
              description: 'Daily prenatal vitamin intake is essential for your baby\'s development.',
              scheduledDate: now,
              category: 'supplement',
            ),
          );
          
          // Add risk alert for pregnant women
          fallbackItems.add(
            HealthScheduleItem(
              title: 'Monitor for Pregnancy Warning Signs',
              description: 'Watch for severe headaches, vision changes, sudden swelling, or abdominal pain. Contact your doctor immediately if these occur.',
              scheduledDate: now,
              category: 'risk_alert',
              severity: 'medium',
              additionalData: {
                'symptoms': 'Severe headaches, vision changes, sudden swelling, abdominal pain',
                'action': 'Contact healthcare provider immediately'
              },
            ),
          );
          
          // Add prediction for pregnant women
          fallbackItems.add(
            HealthScheduleItem(
              title: 'Prepare for Next Trimester',
              description: 'As your pregnancy progresses, you\'ll need comfortable clothes, supportive pillows, and may want to start planning your nursery.',
              scheduledDate: now.add(Duration(days: 30)),
              category: 'prediction',
              additionalData: {
                'essentials': 'Comfortable clothes, supportive pillows, nursery items',
                'timing': 'Coming weeks'
              },
            ),
          );
          
          // Add mental health check if needed
          if (survey.mentalHealthScore != null && survey.mentalHealthScore! < 5 || 
              survey.mood == 'Anxious' || survey.mood == 'Stressed' || survey.mood == 'Sad') {
            fallbackItems.add(
              HealthScheduleItem(
                title: 'Mental Health Support',
                description: 'Based on your survey, consider speaking with a mental health professional about your feelings during pregnancy.',
                scheduledDate: now.add(Duration(days: 7)),
                category: 'risk_alert',
                severity: 'medium',
                additionalData: {
                  'reason': 'Mental health concerns noted in survey',
                  'action': 'Schedule appointment with mental health professional'
                },
              ),
            );
          }
        } else if (survey.babyBirthDate != null) {
          // Calculate baby's age in months
          final babyAgeInDays = now.difference(survey.babyBirthDate!).inDays;
          final babyAgeInMonths = (babyAgeInDays / 30.44).floor();
          
          fallbackItems.add(
            HealthScheduleItem(
              title: 'Pediatric Check-up',
              description: 'Regular health assessment for your baby.',
              scheduledDate: now.add(Duration(days: 30)),
              category: 'checkup',
            ),
          );
          
          // Add risk alert for babies
          fallbackItems.add(
            HealthScheduleItem(
              title: 'Monitor Baby\'s Development',
              description: 'Watch for developmental milestones and consult your pediatrician if you notice delays.',
              scheduledDate: now.add(Duration(days: 15)),
              category: 'risk_alert',
              severity: 'low',
              additionalData: {
                'focus': 'Developmental milestones',
                'action': 'Consult pediatrician if concerned'
              },
            ),
          );
          
          // Add prediction for babies
          fallbackItems.add(
            HealthScheduleItem(
              title: babyAgeInMonths < 6 ? 'Prepare for Solid Foods' : 'Prepare for Mobility',
              description: babyAgeInMonths < 6 
                  ? 'Your baby will likely be ready to start solid foods soon. Consider getting baby feeding supplies.'
                  : 'Your baby will become more mobile soon. Ensure your home is baby-proofed.',
              scheduledDate: now.add(Duration(days: 30)),
              category: 'prediction',
              additionalData: {
                'essentials': babyAgeInMonths < 6 ? 'Baby spoons, bibs, first foods' : 'Baby-proofing supplies',
                'timing': 'Coming weeks'
              },
            ),
          );
          
          // Add specific item for parent concerns if provided
          if (survey.parentConcerns != null && survey.parentConcerns!.isNotEmpty) {
            fallbackItems.add(
              HealthScheduleItem(
                title: 'Address Parent Concerns',
                description: 'Discuss your concerns (${survey.parentConcerns!.join(", ")}) with your pediatrician at your next visit.',
                scheduledDate: now.add(Duration(days: 14)),
                category: 'risk_alert',
                severity: 'medium',
                additionalData: {
                  'concerns': survey.parentConcerns!.join(", "),
                  'action': 'Discuss with pediatrician'
                },
              ),
            );
          }
        }
        
        schedule = HealthSchedule(
          userId: user.uid,
          items: fallbackItems,
          generatedAt: now,
        );
      } catch (e) {
        if (kDebugMode) {
          print("AI generation failed: $e");
        }
        
        final now = DateTime.now();
        
        // Create a basic fallback schedule
        List<HealthScheduleItem> fallbackItems = [
          HealthScheduleItem(
            title: 'Health Check-up',
            description: 'Regular health consultation with your healthcare provider.',
            scheduledDate: now.add(Duration(days: 30)),
            category: 'checkup',
          ),
          HealthScheduleItem(
            title: 'Health Profile Review',
            description: 'Review and update your health profile.',
            scheduledDate: now.add(Duration(days: 15)),
            category: 'milestone',
          ),
          HealthScheduleItem(
            title: 'Health Alert',
            description: 'Monitor your health and contact your healthcare provider if you have concerns.',
            scheduledDate: now,
            category: 'risk_alert',
            severity: 'medium',
          ),
          HealthScheduleItem(
            title: 'Upcoming Needs',
            description: 'Prepare for your healthcare journey by staying informed and planning ahead.',
            scheduledDate: now.add(Duration(days: 7)),
            category: 'prediction',
          ),
        ];
        
        schedule = HealthSchedule(
          userId: user.uid,
          items: fallbackItems,
          generatedAt: now,
        );
      }

      await _healthScheduleService.saveHealthSchedule(schedule);

      if (widget.isUpdate) {
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        if (!mounted) return;
        
        Future.microtask(() {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HealthScheduleScreen(schedule: schedule),
            ),
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red[600],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isUpdate ? 'Update Health Profile' : 'Health Survey',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: Color(0xFFF8AFAF),
        elevation: 0,
      ),
      body: _isLoading || _isLoadingExistingData
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF8AFAF)),
                  ),
                  SizedBox(height: 20),
                  Text(
                    _isLoading ? 'Generating your health schedule...' : 'Loading your data...',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF8AFAF).withOpacity(0.3),
                    Colors.white,
                  ],
                  stops: [0.0, 0.2],
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.favorite_rounded,
                              size: 60,
                              color: Color(0xFFF8AFAF),
                            ),
                            SizedBox(height: 16),
                            Text(
                              widget.isUpdate 
                                ? 'Update Your Health Profile'
                                : 'Create Your Health Schedule',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E6091),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              widget.isUpdate 
                                ? 'Update your health information to regenerate your personalized schedule.'
                                : 'Please fill out this survey to help us create a personalized health schedule for you and your baby.',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 30),
                      
                      _buildSectionTitle('Are you currently pregnant?'),
                      SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildRadioTile(
                              title: 'Yes, I am pregnant',
                              value: true,
                              icon: Icons.pregnant_woman_rounded,
                            ),
                            Divider(height: 1, thickness: 1, indent: 70, endIndent: 20),
                            _buildRadioTile(
                              title: 'No, I have a baby',
                              value: false,
                              icon: Icons.child_care_rounded,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      
                      if (_isPregnant) ...[
                        _buildSectionTitle('Due Date'),
                        SizedBox(height: 10),
                        _buildDateSelector(
                          value: _dueDate,
                          hintText: 'Select Due Date',
                          onTap: () => _selectDueDate(context),
                          icon: Icons.event_rounded,
                        ),
                        if (_isPregnant && _dueDate == null)
                          Padding(
                            padding: EdgeInsets.only(top: 8.0, left: 12.0),
                            child: Text(
                              'Due date is required',
                              style: GoogleFonts.poppins(
                                color: Colors.red[600],
                                fontSize: 12.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                      
                      if (!_isPregnant) ...[
                        _buildSectionTitle('Baby\'s Birth Date'),
                        SizedBox(height: 10),
                        _buildDateSelector(
                          value: _babyBirthDate,
                          hintText: 'Select Birth Date',
                          onTap: () => _selectBabyBirthDate(context),
                          icon: Icons.cake_rounded,
                        ),
                        if (!_isPregnant && _babyBirthDate == null)
                          Padding(
                            padding: EdgeInsets.only(top: 8.0, left: 12.0),
                            child: Text(
                              'Birth date is required',
                              style: GoogleFonts.poppins(
                                color: Colors.red[600],
                                fontSize: 12.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        SizedBox(height: 20),
                        
                        _buildSectionTitle('Baby\'s Gender'),
                        SizedBox(height: 10),
                        _buildDropdownField(
                          value: _babyGender,
                          hintText: 'Select Gender',
                          items: [
                            {'value': 'Male', 'label': 'Male'},
                            {'value': 'Female', 'label': 'Female'},
                            {'value': 'Other', 'label': 'Other'},
                          ],
                          onChanged: (value) {
                            setState(() {
                              _babyGender = value;
                            });
                          },
                          icon: Icons.wc_rounded,
                        ),
                        SizedBox(height: 20),
                        
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle('Baby\'s Weight (kg)'),
                                  SizedBox(height: 10),
                                  _buildTextField(
                                    controller: _babyWeightController,
                                    hintText: 'e.g., 3.5',
                                    keyboardType: TextInputType.number,
                                    icon: Icons.monitor_weight_rounded,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle('Baby\'s Height (cm)'),
                                  SizedBox(height: 10),
                                  _buildTextField(
                                    controller: _babyHeightController,
                                    hintText: 'e.g., 50',
                                    keyboardType: TextInputType.number,
                                    icon: Icons.height_rounded,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      
                      SizedBox(height: 24),
                      
                      _buildSectionTitle('Health Conditions'),
                      SizedBox(height: 4),
                      Text(
                        'Separate multiple conditions with commas',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      SizedBox(height: 10),
                      _buildTextField(
                        controller: _healthConditionsController,
                        hintText: 'e.g., Diabetes, Hypertension',
                        maxLines: 2,
                        icon: Icons.medical_information_rounded,
                      ),
                      SizedBox(height: 20),
                      
                      _buildSectionTitle('Allergies'),
                      SizedBox(height: 4),
                      Text(
                        'Separate multiple allergies with commas',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      SizedBox(height: 10),
                      _buildTextField(
                        controller: _allergiesController,
                        hintText: 'e.g., Penicillin, Peanuts',
                        maxLines: 2,
                        icon: Icons.coronavirus_rounded,
                      ),
                      SizedBox(height: 20),
                      
                      _buildSectionTitle('Medications'),
                      SizedBox(height: 4),
                      Text(
                        'Separate multiple medications with commas',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      SizedBox(height: 10),
                      _buildTextField(
                        controller: _medicationsController,
                        hintText: 'e.g., Prenatal vitamins, Iron supplements',
                        maxLines: 2,
                        icon: Icons.medication_rounded,
                      ),
                      SizedBox(height: 20),
                      
                      _buildSectionTitle('Parent Concerns'),
                      SizedBox(height: 4),
                      Text(
                        'Separate multiple concerns with commas',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      SizedBox(height: 10),
                      _buildTextField(
                        controller: _parentConcernsController,
                        hintText: 'e.g., Sleep issues, Feeding concerns',
                        maxLines: 2,
                        icon: Icons.psychology_rounded,
                      ),
                      SizedBox(height: 20),
                      
                      if (!_isPregnant) ...[
                        _buildSectionTitle('Baby\'s Environment'),
                        SizedBox(height: 4),
                        Text(
                          'Describe key aspects of baby\'s environment (format: aspect: detail)',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        SizedBox(height: 10),
                        _buildTextField(
                          controller: _babyEnvironmentController,
                          hintText: 'e.g., Daycare: 3 days/week, Siblings: 1 older',
                          maxLines: 3,
                          icon: Icons.house_rounded,
                        ),
                        SizedBox(height: 20),
                      ],
                      
                      _buildSectionTitle('Lifestyle Information'),
                      SizedBox(height: 4),
                      Text(
                        'Describe key aspects of your lifestyle (format: aspect: detail)',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      SizedBox(height: 10),
                      _buildTextField(
                        controller: _lifestyleController,
                        hintText: 'e.g., Exercise: 2x weekly, Diet: vegetarian',
                        maxLines: 3,
                        icon: Icons.self_improvement_rounded,
                      ),
                      SizedBox(height: 20),
                      
                      _buildSectionTitle('Mental Health & Wellbeing'),
                      SizedBox(height: 20),
                      
                      Text(
                        'Mental Health Score (1-10)',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 10),
                      Slider(
                        value: _mentalHealthScore.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: _mentalHealthScore.toString(),
                        activeColor: Color(0xFFF8AFAF),
                        onChanged: (value) {
                          setState(() {
                            _mentalHealthScore = value.round();
                          });
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Struggling', style: GoogleFonts.poppins(fontSize: 12)),
                          Text('Excellent', style: GoogleFonts.poppins(fontSize: 12)),
                        ],
                      ),
                      SizedBox(height: 20),
                      
                      Text(
                        'Energy Level (1-10)',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 10),
                      Slider(
                        value: _energyLevel.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: _energyLevel.toString(),
                        activeColor: Color(0xFFF8AFAF),
                        onChanged: (value) {
                          setState(() {
                            _energyLevel = value.round();
                          });
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Very Low', style: GoogleFonts.poppins(fontSize: 12)),
                          Text('Very High', style: GoogleFonts.poppins(fontSize: 12)),
                        ],
                      ),
                      SizedBox(height: 20),
                      
                      Text(
                        'Current Mood',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _moodOptions.map((mood) {
                          final isSelected = _mood == mood;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _mood = mood;
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Color(0xFFF8AFAF) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? Color(0xFFF8AFAF) : Colors.grey[300]!,
                                ),
                              ),
                              child: Text(
                                mood,
                                style: GoogleFonts.poppins(
                                  color: isSelected ? Colors.white : Colors.grey[700],
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      
                      SizedBox(height: 40),
                      
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            if (_isPregnant && _dueDate == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please select your due date'),
                                  backgroundColor: Colors.red[600],
                                ),
                              );
                              return;
                            }
                            if (!_isPregnant && _babyBirthDate == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please select your baby\'s birth date'),
                                  backgroundColor: Colors.red[600],
                                ),
                              );
                              return;
                            }
                            _submitSurvey();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFF8AFAF),
                            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 15.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30.0),
                            ),
                            elevation: 3,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_month_rounded,
                                color: Colors.white,
                              ),
                              SizedBox(width: 10),
                              Text(
                                widget.isUpdate ? 'Update Health Schedule' : 'Generate Health Schedule',
                                style: GoogleFonts.poppins(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16.0,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E6091),
      ),
    );
  }

  Widget _buildRadioTile({required String title, required bool value, required IconData icon}) {
    return InkWell(
      onTap: () {
        setState(() {
          _isPregnant = value;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Row(
          children: [
            Icon(
              icon,
              size: 28,
              color: _isPregnant == value ? Color(0xFFF8AFAF) : Colors.grey,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: _isPregnant == value ? FontWeight.w600 : FontWeight.normal,
                  color: _isPregnant == value ? Color(0xFF1E6091) : Colors.black87,
                ),
              ),
            ),
            Radio<bool>(
              value: value,
              groupValue: _isPregnant,
              activeColor: Color(0xFFF8AFAF),
              onChanged: (newValue) {
                setState(() {
                  _isPregnant = newValue!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector({
    DateTime? value,
    required String hintText,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Color(0xFFF8AFAF),
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                value == null
                    ? hintText
                    : '${value.day}/${value.month}/${value.year}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: value == null ? Colors.grey[600] : Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    String? value,
    required String hintText,
    required List<Map<String, String>> items,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Color(0xFFF8AFAF),
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                hint: Text(
                  hintText,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                icon: Icon(Icons.arrow_drop_down),
                isExpanded: true,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.black87,
                ),
                items: items.map((item) {
                  return DropdownMenuItem(
                    value: item['value'],
                    child: Text(item['label']!),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.poppins(
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey[400],
            fontSize: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFFF8AFAF), width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          prefixIcon: Icon(
            icon,
            color: Color(0xFFF8AFAF),
          ),
        ),
      ),
    );
  }
} 
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bumptobaby/models/health_survey.dart';
import 'package:bumptobaby/services/health_ai_service.dart';
import 'package:bumptobaby/services/health_schedule_service.dart';
import 'package:bumptobaby/screens/health_schedule_screen.dart';

class HealthSurveyScreen extends StatefulWidget {
  const HealthSurveyScreen({Key? key}) : super(key: key);

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
  bool _isLoading = false;

  final HealthAIService _healthAIService = HealthAIService();
  final HealthScheduleService _healthScheduleService = HealthScheduleService();

  @override
  void dispose() {
    _babyWeightController.dispose();
    _babyHeightController.dispose();
    _healthConditionsController.dispose();
    _allergiesController.dispose();
    _medicationsController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 280)), // 40 weeks from now
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 300)),
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
    );
    if (picked != null && picked != _babyBirthDate) {
      setState(() {
        _babyBirthDate = picked;
      });
    }
  }

  Future<void> _submitSurvey() async {
    if (_formKey.currentState!.validate()) {
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

        // Create survey object
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
        );

        // Save survey to Firestore
        await _healthScheduleService.saveHealthSurvey(survey);

        // Generate health schedule using AI
        final schedule = await _healthAIService.generateHealthSchedule(survey, user.uid);

        // Save schedule to Firestore
        await _healthScheduleService.saveHealthSchedule(schedule);

        // Navigate to schedule screen
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HealthScheduleScreen(schedule: schedule),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Survey', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF005792))),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please fill out this survey to help us create a personalized health schedule for you and your baby.',
                      style: TextStyle(fontSize: 16.0),
                    ),
                    const SizedBox(height: 20.0),
                    
                    // User Status Selection
                    const Text(
                      'Are you currently pregnant?',
                      style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Radio<bool>(
                          value: true,
                          groupValue: _isPregnant,
                          onChanged: (value) {
                            setState(() {
                              _isPregnant = value!;
                            });
                          },
                        ),
                        const Text('Yes, I am pregnant'),
                      ],
                    ),
                    Row(
                      children: [
                        Radio<bool>(
                          value: false,
                          groupValue: _isPregnant,
                          onChanged: (value) {
                            setState(() {
                              _isPregnant = value!;
                            });
                          },
                        ),
                        const Text('No, I have a baby'),
                      ],
                    ),
                    const SizedBox(height: 20.0),
                    
                    // Pregnant-specific fields
                    if (_isPregnant) ...[
                      const Text(
                        'Due Date',
                        style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8.0),
                      InkWell(
                        onTap: () => _selectDueDate(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            contentPadding: const EdgeInsets.all(10.0),
                          ),
                          child: Text(
                            _dueDate == null
                                ? 'Select Due Date'
                                : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                          ),
                        ),
                      ),
                      if (_isPregnant && _dueDate == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0, left: 12.0),
                          child: Text(
                            'Due date is required',
                            style: TextStyle(color: Colors.red, fontSize: 12.0),
                          ),
                        ),
                    ],
                    
                    // Baby-specific fields
                    if (!_isPregnant) ...[
                      const Text(
                        'Baby\'s Birth Date',
                        style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8.0),
                      InkWell(
                        onTap: () => _selectBabyBirthDate(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            contentPadding: const EdgeInsets.all(10.0),
                          ),
                          child: Text(
                            _babyBirthDate == null
                                ? 'Select Birth Date'
                                : '${_babyBirthDate!.day}/${_babyBirthDate!.month}/${_babyBirthDate!.year}',
                          ),
                        ),
                      ),
                      if (!_isPregnant && _babyBirthDate == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0, left: 12.0),
                          child: Text(
                            'Birth date is required',
                            style: TextStyle(color: Colors.red, fontSize: 12.0),
                          ),
                        ),
                      const SizedBox(height: 16.0),
                      
                      const Text(
                        'Baby\'s Gender',
                        style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8.0),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          contentPadding: const EdgeInsets.all(10.0),
                        ),
                        value: _babyGender,
                        hint: const Text('Select Gender'),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _babyGender = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16.0),
                      
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Baby\'s Weight (kg)',
                                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8.0),
                                TextFormField(
                                  controller: _babyWeightController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                    contentPadding: const EdgeInsets.all(10.0),
                                    hintText: 'e.g., 3.5',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Baby\'s Height (cm)',
                                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8.0),
                                TextFormField(
                                  controller: _babyHeightController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                    contentPadding: const EdgeInsets.all(10.0),
                                    hintText: 'e.g., 50',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    const SizedBox(height: 20.0),
                    
                    // Common fields
                    const Text(
                      'Health Conditions (comma separated)',
                      style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8.0),
                    TextFormField(
                      controller: _healthConditionsController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        contentPadding: const EdgeInsets.all(10.0),
                        hintText: 'e.g., Diabetes, Hypertension',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16.0),
                    
                    const Text(
                      'Allergies (comma separated)',
                      style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8.0),
                    TextFormField(
                      controller: _allergiesController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        contentPadding: const EdgeInsets.all(10.0),
                        hintText: 'e.g., Penicillin, Peanuts',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16.0),
                    
                    const Text(
                      'Medications (comma separated)',
                      style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8.0),
                    TextFormField(
                      controller: _medicationsController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        contentPadding: const EdgeInsets.all(10.0),
                        hintText: 'e.g., Prenatal vitamins, Iron supplements',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 30.0),
                    
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          // Validate form
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
                          _submitSurvey();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink[400],
                          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                        ),
                        child: const Text(
                          'Generate Health Schedule',
                          style: TextStyle(fontSize: 16.0, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 
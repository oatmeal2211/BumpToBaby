import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

        // Return to previous screen if updating
        if (widget.isUpdate) {
          if (!mounted) return;
          Navigator.pop(context, true); // Return true to indicate update was successful
        } else {
          // Navigate to schedule screen
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HealthScheduleScreen(schedule: schedule),
            ),
          );
        }
      } catch (e) {
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
                      // Header with illustration
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
                      
                      // User Status Selection with better styling
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
                      
                      // Pregnant-specific fields
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
                      
                      // Baby-specific fields
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
                        
                        // Baby measurements with row layout
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
                      
                      // Common fields
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
                      SizedBox(height: 40),
                      
                      // Submit button
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            // Validate form
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

  // Helper method to build section titles
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

  // Helper method to build radio tiles
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

  // Helper method to build date selector
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

  // Helper method to build dropdown field
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

  // Helper method to build text fields
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
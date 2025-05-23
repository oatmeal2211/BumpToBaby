import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyPlanningData {
  final String userId;
  final String planningGoal; // "want_more_children", "no_more_children", "undecided"
  final List<String> contraceptiveMethodsUsed;
  final DateTime lastPeriodDate;
  final int cycleDuration; // Average cycle length in days
  final List<DateTime> periodDates; // History of period dates
  final List<DateTime> pillTakenDates; // Dates when pills were taken
  final List<DateTime> injectionDates; // Dates of contraceptive injections
  
  FamilyPlanningData({
    required this.userId,
    required this.planningGoal,
    this.contraceptiveMethodsUsed = const [],
    required this.lastPeriodDate,
    this.cycleDuration = 28,
    this.periodDates = const [],
    this.pillTakenDates = const [],
    this.injectionDates = const [],
  });
  
  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'planningGoal': planningGoal,
      'contraceptiveMethodsUsed': contraceptiveMethodsUsed,
      'lastPeriodDate': lastPeriodDate,
      'cycleDuration': cycleDuration,
      'periodDates': periodDates.map((date) => Timestamp.fromDate(date)).toList(),
      'pillTakenDates': pillTakenDates.map((date) => Timestamp.fromDate(date)).toList(),
      'injectionDates': injectionDates.map((date) => Timestamp.fromDate(date)).toList(),
    };
  }
  
  // Create from Firestore document
  factory FamilyPlanningData.fromMap(Map<String, dynamic> map) {
    return FamilyPlanningData(
      userId: map['userId'],
      planningGoal: map['planningGoal'],
      contraceptiveMethodsUsed: List<String>.from(map['contraceptiveMethodsUsed'] ?? []),
      lastPeriodDate: (map['lastPeriodDate'] as Timestamp).toDate(),
      cycleDuration: map['cycleDuration'] ?? 28,
      periodDates: (map['periodDates'] as List?)
          ?.map((timestamp) => (timestamp as Timestamp).toDate())
          .toList() ?? [],
      pillTakenDates: (map['pillTakenDates'] as List?)
          ?.map((timestamp) => (timestamp as Timestamp).toDate())
          .toList() ?? [],
      injectionDates: (map['injectionDates'] as List?)
          ?.map((timestamp) => (timestamp as Timestamp).toDate())
          .toList() ?? [],
    );
  }
}

// Educational content for family planning
class EducationalContent {
  static List<Map<String, dynamic>> getContentForGoal(String goal) {
    switch (goal) {
      case 'want_more_children':
        return _conceptionContent;
      case 'no_more_children':
        return _contraceptionContent;
      case 'undecided':
        return _undecidedContent;
      default:
        return _generalContent;
    }
  }
  
  // Content for users wanting more children
  static final List<Map<String, dynamic>> _conceptionContent = [
    {
      'title': 'Fertility Awareness',
      'description': 'Understanding your body\'s fertility signs can help maximize your chances of conception.',
      'icon': 'calendar_today',
      'color': 0xFFFF8AAE, // pink
      'content': [
        'Track your basal body temperature (BBT) daily before getting out of bed',
        'Monitor changes in cervical mucus throughout your cycle - it becomes clear and stretchy during fertile days',
        'Use ovulation predictor kits to detect LH surge 24-36 hours before ovulation',
        'Your most fertile days are typically 3 days before ovulation and ovulation day itself',
        'Consider using a fertility tracking app that combines multiple fertility indicators'
      ]
    },
    {
      'title': 'Ovulation Tracking',
      'description': 'Identifying your ovulation window is key to successful conception.',
      'icon': 'favorite',
      'color': 0xFF7ED957, // green
      'content': [
        'Ovulation typically occurs 12-14 days before your next period starts',
        'Look for signs like slight cramping on one side (mittelschmerz) or light spotting',
        'Your sex drive may naturally increase around ovulation',
        'For most accurate results, combine calendar tracking with BBT and cervical mucus monitoring',
        'Having intercourse every 1-2 days during your fertile window maximizes conception chances'
      ]
    },
    {
      'title': 'Conception Tips',
      'description': 'Practical advice to improve your chances of getting pregnant.',
      'icon': 'tips_and_updates',
      'color': 0xFF6C9FFF, // blue
      'content': [
        'Avoid lubricants that can inhibit sperm movement - use fertility-friendly options if needed',
        'After intercourse, lying down for 15 minutes may help sperm reach their destination',
        'Moderate exercise can improve fertility, but avoid excessive high-intensity workouts',
        'Manage stress through yoga, meditation, or other relaxation techniques',
        'Both partners should avoid excessive alcohol, smoking, and recreational drugs'
      ]
    },
    {
      'title': 'Nutrition for Conception',
      'description': 'Proper nutrition can improve fertility and prepare your body for pregnancy.',
      'icon': 'restaurant',
      'color': 0xFFFF9D6C, // orange
      'content': [
        'Take a prenatal vitamin with at least 400mcg of folic acid at least 3 months before trying to conceive',
        'Consume foods rich in antioxidants like fruits, vegetables, nuts, and grains',
        'Include healthy fats like omega-3s found in fish, avocados, and olive oil',
        'Maintain adequate iron intake through lean meats, beans, and leafy greens',
        'Stay hydrated and limit caffeine to less than 200mg daily (about one 12oz cup of coffee)'
      ]
    },
    {
      'title': 'When to See a Specialist',
      'description': 'Know when it\'s time to seek professional help with conception.',
      'icon': 'medical_services',
      'color': 0xFFAA6DE0, // purple
      'content': [
        'If you\'re under 35 and have been trying for 12 months without success',
        'If you\'re 35-40 and have been trying for 6 months without success',
        'If you\'re over 40 and have been trying for 3 months without success',
        'If you have irregular periods, endometriosis, PCOS, or history of pelvic infections',
        'If either partner has known fertility issues or previous reproductive surgeries'
      ]
    }
  ];
  
  // Content for users not wanting more children
  static final List<Map<String, dynamic>> _contraceptionContent = [
    {
      'title': 'Short-term Methods',
      'description': 'Temporary birth control options that can be stopped when desired.',
      'icon': 'medication',
      'color': 0xFF6C9FFF, // blue
      'content': [
        'Combined hormonal methods: pills, patches, and vaginal rings (91-99% effective)',
        'Progestin-only methods: mini-pills (91-99% effective)',
        'Barrier methods: condoms, diaphragms, and cervical caps (76-98% effective)',
        'Fertility awareness methods: tracking fertile days to avoid intercourse (76-88% effective)',
        'Emergency contraception: morning-after pill or copper IUD insertion (up to 99% effective if used correctly)'
      ]
    },
    {
      'title': 'Long-term Methods',
      'description': 'Long-lasting birth control options that don\'t require daily attention.',
      'icon': 'watch_later',
      'color': 0xFFAA6DE0, // purple
      'content': [
        'Hormonal IUDs: last 3-7 years, may reduce period pain and bleeding (99% effective)',
        'Copper IUD: hormone-free option that lasts up to 10-12 years (99% effective)',
        'Implant: small rod inserted under the skin that lasts 3-5 years (99% effective)',
        'Hormonal injection: administered every 3 months (94-99% effective)',
        'All long-term methods are reversible with quick return to fertility'
      ]
    },
    {
      'title': 'Permanent Birth Control',
      'description': 'Surgical options for those who are certain they don\'t want more children.',
      'icon': 'medical_services',
      'color': 0xFF7ED957, // green
      'content': [
        'Female sterilization (tubal ligation): blocks fallopian tubes (99% effective)',
        'Male sterilization (vasectomy): blocks sperm from leaving the body (99% effective)',
        'Vasectomy is less invasive with quicker recovery than tubal ligation',
        'Both should be considered permanent, though reversal is sometimes possible but not guaranteed',
        'These methods do not protect against STIs, so condoms may still be needed'
      ]
    },
    {
      'title': 'Emergency Contraception',
      'description': 'Options to prevent pregnancy after unprotected sex or contraceptive failure.',
      'icon': 'priority_high',
      'color': 0xFFFF9D6C, // orange
      'content': [
        'Emergency contraceptive pills: most effective within 72 hours (up to 89% effective)',
        'Ella (ulipristal acetate): effective up to 5 days after unprotected sex',
        'Copper IUD: can be inserted up to 5 days after unprotected sex (99% effective)',
        'Not intended for regular use - less effective than ongoing contraception',
        'Does not terminate an existing pregnancy - prevents pregnancy from occurring'
      ]
    },
    {
      'title': 'Partner Communication',
      'description': 'Tips for discussing contraception and family planning with your partner.',
      'icon': 'people',
      'color': 0xFFFF8AAE, // pink
      'content': [
        'Choose a neutral time and place for the conversation, not during an argument',
        'Use "I" statements to express your feelings and needs',
        'Listen to your partner\'s concerns and preferences without judgment',
        'Consider consulting a healthcare provider together to discuss options',
        'Remember that contraception responsibility can be shared between partners'
      ]
    }
  ];
  
  // Content for undecided users
  static final List<Map<String, dynamic>> _undecidedContent = [
    {
      'title': 'Pros & Cons',
      'description': 'Considerations to help with your family planning decision.',
      'icon': 'balance',
      'color': 0xFF6C9FFF, // blue
      'content': [
        'PROS: Siblings for existing children, expanded family experiences, potential joy and fulfillment',
        'CONS: Financial considerations, career impacts, time and energy demands',
        'PROS: Continuing family legacy, experiencing different stages of parenting',
        'CONS: Environmental concerns, potential health risks, lifestyle restrictions',
        'Consider your age, health, support system, financial situation, and long-term goals'
      ]
    },
    {
      'title': 'Counseling Resources',
      'description': 'Professional support for making family planning decisions.',
      'icon': 'psychology',
      'color': 0xFFAA6DE0, // purple
      'content': [
        'Individual or couples counseling can help clarify values and goals',
        'Reproductive health counselors specialize in family planning decisions',
        'Support groups for those facing similar decisions can provide perspective',
        'Online resources and decision-making tools can supplement professional guidance',
        'Genetic counseling may be helpful if hereditary conditions are a concern'
      ]
    },
    {
      'title': 'Family Planning Methods',
      'description': 'Understanding all your options while you decide.',
      'icon': 'info',
      'color': 0xFF7ED957, // green
      'content': [
        'Temporary methods allow flexibility while deciding (pills, condoms, etc.)',
        'Fertility awareness helps understand your cycle for either goal',
        'Long-acting reversible contraception provides years of protection with quick return to fertility',
        'Permanent methods should only be considered when completely certain',
        'Your choice can evolve over time as your circumstances and feelings change'
      ]
    },
    {
      'title': 'Decision-Making Guides',
      'description': 'Frameworks to help you make this important life decision.',
      'icon': 'lightbulb',
      'color': 0xFFFF9D6C, // orange
      'content': [
        'List your values and how each option aligns with them',
        'Imagine your life in 5, 10, and 20 years with each choice',
        'Consider the "regret test" - which decision might you regret more?',
        'Talk to parents at different family stages to gain perspective',
        'Remember that many factors are temporary (financial situation, housing) while others are permanent'
      ]
    },
    {
      'title': 'Life Considerations',
      'description': 'How family planning fits into your broader life picture.',
      'icon': 'timeline',
      'color': 0xFFFF8AAE, // pink
      'content': [
        'Career goals and timeline - how would children affect your professional path?',
        'Financial readiness - childcare costs, education savings, healthcare',
        'Support system - family nearby, partner involvement, community resources',
        'Personal fulfillment - how do children fit into your vision of a meaningful life?',
        'Relationship stability - are you and your partner aligned on parenting values?'
      ]
    }
  ];
  
  // General content for all users
  static final List<Map<String, dynamic>> _generalContent = [
    {
      'title': 'Understanding Your Cycle',
      'description': 'The basics of the menstrual cycle and fertility.',
      'icon': 'autorenew',
      'color': 0xFF2196F3, // blue
      'content': [
        'The average cycle is 28 days but can range from 21-35 days',
        'Ovulation typically occurs 12-14 days before your next period',
        'The fertile window includes 5 days before ovulation and ovulation day',
        'Tracking your cycle helps identify patterns and irregularities'
      ]
    },
    {
      'title': 'Hormonal Health',
      'description': 'How hormones affect your cycle and overall wellbeing.',
      'icon': 'science',
      'color': 0xFF9C27B0, // purple
      'content': [
        'Estrogen rises in the first half of your cycle, peaking at ovulation',
        'Progesterone dominates the second half of your cycle',
        'Hormonal imbalances can cause irregular periods, mood changes, and other symptoms',
        'Lifestyle factors like stress, sleep, and nutrition can affect hormone balance'
      ]
    },
    {
      'title': 'When to See a Doctor',
      'description': 'Signs that warrant medical attention for reproductive health.',
      'icon': 'medical_services',
      'color': 0xFFE91E63, // pink
      'content': [
        'Very heavy periods or excessive bleeding',
        'Severe pain during periods that interferes with daily activities',
        'Irregular cycles or missed periods (if not pregnant)',
        'Unusual symptoms like bleeding between periods or after sex'
      ]
    },
  ];
}

// Cycle phase information
class CyclePhase {
  static Map<String, dynamic> getPhaseInfo(DateTime date, DateTime lastPeriodDate, List<DateTime> nextPeriods, List<DateTime> fertileDays) {
    // Default values
    String phaseName = 'Follicular Phase';
    String description = 'Your body is preparing for ovulation';
    int color = 0xFF2196F3; // blue
    List<String> tips = [
      'Focus on building energy',
      'Good time for starting new projects',
      'Incorporate iron-rich foods'
    ];
    
    // Check if date is in period
    if (nextPeriods.isNotEmpty) {
      DateTime nextPeriod = nextPeriods.first;
      int daysUntilNextPeriod = nextPeriod.difference(date).inDays;
      
      // Menstrual phase (period)
      if (daysUntilNextPeriod <= 0 && daysUntilNextPeriod >= -5) {
        phaseName = 'Menstrual Phase';
        description = 'Your period is here';
        color = 0xFFE91E63; // pink
        tips = [
          'Rest when needed',
          'Stay hydrated',
          'Warm beverages may help with cramps',
          'Consider iron-rich foods to replenish'
        ];
        return {
          'phaseName': phaseName,
          'description': description,
          'color': color,
          'tips': tips
        };
      }
      
      // PMS/Luteal phase (7-10 days before period)
      if (daysUntilNextPeriod > 0 && daysUntilNextPeriod <= 10) {
        phaseName = 'Luteal Phase';
        description = 'Your body is preparing for your next period';
        color = 0xFF9C27B0; // purple
        tips = [
          'Be mindful of mood changes',
          'Prioritize self-care',
          'Reduce salt, sugar, and caffeine if experiencing PMS',
          'Extra rest may be helpful'
        ];
        return {
          'phaseName': phaseName,
          'description': description,
          'color': color,
          'tips': tips
        };
      }
    }
    
    // Check if date is in fertile window
    bool isFertile = fertileDays.any((d) => 
      d.year == date.year && 
      d.month == date.month && 
      d.day == date.day
    );
    
    if (isFertile) {
      phaseName = 'Fertile Window';
      description = 'You are most likely to conceive during this time';
      color = 0xFF4CAF50; // green
      tips = [
        'Peak energy and focus',
        'Optimal time for conception',
        'Good time for important conversations',
        'You may notice changes in cervical fluid'
      ];
      return {
        'phaseName': phaseName,
        'description': description,
        'color': color,
        'tips': tips
      };
    }
    
    // Default to follicular phase
    return {
      'phaseName': phaseName,
      'description': description,
      'color': color,
      'tips': tips
    };
  }
} 
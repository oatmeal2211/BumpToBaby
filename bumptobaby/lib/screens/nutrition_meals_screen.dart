import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// import 'package:shared_preferences/shared_preferences.dart'; // Comment out SharedPreferences
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add Firebase import
import 'package:firebase_auth/firebase_auth.dart'; // Add Firebase Auth import

// Model for a recipe - helps with structured data
class Recipe {
  final String id;
  final String title;
  final List<String> ingredients;
  final List<String> instructions;
  final String cuisineType;
  final String description;
  final List<String> allergens;
  final String servings;
  final Map<String, String> nutritionalValues;
  final String healthBenefitsSummary;
  final String? priceRange;

  // New fields for user's selected preferences
  final String? selectedLifeStage;
  final bool? wasVegetarian;
  final bool? wasHalal;
  final bool? wasBudgetFriendly;

  Recipe({
    required this.id,
    required this.title,
    required this.ingredients,
    required this.instructions,
    required this.cuisineType,
    required this.description,
    required this.allergens,
    required this.servings,
    required this.nutritionalValues,
    required this.healthBenefitsSummary,
    this.priceRange,
    this.selectedLifeStage,
    this.wasVegetarian = false,
    this.wasHalal = false,
    this.wasBudgetFriendly = false,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'Untitled Recipe',
      ingredients: List<String>.from(json['ingredients'] as List? ?? []),
      instructions: List<String>.from(json['instructions'] as List? ?? []),
      cuisineType: json['cuisineType'] as String? ?? 'Unknown',
      description: json['description'] as String? ?? 'No description.',
      allergens: List<String>.from(json['allergens'] as List? ?? []),
      servings: json['servings'] as String? ?? 'N/A',
      nutritionalValues: Map<String, String>.from(json['nutritionalValues'] as Map? ?? {}),
      healthBenefitsSummary: json['healthBenefitsSummary'] as String? ?? '',
      priceRange: json['priceRange'] as String?,
      selectedLifeStage: json['selectedLifeStage'] as String?,
      wasVegetarian: json['wasVegetarian'] as bool? ?? false,
      wasHalal: json['wasHalal'] as bool? ?? false,
      wasBudgetFriendly: json['wasBudgetFriendly'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'ingredients': ingredients,
      'instructions': instructions,
      'cuisineType': cuisineType,
      'description': description,
      'allergens': allergens,
      'servings': servings,
      'nutritionalValues': nutritionalValues,
      'healthBenefitsSummary': healthBenefitsSummary,
      'priceRange': priceRange,
      'selectedLifeStage': selectedLifeStage,
      'wasVegetarian': wasVegetarian,
      'wasHalal': wasHalal,
      'wasBudgetFriendly': wasBudgetFriendly,
    };
  }
}

class RecipeDisplayScreen extends StatefulWidget {
  final Recipe recipe; // Changed from Map<String, dynamic> to Recipe

  const RecipeDisplayScreen({Key? key, required this.recipe}) : super(key: key);

  @override
  _RecipeDisplayScreenState createState() => _RecipeDisplayScreenState();
}

class _RecipeDisplayScreenState extends State<RecipeDisplayScreen> {
  bool _isSaved = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _checkIfSaved();
  }

  Future<void> _checkIfSaved() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _isSaved = false;
      });
      return;
    }
    try {
      final recipeQuery = await _firestore
          .collection('recipes')
          .where('id', isEqualTo: widget.recipe.id)
          .where('userId', isEqualTo: user.uid)
          .limit(1) // Optimization: we only need to know if it exists
          .get();
          
      setState(() {
        _isSaved = recipeQuery.docs.isNotEmpty;
      });
    } catch (e) {
      print('Error checking if recipe is saved: $e');
      setState(() {
        _isSaved = false; // Assume not saved on error
      });
      // Optionally show a snackbar error here if needed
    }
  }

  Future<void> _toggleSaveRecipe(Recipe recipe) async {
    final user = _auth.currentUser;
    if (user == null) {
      print("User not signed in. Cannot save recipe.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please sign in to save recipes', style: GoogleFonts.poppins()))
      );
      return;
    }

    final recipeDocRefQuery = _firestore
        .collection('recipes')
        .where('id', isEqualTo: recipe.id)
        .where('userId', isEqualTo: user.uid)
        .limit(1);

    try {
      final querySnapshot = await recipeDocRefQuery.get();

      if (querySnapshot.docs.isNotEmpty) {
        // Recipe exists, so delete it
        await querySnapshot.docs.first.reference.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recipe removed!', style: GoogleFonts.poppins()))
        );
        setState(() {
          _isSaved = false;
        });
      } else {
        // Recipe doesn't exist, so add it
        // Ensure all fields are present for Firestore, especially if they are optional in the model
        final recipeData = recipe.toJson();
        recipeData['userId'] = user.uid;
        recipeData['timestamp'] = FieldValue.serverTimestamp(); // Added for ordering/querying later

        // Add default values for any potentially null fields expected by Firestore if not handled in toJson
        recipeData.putIfAbsent('priceRange', () => null);
        recipeData.putIfAbsent('selectedLifeStage', () => null);


        await _firestore.collection('recipes').add(recipeData);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recipe saved!', style: GoogleFonts.poppins()))
        );
        setState(() {
          _isSaved = true;
        });
      }
      // No need to call _checkIfSaved() here as we're directly setting _isSaved
    } catch (e) {
      print('Error toggling recipe save: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update recipe status. Please try again.', style: GoogleFonts.poppins()))
      );
      // Optionally, re-fetch state to be safe, or revert optimistic update
      _checkIfSaved(); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Suggested Recipe',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black)
        ),
        backgroundColor: const Color(0xFFF8AFAF),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border, color: Colors.black),
            onPressed: () => _toggleSaveRecipe(widget.recipe),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe title moved here, below the app bar
            Text(
              widget.recipe.title,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF4E342E),
              ),
            ),
            const SizedBox(height: 16), // Add spacing after title
            
            // Description
            Text(
              widget.recipe.description, 
              style: GoogleFonts.poppins(fontSize: 16, fontStyle: FontStyle.italic)
            ),
            const SizedBox(height: 12),
            
            // Capsules/Tags moved here (right after description)
            _buildCapsuleTags(),
            const SizedBox(height: 10),
            
            // Then cuisine and servings
            Text('Cuisine: ${widget.recipe.cuisineType}', style: GoogleFonts.poppins(fontSize: 14)),
            Text('Servings: ${widget.recipe.servings}', style: GoogleFonts.poppins(fontSize: 14)),
            
            // Display price range if available
            if (widget.recipe.priceRange != null && widget.recipe.priceRange!.isNotEmpty)
              Text('Price Range: ${widget.recipe.priceRange}', 
                 style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.green[700])),
            
            if (widget.recipe.allergens.isNotEmpty)
              Text('Allergens: ${widget.recipe.allergens.join(", ")}', style: GoogleFonts.poppins(fontSize: 14, color: Colors.red)),
            
            const SizedBox(height: 15),
            const Divider(thickness: 1), // Divider
            const SizedBox(height: 15),

            _buildSectionHeader('Ingredients'),
            ...widget.recipe.ingredients.map((ing) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0, left: 8.0),
              child: Text('• $ing', style: GoogleFonts.poppins(fontSize: 15)),
            )),
            
            const SizedBox(height: 15),
            const Divider(thickness: 1), // Divider
            const SizedBox(height: 15),

            _buildSectionHeader('Instructions'),
            ...widget.recipe.instructions.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
              child: Text('${entry.key + 1}. ${entry.value}', style: GoogleFonts.poppins(fontSize: 15)),
            )),

            if (widget.recipe.nutritionalValues.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Divider(thickness: 1),
              const SizedBox(height: 10),
              _buildSectionHeader('Nutritional Information (Estimated)'),
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                color: const Color(0xFFF8AFAF), // Changed background color
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.recipe.nutritionalValues.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 5.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.key, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.black87)),
                          Text(entry.value, style: GoogleFonts.poppins(color: Colors.black87)),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ),
            ],

            if (widget.recipe.healthBenefitsSummary.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(thickness: 1),
              const SizedBox(height: 10),
              _buildSectionHeader('Health Benefits'),
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                color: const Color(0xFFF8AFAF), // Changed background color
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    widget.recipe.healthBenefitsSummary,
                    style: GoogleFonts.poppins(fontSize: 15, height: 1.5, color: Colors.black87),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCapsuleTags() {
    List<Widget> tags = [];

    // Life Stage Tag
    if (widget.recipe.selectedLifeStage != null && widget.recipe.selectedLifeStage!.isNotEmpty) {
      tags.add(_buildTagChip(widget.recipe.selectedLifeStage!, Colors.blue[700]!));
    }

    // Dietary Preference Tags
    if (widget.recipe.wasVegetarian == true) {
      tags.add(_buildTagChip('Vegetarian', Colors.green[700]!));
    }
    if (widget.recipe.wasHalal == true) {
      tags.add(_buildTagChip('Halal', Colors.teal[700]!));
    }
    if (widget.recipe.wasBudgetFriendly == true) {
      tags.add(_buildTagChip('Budget-Friendly', Colors.orange[700]!));
    }

    // Fallback tag (optional)
    if (tags.isEmpty && widget.recipe.healthBenefitsSummary.isNotEmpty) {
        tags.add(_buildTagChip('Tailored Recipe', Colors.purple[700]!));
    }

    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        children: tags,
      ),
    );
  }

  Widget _buildTagChip(String label, Color color) {
    return Chip(
      label: Text(label, style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4.0), // Adjust padding
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF4E342E)),
      ),
    );
  }
}

class NutritionMealsScreen extends StatefulWidget {
  const NutritionMealsScreen({Key? key}) : super(key: key);

  @override
  _NutritionMealsScreenState createState() => _NutritionMealsScreenState();
}

class _NutritionMealsScreenState extends State<NutritionMealsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  GenerativeModel? _geminiModel;
  bool _isLoadingRecipe = false;
  List<Recipe> _savedRecipes = [];
  bool _isLoadingSavedRecipes = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _selectedStage;
  final TextEditingController _ingredientsController = TextEditingController();
  Set<String> _selectedStaples = {};
  Set<String> _selectedCuisines = {};
  bool _isVegetarian = false;
  bool _isHalal = false;
  Set<String> _selectedAllergies = {};
  bool _isBudgetFriendly = false;

  final List<String> _lifeStages = [
    'Trying to Conceive', 'Pregnant - Trimester 1', 'Pregnant - Trimester 2', 
    'Pregnant - Trimester 3', 'Postpartum - Breastfeeding', 
    'Postpartum - Not Breastfeeding', 'Partner/General Health'
  ];
  final List<String> _stapleIngredients = ['Oil', 'Butter', 'Flour', 'Salt', 'Pepper', 'Sugar', 'Milk', 'Vinegar', 'Onion', 'Garlic'];
  final List<String> _cuisines = ['Any','Italian', 'Mexican', 'American', 'French', 'Japanese', 'Chinese', 'Indian', 'Greek', 'Moroccan', 'Ethiopian', 'South African', 'Malay', 'Thai', 'Vietnamese'];
  final List<String> _allergiesList = ['Dairy', 'Eggs', 'Nuts', 'Soy', 'Gluten', 'Fish', 'Shellfish', 'Sesame', 'Mustard'];

  String? _apiKey;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    
    // Initialize the Gemini model with the same API key and model as in HealthHelpPage
    _apiKey = dotenv.env['GEMINI_API_KEY'];
    if (_apiKey != null) {
      _geminiModel = GenerativeModel(model: 'gemini-1.5-flash-latest', apiKey: _apiKey!);
    } else {
      print("GEMINI_API_KEY not found in .env file");
      // Optionally show an error to the user
    }
    
    _loadSavedRecipes();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      if (_tabController.index == 1) { // Saved Recipes tab
        _loadSavedRecipes();
      }
    }
  }

  Future<void> _loadSavedRecipes() async {
    setState(() => _isLoadingSavedRecipes = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final recipesSnapshot = await _firestore
            .collection('recipes')
            .where('userId', isEqualTo: user.uid)
            .get();
            
        setState(() {
          _savedRecipes = recipesSnapshot.docs
              .map((doc) => Recipe.fromJson(doc.data()))
              .toList();
        });
      }
    } catch (e) {
      print('Error loading recipes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load recipes', style: GoogleFonts.poppins()))
      );
    } finally {
      setState(() => _isLoadingSavedRecipes = false);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _ingredientsController.dispose();
    super.dispose();
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF6D4C41)),
      ),
    );
  }

  Widget _buildFilterChip(String label, Set<String> selectedSet, {Color? selectedColor, Color? labelColor}) {
    final bool isSelected = selectedSet.contains(label);
    return FilterChip(
      label: Text(label, style: GoogleFonts.poppins(color: isSelected ? Colors.white : (labelColor ?? Colors.black87))),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          if (selected) {
            if (label == 'Any' && selectedSet == _selectedCuisines) {
                _selectedCuisines.clear();
                _selectedCuisines.add('Any');
            } else {
                if (selectedSet == _selectedCuisines) _selectedCuisines.remove('Any');
                selectedSet.add(label);
            }
          } else {
            selectedSet.remove(label);
          }
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: selectedColor ?? const Color(0xFF005792), 
      checkmarkColor: Colors.white,
      elevation: isSelected ? 2.0 : 0.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: isSelected ? (selectedColor ?? const Color(0xFF005792)) : Colors.grey[400]!)
      ),
    );
  }

  Future<void> _generateRecipe() async {
    if (_geminiModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recipe generation service is unavailable.', style: GoogleFonts.poppins()))
      );
      return;
    }
    setState(() => _isLoadingRecipe = true);

    final userIngredients = _ingredientsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    
    String promptText = '''
You are a helpful AI assistant specializing in creating recipes for individuals with specific dietary needs and preferences during various life stages related to pregnancy and family planning.

Generate a recipe based on the following user profile and preferences:
Life Stage: ${_selectedStage ?? "Not specified"}
Ingredients on hand: ${userIngredients.isEmpty ? "None specified, suggest common pantry items" : userIngredients.join(", ")}
Staple ingredients available: ${_selectedStaples.isEmpty ? "None specified" : _selectedStaples.join(", ")}
Preferred Cuisines: ${_selectedCuisines.isEmpty || _selectedCuisines.contains("Any") ? "Any cuisine is fine" : _selectedCuisines.join(", ")}
Dietary Restrictions:
  Vegetarian: ${_isVegetarian ? "Yes" : "No"}
  Halal: ${_isHalal ? "Yes" : "No"}
Allergies/Avoidances: ${_selectedAllergies.isEmpty ? "None specified" : _selectedAllergies.join(", ")}
Budget-Friendly Mode: ${_isBudgetFriendly ? "Yes, prioritize affordable ingredients and minimize waste." : "No special budget considerations."}

Provide a unique recipe. If ingredients are scarce, suggest a simple recipe or one that utilizes common pantry staples effectively.
If "Halal" is Yes, ensure all ingredients and preparation methods are Halal-compliant. Avoid pork and alcohol.
If "Vegetarian" is Yes, ensure no meat, poultry, or fish is used. Eggs and dairy are okay unless specified in allergies.
Consider the "Life Stage" for nutritional appropriateness if possible (e.g., folate for trying to conceive/pregnancy, iron for postpartum).

Please also provide:
1. Estimated nutritional values for the recipe (e.g., Calories, Protein, Carbohydrates, Fats, and 2-3 key micronutrients relevant to the life stage like Folate, Iron, Calcium).
2. A brief health benefits summary (2-3 sentences) explaining how this recipe is beneficial for the specified "Life Stage". If no stage is specified, provide general benefits.

Return the recipe IN JSON FORMAT ONLY, using the following structure. Do not include any other text or explanation outside the JSON structure.
Ensure all string values in the JSON are properly escaped.
Ingredients and Instructions should be lists of strings.
Allergens should be a list of common allergens present in the recipe (e.g., "Dairy", "Gluten", "Nuts"). If none, provide an empty list.
NutritionalValues should be a map of nutrient to value (e.g., "Calories": "350 kcal", "Protein": "20g").

{
  "id": "A_UNIQUE_RECIPE_ID_OR_TIMESTAMP",
  "title": "Recipe Title",
  "description": "A brief, appealing description of the recipe (2-3 sentences).",
  "cuisineType": "e.g., Italian, Mexican, Indian (be specific)",
  "servings": "e.g., 2-3 servings, 4 servings",
  "ingredients": [
    "Ingredient 1 with quantity (e.g., 1 cup flour)",
    "Ingredient 2 with quantity (e.g., 2 large eggs)"
  ],
  "instructions": [
    "Step 1...",
    "Step 2...",
    "Step 3..."
  ],
  "allergens": ["e.g., Gluten", "e.g., Dairy"],
  "nutritionalValues": {
    "Calories": "Approx. XXX kcal",
    "Protein": "Approx. XXg",
    "Carbohydrates": "Approx. XXg",
    "Fats": "Approx. XXg",
    "KeyNutrient1Name": "Approx. XXunit (e.g., Folate: 400mcg)"
  },
  "healthBenefitsSummary": "This recipe is beneficial for [Life Stage] because..."
}
''';

    try {
      final response = await _geminiModel!.generateContent([Content.text(promptText)]);
      final responseText = response.text;

      if (responseText != null) {
        String cleanedJson = responseText.trim();
        if (cleanedJson.startsWith("```json")) {
          cleanedJson = cleanedJson.substring(7);
        }
        if (cleanedJson.startsWith("```")) {
          cleanedJson = cleanedJson.substring(3);
        }
        if (cleanedJson.endsWith("```")) {
          cleanedJson = cleanedJson.substring(0, cleanedJson.length - 3);
        }
        cleanedJson = cleanedJson.trim();
        
        print("Cleaned Gemini Response JSON: $cleanedJson"); // For debugging

        final recipeJson = jsonDecode(cleanedJson) as Map<String, dynamic>;
        final aiRecipe = Recipe.fromJson(recipeJson);
        
        // Get price range if budget-friendly is selected
        String? priceRange;
        if (_isBudgetFriendly) {
          try {
            final pricePrompt = '''
Based on the following recipe, please estimate its price range (low, medium, or high cost) and 
provide an approximate cost range in Malaysian Ringgit (MYR) for the entire recipe. Consider standard grocery prices 
in Malaysia. Make your response as concise as possible, providing just the estimated price 
range (like "Low-cost: RM5-8 total").

Recipe: ${aiRecipe.title}
Ingredients: ${aiRecipe.ingredients.join(", ")}
Cuisine: ${aiRecipe.cuisineType}
Servings: ${aiRecipe.servings}
''';
            final priceResponse = await _geminiModel!.generateContent([Content.text(pricePrompt)]);
            if (priceResponse.text != null) {
              priceRange = priceResponse.text!.trim();
            }
          } catch (e) {
            print('Error getting price range: $e');
            // Continue without price range if there's an error
          }
        }
        
        // Then, create the final recipe object that includes user's selections
        final finalRecipe = Recipe(
          id: aiRecipe.id,
          title: aiRecipe.title,
          description: aiRecipe.description,
          cuisineType: aiRecipe.cuisineType,
          servings: aiRecipe.servings,
          ingredients: aiRecipe.ingredients,
          instructions: aiRecipe.instructions,
          allergens: aiRecipe.allergens,
          nutritionalValues: aiRecipe.nutritionalValues,
          healthBenefitsSummary: aiRecipe.healthBenefitsSummary,
          priceRange: priceRange,
          selectedLifeStage: _selectedStage,
          wasVegetarian: _isVegetarian,
          wasHalal: _isHalal,
          wasBudgetFriendly: _isBudgetFriendly
        );
        
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RecipeDisplayScreen(recipe: finalRecipe)),
        );

      } else {
        throw Exception("Empty response from Gemini.");
      }
    } catch (e) {
      print('Error generating or parsing recipe: $e');
      print('Original Gemini Response: ${e is GenerativeAIException ? e.message : (e is FormatException ? e.source : "N/A")}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate recipe. Please try again. Error: ${e.toString().substring(0,100)}', style: GoogleFonts.poppins()))
      );
    } finally {
      setState(() => _isLoadingRecipe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nutrition & Meals',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: const Color(0xFFF8AFAF),
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(),
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black.withOpacity(0.7),
          indicatorColor: const Color(0xFF6D4C41),
          tabs: const [
            Tab(text: 'Create Recipe'),
            Tab(text: 'Saved Recipes'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildCreateRecipeTab(),
            _buildSavedRecipesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateRecipeTab() {
    // Simplified layout for better scrolling and overflow handling
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Your Profile/Stage'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.grey.shade400)
            ),
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                border: InputBorder.none,
                 hintText: 'Select your current stage',
              ),
              hint: Text('Select your current stage', style: GoogleFonts.poppins(color: Colors.grey[600])),
              value: _selectedStage,
              items: _lifeStages.map((String stage) {
                return DropdownMenuItem<String>(
                  value: stage,
                  child: Text(stage, style: GoogleFonts.poppins()),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedStage = newValue;
                });
              },
              isExpanded: true,
            ),
          ),

          _buildSectionTitle('Ingredients You Have (comma-separated)'),
          TextField(
            controller: _ingredientsController,
            decoration: InputDecoration(
              hintText: 'e.g., chicken breast, broccoli, rice',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: Colors.grey.shade400)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: Color(0xFF6D4C41), width: 2)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            ),
            style: GoogleFonts.poppins(),
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.done,
          ),

          _buildSectionTitle('Staple Ingredients You Also Have'),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: _stapleIngredients.map((staple) => _buildFilterChip(staple, _selectedStaples, selectedColor: Colors.teal[400])).toList(),
          ),
          
          _buildSectionTitle('Cuisine Preference(s)'),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: _cuisines.map((cuisine) => _buildFilterChip(cuisine, _selectedCuisines, selectedColor: Colors.orange[600])).toList(),
          ),

          _buildSectionTitle('Dietary Preferences'),
          SwitchListTile(
            title: Text('Vegetarian', style: GoogleFonts.poppins()),
            value: _isVegetarian,
            onChanged: (bool value) => setState(() => _isVegetarian = value),
            activeColor: const Color(0xFF6D4C41),
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text('Halal', style: GoogleFonts.poppins()),
            value: _isHalal,
            onChanged: (bool value) => setState(() => _isHalal = value),
            activeColor: const Color(0xFF6D4C41),
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text('Budget-Friendly Mode', style: GoogleFonts.poppins()),
            value: _isBudgetFriendly,
            onChanged: (bool value) => setState(() => _isBudgetFriendly = value),
            activeColor: const Color(0xFF6D4C41),
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),

          _buildSectionTitle('Allergies / Avoidances'),
           Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: _allergiesList.map((allergy) => _buildFilterChip(allergy, _selectedAllergies, selectedColor: Colors.redAccent[400])).toList(),
          ),

          const SizedBox(height: 30),
          Center(
            child: _isLoadingRecipe 
            ? const CircularProgressIndicator(color: Color(0xFF6D4C41))
            : ElevatedButton(
                onPressed: _generateRecipe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6D4C41),
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                ),
                child: Text(
                  'Generate Recipe',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
          ),
          const SizedBox(height: 20), // Padding at the bottom
        ],
      ),
    );
  }

  Widget _buildSavedRecipesTab() {
    if (_isLoadingSavedRecipes) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6D4C41)));
    }
    if (_savedRecipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bookmark_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            Text(
              _isLoadingSavedRecipes ? 'Loading...' : 'No saved recipes yet.',
              style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _savedRecipes.length,
      itemBuilder: (context, index) {
        final recipe = _savedRecipes[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            title: Text(recipe.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Color(0xFF6D4C41))),
            subtitle: Text(recipe.description, style: GoogleFonts.poppins(), maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF6D4C41)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RecipeDisplayScreen(recipe: recipe)),
              ).then((_) => _loadSavedRecipes()); // Refresh list if a recipe is unsaved from display screen
            },
          ),
        );
      },
    );
  }
} 
import Foundation

/// JSON Schema for OpenAI Structured Outputs (strict mode).
/// Kept as a literal so property order is preserved: the model fills `items`
/// before the totals in `nutrients`, which makes the totals add up.
enum NutritionSchema {
    static let json = #"""
    {
      "type": "object",
      "additionalProperties": false,
      "required": ["is_food", "not_food_reason", "input_type", "name", "summary", "category", "items", "serving_description", "estimated_weight_grams", "servings_per_container", "nutrients", "ingredients", "allergens", "dietary_tags", "processing_level", "glycemic_impact", "health_score", "confidence", "insights"],
      "properties": {
        "is_food": { "type": "boolean", "description": "False if the input contains no food or drink." },
        "not_food_reason": { "type": ["string", "null"], "description": "Why this is not food. Null when is_food is true." },
        "input_type": { "type": "string", "enum": ["food_photo", "nutrition_label", "packaged_product", "text_description"] },
        "name": { "type": "string", "description": "Short dish or product name, e.g. 'Rajma Chawal' or 'Coca-Cola Classic (330 ml can)'." },
        "summary": { "type": "string", "description": "One sentence describing what was identified, including portion and cooking style." },
        "category": { "type": "string", "enum": ["home_cooked", "restaurant", "fast_food", "packaged", "beverage", "fruit_vegetable", "snack", "dessert", "other"] },
        "items": {
          "type": "array",
          "description": "Each distinct component of one serving. Their sums must match nutrients.",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": ["name", "portion", "calories", "protein_g", "carbs_g", "fat_g"],
            "properties": {
              "name": { "type": "string" },
              "portion": { "type": "string", "description": "e.g. '1 cup (180 g)', '2 pieces', '1 tbsp oil'" },
              "calories": { "type": "number" },
              "protein_g": { "type": "number" },
              "carbs_g": { "type": "number" },
              "fat_g": { "type": "number" }
            }
          }
        },
        "serving_description": { "type": "string", "description": "What one serving is, e.g. '1 plate (~450 g)', '1 can (330 ml)', '2 biscuits (25 g)'." },
        "estimated_weight_grams": { "type": ["number", "null"], "description": "Total weight (g) or volume (ml) of one serving." },
        "servings_per_container": { "type": ["number", "null"], "description": "For packaged products, servings per pack if known; otherwise null." },
        "nutrients": {
          "type": "object",
          "additionalProperties": false,
          "description": "Totals for ONE serving.",
          "required": ["calories", "protein_g", "carbs_g", "fat_g", "fiber_g", "sugar_g", "added_sugar_g", "saturated_fat_g", "trans_fat_g", "cholesterol_mg", "sodium_mg", "potassium_mg", "calcium_mg", "iron_mg", "vitamin_a_mcg", "vitamin_c_mg", "vitamin_d_mcg", "caffeine_mg", "alcohol_g"],
          "properties": {
            "calories": { "type": "number", "description": "kcal" },
            "protein_g": { "type": "number" },
            "carbs_g": { "type": "number" },
            "fat_g": { "type": "number" },
            "fiber_g": { "type": ["number", "null"] },
            "sugar_g": { "type": ["number", "null"] },
            "added_sugar_g": { "type": ["number", "null"] },
            "saturated_fat_g": { "type": ["number", "null"] },
            "trans_fat_g": { "type": ["number", "null"] },
            "cholesterol_mg": { "type": ["number", "null"] },
            "sodium_mg": { "type": ["number", "null"] },
            "potassium_mg": { "type": ["number", "null"] },
            "calcium_mg": { "type": ["number", "null"] },
            "iron_mg": { "type": ["number", "null"] },
            "vitamin_a_mcg": { "type": ["number", "null"], "description": "mcg RAE" },
            "vitamin_c_mg": { "type": ["number", "null"] },
            "vitamin_d_mcg": { "type": ["number", "null"] },
            "caffeine_mg": { "type": ["number", "null"] },
            "alcohol_g": { "type": ["number", "null"] }
          }
        },
        "ingredients": { "type": "array", "items": { "type": "string" } },
        "allergens": { "type": "array", "items": { "type": "string" } },
        "dietary_tags": { "type": "array", "items": { "type": "string" } },
        "processing_level": { "type": "string", "enum": ["unprocessed", "minimally_processed", "processed", "ultra_processed"] },
        "glycemic_impact": { "type": "string", "enum": ["low", "medium", "high", "not_applicable"] },
        "health_score": { "type": "integer", "description": "1 (least healthy) to 10 (most healthy)." },
        "confidence": { "type": "string", "enum": ["low", "medium", "high"] },
        "insights": { "type": "array", "items": { "type": "string" } }
      }
    }
    """#
}

enum NutritionPrompts {
    static let system = """
    You are NutriCheck, an expert registered dietitian and food scientist. You analyze a photo (or a text description) of food or drink and return an accurate nutrition estimate as structured data.

    1. Work out what the input shows (input_type):
       - nutrition_label: a Nutrition Facts / nutrition information panel is readable. Transcribe values EXACTLY as printed for ONE serving as defined on the label. If only kJ is shown, convert (1 kcal = 4.184 kJ). If the label lists only per-100 g/ml values, use the stated serving size when given, otherwise use 100 g/ml as the serving and say so in serving_description. Copy the ingredient list and allergen statement if visible. Set servings_per_container when printed.
       - packaged_product: the packaging or brand is visible but the nutrition panel is not. Identify the exact product and use its published nutrition values.
       - food_photo: a meal, dish, snack, fruit, drink or anything else to eat.
       - text_description: there is no image, only the user's description.

    2. For meals and dishes, identify every distinct component (e.g. rice, dal, sabzi, roti, raita, salad, chutney, sauce, toppings) and list each in items. Estimate portions from visual cues: a dinner plate is about 25–27 cm, a katori/small bowl about 150 ml, plus cutlery, hands and packaging for scale. Account for hidden calories: cooking oil, ghee, butter, cream, sugar, dressings, frying and gravies. You know world cuisines, including home-style and regional cooking (Indian, Chinese, Mexican, Italian, Middle Eastern, Japanese, etc.). If the food comes from a recognizable restaurant or fast-food chain (logo, packaging, signature item), use that chain's published nutrition data.

    3. For drinks, estimate the volume from the container and account for milk, sugar, syrups and toppings. Always report caffeine (coffee, tea, energy drinks, colas) and alcohol where relevant.

    4. One serving is everything visible: the whole portion the user is about to eat or drink. For nutrition labels, one serving is the label's serving. Describe it in serving_description.

    5. nutrients are totals for ONE serving and must equal the sum of items (within rounding). Calories must be consistent with the macros: about 4 × protein + 4 × carbs + 9 × fat + 7 × alcohol.

    6. Give your best estimate for every micronutrient. Use 0 when a nutrient is genuinely absent (e.g. cholesterol in plant foods, caffeine in juice). Use null only when a value truly cannot be estimated.

    7. ingredients: from the label if visible, otherwise the main likely ingredients. allergens: only allergens likely present, chosen from milk, egg, fish, shellfish, tree nuts, peanuts, wheat/gluten, soy, sesame, mustard, celery and sulphites. dietary_tags: short applicable tags such as vegetarian, vegan, eggetarian, gluten-free, high-protein, high-fiber, low-carb, keto-friendly, high-sugar, high-sodium, deep-fried, whole-grain.

    8. health_score: an integer from 1 to 10. 10 is a nutrient-dense, balanced whole food. 1 is ultra-processed, high in sugar, saturated fat or sodium, and low in nutrients.

    9. insights: 2 to 4 short, specific, practical points. Cover nutritional highlights, concerns, and one concrete tip (a healthier swap, or what to pair it with). No generic filler.

    10. confidence: high for readable labels and known branded items, medium for clearly identifiable dishes, low when the image is unclear or the portion is hard to judge.

    11. If the input contains no food or drink, set is_food to false, explain why in not_food_reason, and fill the other fields with empty strings, zeros and empty arrays.

    12. Details the user provides (portion eaten, cooking method, brand, "I ate half", etc.) are authoritative and override what you see.

    Use concise English names; you may add the local name, e.g. "Chole Bhature (chickpea curry with fried bread)".
    """
}

import * as admin from 'firebase-admin';

/**
 * Struttura Dati Firestore per Ricette Spoonacular
 *
 * Collection: spoonacular_recipes
 * Document ID: spoonacular_recipe_id (es: "716429")
 */

export interface SpoonacularRecipe {
  // Identificatori
  spoonacularId: number;
  title: string;

  // Informazioni base
  image: string;
  imageType: string;
  creditsText: string;
  sourceUrl: string;
  spoonacularSourceUrl: string;

  // Dettagli ricetta
  readyInMinutes: number;
  servings: number;
  pricePerServing: number;
  healthScore: number;

  // Ingredienti
  extendedIngredients: Array<{
    id: number;
    aisle: string;
    image: string;
    name: string;
    amount: number;
    unit: string;
    unitShort: string;
    original: string;
    meta: string[];
  }>;

  // Istruzioni
  analyzedInstructions: Array<{
    name: string;
    steps: Array<{
      number: number;
      step: string;
      ingredients: Array<{ id: number; name: string; image: string }>;
      equipment: Array<{ id: number; name: string; image: string }>;
    }>;
  }>;

  // Nutrienti
  nutrition: {
    nutrients: Array<{
      name: string;
      amount: number;
      unit: string;
      percentOfDailyNeeds: number;
    }>;
    caloricBreakdown: {
      percentProtein: number;
      percentFat: number;
      percentCarbs: number;
    };
  };

  // Dieta e allergeni
  diets: string[];
  dishTypes: string[];
  cuisines: string[];

  // Metadati caching
  cachedAt: admin.firestore.Timestamp;
  expiresAt: admin.firestore.Timestamp; // Cache per 7 giorni
  lastUpdated: admin.firestore.Timestamp;
}

/**
 * Collection: image_credits
 * Document ID: image_url_hash (per evitare duplicati)
 */
export interface ImageCredit {
  imageUrl: string;
  photographer: string;
  source: string; // es: "Unsplash", "Spoonacular"
  sourceUrl: string;
  attributionText: string;
  cachedAt: admin.firestore.Timestamp;
}

/**
 * Collection: api_usage_log
 * Per monitorare l'utilizzo dell'API Spoonacular
 */
export interface ApiUsageLog {
  endpoint: string;
  timestamp: admin.firestore.Timestamp;
  success: boolean;
  error?: string;
  recipeId?: number;
}

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import axios from 'axios';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { defineSecret } from 'firebase-functions/params';

// Define secrets using the new system
const geminiApiKey = defineSecret('GEMINI_API_KEY');
const spoonacularApiKey = defineSecret('SPOONACULAR_API_KEY');
const unsplashAccessKey = defineSecret('UNSPLASH_ACCESS_KEY');

const db = admin.firestore();
const SPOONACULAR_BASE_URL = 'https://api.spoonacular.com/recipes';
const UNSPLASH_SEARCH_URL = 'https://api.unsplash.com/search/photos';
const UNSPLASH_SOURCE_URL = 'https://source.unsplash.com/800x600/?food';
const CACHE_DURATION_DAYS = 7;

/**
 * Firebase Cloud Function per suggerire ricette usando Gemini
 * Pipeline: Gemini → Spoonacular → Unsplash → Firestore
 *
 * Endpoint: /suggestRecipe
 * Method: POST
 *
 * Body: { ingredients: string[], preferences?: string }
 */
export const suggestRecipe = functions.https.onRequest(
  { secrets: [geminiApiKey, spoonacularApiKey, unsplashAccessKey] },
  async (req, res) => {
    // Enable CORS
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    const { ingredients, preferences } = req.body;

    if (!ingredients || !Array.isArray(ingredients) || ingredients.length === 0) {
      res.status(400).json({ error: 'ingredients must be a non-empty array' });
      return;
    }

    try {
      // Step 1: Generate cache key based on ingredients and preferences
      const cacheKey = generateCacheKey(ingredients, preferences);

      // Step 2: Check if suggestion exists in Firestore cache
      const cacheDoc = await db.collection('gemini_suggestions').doc(cacheKey).get();

      if (cacheDoc.exists) {
        const cachedData = cacheDoc.data();
        const expiresAt = cachedData?.expiresAt?.toDate();

        if (expiresAt && expiresAt > new Date()) {
          console.log(`Suggestion found in cache for key: ${cacheKey}`);
          res.json(cachedData);
          return;
        } else {
          console.log(`Suggestion cache expired, regenerating...`);
        }
      }

      // Step 3: Call Gemini to get recipe suggestion
      console.log('Calling Gemini API for recipe suggestion');
      const geminiSuggestion = await getGeminiSuggestion(ingredients, preferences);

      // Step 4: Search Spoonacular for recipe details
      console.log('Searching Spoonacular for recipe details');
      const spoonacularRecipe = await searchSpoonacularRecipe(geminiSuggestion.title);

      // Step 5: Get image from Unsplash
      console.log('Fetching image from Unsplash');
      const imageUrl = await getUnsplashImage(geminiSuggestion.title);

      // Step 6: Save to Firestore with caching metadata
      const now = admin.firestore.Timestamp.now();
      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + CACHE_DURATION_DAYS);

      const recipeToSave = {
        ...spoonacularRecipe,
        imageUrl: imageUrl,
        geminiSuggestion: geminiSuggestion,
        originalIngredients: ingredients,
        originalPreferences: preferences,
        cachedAt: now,
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        lastUpdated: now,
      };

      await db.collection('gemini_suggestions').doc(cacheKey).set(recipeToSave);

      // Step 7: Save image credits
      if (imageUrl) {
        await saveImageCredits(imageUrl, 'Gemini AI + Unsplash');
      }

      // Step 8: Log API usage
      await logApiUsage('suggestRecipe', true, null, cacheKey);

      res.json(recipeToSave);

    } catch (error) {
      console.error('Error in suggestRecipe pipeline:', error);

      // Log API usage failure
      await logApiUsage('suggestRecipe', false, null, error.message);

      if (error.response) {
        res.status(error.response.status).json({
          error: 'API error',
          message: error.response.data,
        });
      } else {
        res.status(500).json({
          error: 'Internal server error',
          message: error.message,
        });
      }
    }
  }
);

/**
 * Generate cache key from ingredients and preferences
 */
function generateCacheKey(ingredients: string[], preferences?: string): string {
  const ingredientsStr = ingredients.sort().join(',');
  const prefsStr = preferences || '';
  const combined = `${ingredientsStr}|${prefsStr}`;
  
  // Simple hash function
  let hash = 0;
  for (let i = 0; i < combined.length; i++) {
    const char = combined.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32bit integer
  }
  
  return Math.abs(hash).toString(36);
}

/**
 * Get recipe suggestion from Gemini AI
 */
async function getGeminiSuggestion(ingredients: string[], preferences?: string): Promise<any> {
  const apiKey = geminiApiKey.value();
  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({ model: 'gemini-pro' });

  const prompt = `Sei un assistente chef esperto. Suggerisci UNA ricetta usando questi ingredienti: ${ingredients.join(', ')}.
${preferences ? `Preferenze: ${preferences}.` : ''}

Rispondi in formato JSON con questa struttura:
{
  "title": "Nome della ricetta",
  "description": "Breve descrizione della ricetta",
  "cuisine": "Tipo di cucina (es: Italiana, Asiatica, Messicana)",
  "difficulty": "Facile/Media/Difficile",
  "prepTime": "Tempo di preparazione in minuti",
  "servings": "Numero di porzioni"
}

Rispondi SOLO con il JSON, senza testo aggiuntivo.`;

  try {
    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();

    // Parse JSON response
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      throw new Error('Invalid JSON response from Gemini');
    }

    return JSON.parse(jsonMatch[0]);
  } catch (error) {
    console.error('Gemini API error:', error);
    throw new Error('Failed to get suggestion from Gemini');
  }
}

/**
 * Search Spoonacular for recipe details
 */
async function searchSpoonacularRecipe(title: string): Promise<any> {
  try {
    const apiKey = spoonacularApiKey.value();
    // Search for recipes by title
    const searchResponse = await axios.get(
      `${SPOONACULAR_BASE_URL}/complexSearch?apiKey=${apiKey}&query=${encodeURIComponent(title)}&number=1&addRecipeInformation=true&addRecipeInstructions=true&addRecipeNutrition=true`
    );

    if (searchResponse.data.results && searchResponse.data.results.length > 0) {
      const recipe = searchResponse.data.results[0];

      // Get full recipe information
      const infoResponse = await axios.get(
        `${SPOONACULAR_BASE_URL}/${recipe.id}/information?apiKey=${apiKey}&includeNutrition=true`
      );

      return infoResponse.data;
    } else {
      // If no exact match found, return a basic structure
      return {
        spoonacularId: null,
        title: title,
        image: null,
        readyInMinutes: 30,
        servings: 4,
        extendedIngredients: [],
        analyzedInstructions: [],
        nutrition: null,
      };
    }
  } catch (error) {
    console.error('Spoonacular API error:', error);
    // Return basic structure if Spoonacular fails
    return {
      spoonacularId: null,
      title: title,
      image: null,
      readyInMinutes: 30,
      servings: 4,
      extendedIngredients: [],
      analyzedInstructions: [],
      nutrition: null,
    };
  }
}

/**
 * Get image from Unsplash
 */
async function getUnsplashImage(query: string): Promise<string | null> {
  try {
    const accessKey = unsplashAccessKey.value();
    // Try Unsplash Search API first if access key is available
    if (accessKey) {
      const response = await axios.get(
        `${UNSPLASH_SEARCH_URL}?query=${encodeURIComponent(query + ' food')}&per_page=1&client_id=${accessKey}`
      );

      if (response.data.results && response.data.results.length > 0) {
        return response.data.results[0].urls.regular;
      }
    }

    // Fallback to Unsplash Source API
    return `${UNSPLASH_SOURCE_URL}&${encodeURIComponent(query)}`;
  } catch (error) {
    console.error('Unsplash API error:', error);
    return null;
  }
}

/**
 * Save image credits to Firestore
 */
async function saveImageCredits(imageUrl: string, source: string): Promise<void> {
  try {
    const crypto = require('crypto');
    const imageHash = crypto.createHash('md5').update(imageUrl).digest('hex');

    const creditDoc = await db.collection('image_credits').doc(imageHash).get();

    if (!creditDoc.exists) {
      await db.collection('image_credits').doc(imageHash).set({
        imageUrl,
        photographer: 'Unknown',
        source: source,
        sourceUrl: imageUrl,
        attributionText: `Image from ${source}`,
        cachedAt: admin.firestore.Timestamp.now(),
      });
    }
  } catch (error) {
    console.error('Error saving image credits:', error);
  }
}

/**
 * Log API usage for monitoring
 */
async function logApiUsage(
  endpoint: string,
  success: boolean,
  recipeId?: number | null,
  error?: string
): Promise<void> {
  try {
    await db.collection('api_usage_log').add({
      endpoint,
      timestamp: admin.firestore.Timestamp.now(),
      success,
      error,
      recipeId,
    });
  } catch (logError) {
    console.error('Error logging API usage:', logError);
  }
}

/**
 * Callable function for recipe suggestions (for Flutter integration)
 */
export const suggestRecipeCallable = functions.https.onCall(
  { secrets: [geminiApiKey, spoonacularApiKey, unsplashAccessKey] },
  async (data, context) => {
    const { ingredients, preferences } = data;

    if (!ingredients || !Array.isArray(ingredients) || ingredients.length === 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'ingredients must be a non-empty array'
      );
    }

    try {
      // Generate cache key
      const cacheKey = generateCacheKey(ingredients, preferences);

      // Check cache
      const cacheDoc = await db.collection('gemini_suggestions').doc(cacheKey).get();

      if (cacheDoc.exists) {
        const cachedData = cacheDoc.data();
        const expiresAt = cachedData?.expiresAt?.toDate();

        if (expiresAt && expiresAt > new Date()) {
          return { ...cachedData, cached: true };
        }
      }

      // Get Gemini suggestion
      const geminiSuggestion = await getGeminiSuggestion(ingredients, preferences);

      // Search Spoonacular
      const spoonacularRecipe = await searchSpoonacularRecipe(geminiSuggestion.title);

      // Get Unsplash image
      const imageUrl = await getUnsplashImage(geminiSuggestion.title);

      // Save to Firestore
      const now = admin.firestore.Timestamp.now();
      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + CACHE_DURATION_DAYS);

      const recipeToSave = {
        ...spoonacularRecipe,
        imageUrl: imageUrl,
        geminiSuggestion: geminiSuggestion,
        originalIngredients: ingredients,
        originalPreferences: preferences,
        cachedAt: now,
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        lastUpdated: now,
      };

      await db.collection('gemini_suggestions').doc(cacheKey).set(recipeToSave);

      if (imageUrl) {
        await saveImageCredits(imageUrl, 'Gemini AI + Unsplash');
      }

      await logApiUsage('suggestRecipeCallable', true, null, cacheKey);

      return { ...recipeToSave, cached: false };

    } catch (error) {
      await logApiUsage('suggestRecipeCallable', false, null, error.message);
      throw new functions.https.HttpsError(
        'internal',
        error.message
      );
    }
  }
);

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import axios from 'axios';
import crypto from 'crypto';
import { defineSecret } from 'firebase-functions/params';

// Initialize Firebase Admin
admin.initializeApp();

// Define secrets using the new system
const spoonacularApiKey = defineSecret('SPOONACULAR_API_KEY');

const db = admin.firestore();
const SPOONACULAR_BASE_URL = 'https://api.spoonacular.com/recipes';
const CACHE_DURATION_DAYS = 7;

/**
 * Firebase Cloud Function per ottenere ricette da Spoonacular con caching su Firestore
 *
 * Endpoint: /getRecipe/{recipeId}
 * Method: GET
 *
 * @param recipeId - L'ID della ricetta di Spoonacular (es: 716429)
 */
export const getRecipe = functions.https.onRequest(
  { secrets: [spoonacularApiKey] },
  async (req, res) => {
    // Enable CORS
    res.set('Access-Control-Allow-Origin', '*');

    if (req.method !== 'GET') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    const recipeId = req.params.recipeId;

    if (!recipeId || isNaN(Number(recipeId))) {
      res.status(400).json({ error: 'Invalid recipe ID' });
      return;
    }

    try {
      // Step 1: Check if recipe exists in Firestore
      const recipeDoc = await db.collection('spoonacular_recipes').doc(recipeId).get();

      if (recipeDoc.exists) {
        const recipeData = recipeDoc.data();

        // Check if cache is still valid
        const expiresAt = recipeData?.expiresAt?.toDate();
        if (expiresAt && expiresAt > new Date()) {
          console.log(`Recipe ${recipeId} found in cache`);
          res.json(recipeData);
          return;
        } else {
          console.log(`Recipe ${recipeId} cache expired, refreshing...`);
        }
      }

      // Step 2: Fetch from Spoonacular API
      console.log(`Fetching recipe ${recipeId} from Spoonacular API`);
      const spoonacularData = await fetchRecipeFromSpoonacular(recipeId);

      // Step 3: Save to Firestore with caching metadata
      const now = admin.firestore.Timestamp.now();
      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + CACHE_DURATION_DAYS);

      const recipeToSave = {
        ...spoonacularData,
        cachedAt: now,
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        lastUpdated: now,
      };

      await db.collection('spoonacular_recipes').doc(recipeId).set(recipeToSave);

      // Step 4: Save image credits
      if (spoonacularData.image && spoonacularData.creditsText) {
        await saveImageCredits(spoonacularData.image, spoonacularData.creditsText);
      }

      // Step 5: Log API usage
      await logApiUsage('getRecipe', true, Number(recipeId));

      res.json(recipeToSave);

    } catch (error) {
      console.error('Error fetching recipe:', error);

      // Log API usage failure
      await logApiUsage('getRecipe', false, Number(recipeId), error.message);

      if (error.response) {
        // Spoonacular API error
        res.status(error.response.status).json({
          error: 'Spoonacular API error',
          message: error.response.data,
        });
      } else if (error.code === 'ECONNREFUSED') {
        res.status(503).json({
          error: 'Service unavailable',
          message: 'Unable to connect to Spoonacular API',
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
 * Fetch recipe data from Spoonacular API
 */
async function fetchRecipeFromSpoonacular(recipeId: string): Promise<any> {
  const apiKey = spoonacularApiKey.value();
  const endpoints = [
    `${SPOONACULAR_BASE_URL}/${recipeId}/information?apiKey=${apiKey}&includeNutrition=true`,
  ];

  try {
    const response = await axios.get(endpoints[0]);
    return response.data;
  } catch (error) {
    console.error('Spoonacular API error:', error);
    throw error;
  }
}

/**
 * Save image credits to Firestore
 */
async function saveImageCredits(imageUrl: string, creditsText: string): Promise<void> {
  try {
    // Create a hash of the image URL to use as document ID
    const imageHash = crypto.createHash('md5').update(imageUrl).digest('hex');

    const creditDoc = await db.collection('image_credits').doc(imageHash).get();

    if (!creditDoc.exists) {
      await db.collection('image_credits').doc(imageHash).set({
        imageUrl,
        photographer: extractPhotographer(creditsText),
        source: 'Spoonacular',
        sourceUrl: imageUrl,
        attributionText: creditsText,
        cachedAt: admin.firestore.Timestamp.now(),
      });
      console.log(`Image credits saved for ${imageHash}`);
    }
  } catch (error) {
    console.error('Error saving image credits:', error);
    // Don't throw error - image credits are secondary data
  }
}

/**
 * Extract photographer name from credits text
 */
function extractPhotographer(creditsText: string): string {
  // Try to extract photographer from credits text
  // Format varies, so this is a basic implementation
  const patterns = [
    /Photo by (.+?)(?: on|,|$)/i,
    /Photographer: (.+?)(?:,|$)/i,
    /Credit: (.+?)(?:,|$)/i,
  ];

  for (const pattern of patterns) {
    const match = creditsText.match(pattern);
    if (match) {
      return match[1].trim();
    }
  }

  return 'Unknown';
}

/**
 * Log API usage for monitoring
 */
async function logApiUsage(
  endpoint: string,
  success: boolean,
  recipeId?: number,
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
    // Don't throw error - logging is secondary
  }
}

/**
 * Callable function to get multiple recipes at once
 * Useful for batch operations
 */
export const getRecipesBatch = functions.https.onCall(
  { secrets: [spoonacularApiKey] },
  async (data, context) => {
    const { recipeIds } = data;

    if (!Array.isArray(recipeIds) || recipeIds.length === 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'recipeIds must be a non-empty array'
      );
    }

    if (recipeIds.length > 10) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Maximum 10 recipes per batch request'
      );
    }

    const results = await Promise.all(
      recipeIds.map(async (recipeId) => {
        try {
          const recipeDoc = await db.collection('spoonacular_recipes').doc(String(recipeId)).get();

          if (recipeDoc.exists) {
            const recipeData = recipeDoc.data();
            const expiresAt = recipeData?.expiresAt?.toDate();

            if (expiresAt && expiresAt > new Date()) {
              return { recipeId, data: recipeData, cached: true };
            }
          }

          // Fetch from API if not in cache or expired
          const spoonacularData = await fetchRecipeFromSpoonacular(String(recipeId));

          const now = admin.firestore.Timestamp.now();
          const expiresAt = new Date();
          expiresAt.setDate(expiresAt.getDate() + CACHE_DURATION_DAYS);

          const recipeToSave = {
            ...spoonacularData,
            cachedAt: now,
            expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
            lastUpdated: now,
          };

          await db.collection('spoonacular_recipes').doc(String(recipeId)).set(recipeToSave);

          if (spoonacularData.image && spoonacularData.creditsText) {
            await saveImageCredits(spoonacularData.image, spoonacularData.creditsText);
          }

          await logApiUsage('getRecipesBatch', true, Number(recipeId));

          return { recipeId, data: recipeToSave, cached: false };

        } catch (error) {
          await logApiUsage('getRecipesBatch', false, Number(recipeId), error.message);
          return { recipeId, error: error.message };
        }
      })
    );

    return { results };
  }
);

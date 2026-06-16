import * as functions from 'firebase-functions';
import { getRecipe, getRecipesBatch } from './spoonacular';
import { suggestRecipe, suggestRecipeCallable } from './gemini';

// Export the Spoonacular functions
export { getRecipe, getRecipesBatch };

// Export the Gemini functions
export { suggestRecipe, suggestRecipeCallable };

// Optionally, you can add other functions here
// export const anotherFunction = functions.https.onRequest(...);

# Spoonacular API & Gemini AI Integration with Firebase Firestore

Questa integrazione permette di utilizzare le API di Spoonacular e Gemini AI per ottenere ricette intelligenti, con caching automatico su Firestore per minimizzare le chiamate API e restare nel piano gratuito.

## Architettura

### Pipeline Spoonacular (Ricette esistenti)
```
Frontend (Flutter App)
    ↓ (HTTP Request)
Firebase Cloud Function
    ↓ (Check Firestore)
Cache Hit? → Return cached data
    ↓ (Cache Miss)
Spoonacular API
    ↓ (Save to Firestore)
Firestore
    ↓ (Return data)
Frontend
```

### Pipeline Gemini (Suggerimenti ricette)
```
Frontend (Flutter App)
    ↓ (Ingredienti + Preferenze)
Firebase Cloud Function
    ↓ (Check Firestore Cache)
Cache Hit? → Return cached suggestion
    ↓ (Cache Miss)
Gemini AI (Suggerisce ricetta)
    ↓
Spoonacular API (Dettagli ricetta)
    ↓
Unsplash API (Immagine)
    ↓ (Save to Firestore)
Firestore
    ↓ (Return complete recipe)
Frontend
```

## Struttura Dati Firestore

### Collection: `spoonacular_recipes`
- **Document ID**: `spoonacular_recipe_id` (es: "716429")
- **Campi**:
  - `spoonacularId`: number
  - `title`: string
  - `image`: string (URL immagine)
  - `imageType`: string
  - `creditsText`: string
  - `sourceUrl`: string
  - `spoonacularSourceUrl`: string
  - `readyInMinutes`: number
  - `servings`: number
  - `pricePerServing`: number
  - `healthScore`: number
  - `extendedIngredients`: array (ingredienti dettagliati)
  - `analyzedInstructions`: array (istruzioni passo-passo)
  - `nutrition`: object (informazioni nutrizionali)
  - `diets`: array (diete compatibili)
  - `dishTypes`: array (tipi di piatto)
  - `cuisines`: array (cucine)
  - `cachedAt`: Timestamp (quando è stato salvato in cache)
  - `expiresAt`: Timestamp (quando scade la cache - 7 giorni)
  - `lastUpdated`: Timestamp (ultimo aggiornamento)

### Collection: `gemini_suggestions`
- **Document ID**: `cache_key` (hash degli ingredienti + preferenze)
- **Campi**:
  - Tutti i campi di `spoonacular_recipes`
  - `imageUrl`: string (URL immagine da Unsplash)
  - `geminiSuggestion`: object (suggerimento originale di Gemini)
    - `title`: string
    - `description`: string
    - `cuisine`: string
    - `difficulty`: string
    - `prepTime`: number
    - `servings`: number
  - `originalIngredients`: array (ingredienti originali dell'utente)
  - `originalPreferences`: string (preferenze originali dell'utente)
  - `cachedAt`: Timestamp
  - `expiresAt`: Timestamp (cache 7 giorni)
  - `lastUpdated`: Timestamp

### Collection: `image_credits`
- **Document ID**: `image_url_hash` (hash MD5 dell'URL per evitare duplicati)
- **Campi**:
  - `imageUrl`: string
  - `photographer`: string
  - `source`: string (es: "Unsplash", "Spoonacular")
  - `sourceUrl`: string
  - `attributionText`: string
  - `cachedAt`: Timestamp

### Collection: `api_usage_log`
- **Document ID**: auto-generated
- **Campi**:
  - `endpoint`: string (es: "getRecipe", "getRecipesBatch")
  - `timestamp`: Timestamp
  - `success`: boolean
  - `error`: string? (se c'è stato un errore)
  - `recipeId`: number? (ID della ricetta se applicabile)

## Setup

### 1. Installa le dipendenze

```bash
cd firebase/functions
npm install
```

### 2. Configura le API Keys usando Firebase Secrets (Nuovo sistema)

Il sistema `functions:config:set` è deprecato. Usa il nuovo sistema dei secrets:

```bash
# Imposta i secrets
firebase functions:secrets:set SPOONACULAR_API_KEY
firebase functions:secrets:set GEMINI_API_KEY
firebase functions:secrets:set UNSPLASH_ACCESS_KEY
```

Quando richiesto, inserisci i tuoi API Keys:
- **SPOONACULAR_API_KEY**: `cc977b4f20e841f3a4f11756f4fb8861` (la tua chiave)
- **GEMINI_API_KEY**: La tua chiave API di Gemini
- **UNSPLASH_ACCESS_KEY**: La tua chiave API di Unsplash (opzionale)

⚠️ **IMPORTANTE**: Non inserire mai le tue API Keys direttamente nel codice!

### 3. Inizializza Firebase (se non l'hai già fatto)

```bash
firebase login
firebase init functions
```

### 4. Deploy le Cloud Functions

```bash
firebase deploy --only functions
```

## Utilizzo

### HTTP Endpoint: `getRecipe` (Spoonacular)

**Endpoint**: `GET /getRecipe/{recipeId}`

**Esempio**:
```bash
curl https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/getRecipe/716429
```

**Risposta**:
```json
{
  "spoonacularId": 716429,
  "title": "Pasta with Garlic, Scallions, Cauliflower & Breadcrumbs",
  "image": "https://...",
  "readyInMinutes": 45,
  "servings": 4,
  "extendedIngredients": [...],
  "analyzedInstructions": [...],
  "nutrition": {...},
  "cachedAt": {...},
  "expiresAt": {...}
}
```

### HTTP Endpoint: `suggestRecipe` (Gemini)

**Endpoint**: `POST /suggestRecipe`

**Body**:
```json
{
  "ingredients": ["pomodoro", "mozzarella", "basilico"],
  "preferences": "cucina italiana, facile"
}
```

**Esempio**:
```bash
curl -X POST https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/suggestRecipe \
  -H "Content-Type: application/json" \
  -d '{"ingredients": ["pomodoro", "mozzarella", "basilico"], "preferences": "cucina italiana"}'
```

**Risposta**:
```json
{
  "spoonacularId": 716429,
  "title": "Caprese Salad",
  "imageUrl": "https://images.unsplash.com/...",
  "geminiSuggestion": {
    "title": "Caprese Salad",
    "description": "Insalata fresca con pomodoro, mozzarella e basilico",
    "cuisine": "Italiana",
    "difficulty": "Facile",
    "prepTime": 15,
    "servings": 2
  },
  "extendedIngredients": [...],
  "analyzedInstructions": [...],
  "nutrition": {...},
  "cachedAt": {...},
  "expiresAt": {...}
}
```

### Callable Function: `getRecipesBatch` (Spoonacular)

Per ottenere più ricette in una sola chiamata (massimo 10 per richiesta).

**Esempio (Flutter)**:
```dart
final result = await FirebaseFunctions.instance
    .httpsCallable('getRecipesBatch')
    .call({'recipeIds': [716429, 715538, 715515]});
```

### Callable Function: `suggestRecipeCallable` (Gemini)

Per ottenere suggerimenti di ricette da Gemini usando callable function (raccomandato per Flutter).

**Esempio (Flutter)**:
```dart
final result = await FirebaseFunctions.instance
    .httpsCallable('suggestRecipeCallable')
    .call({
      'ingredients': ['pomodoro', 'mozzarella', 'basilico'],
      'preferences': 'cucina italiana, facile'
    });

final data = result.data;
print(data['title']);
print(data['imageUrl']);
print(data['cached']); // true se dalla cache, false se nuova
```

## Gestione Errori

La Cloud Function gestisce i seguenti errori:

1. **Recipe ID non valido**: Restituisce 400 Bad Request
2. **Spoonacular API error**: Restituisce lo status code dell'API Spoonacular
3. **Gemini API error**: Restituisce 500 se Gemini fallisce
4. **Service unavailable**: Restituisce 503 se non riesce a connettersi alle API
5. **Internal server error**: Restituisce 500 per altri errori

Tutti gli errori vengono loggati nella collection `api_usage_log`.

## Caching

### Spoonacular Recipes
- **Durata cache**: 7 giorni
- **Verifica**: La funzione controlla se la ricetta esiste in Firestore e se la cache non è scaduta
- **Refresh**: Se la cache è scaduta, i dati vengono rinfrescati da Spoonacular

### Gemini Suggestions
- **Durata cache**: 7 giorni
- **Cache key**: Hash degli ingredienti + preferenze (stessi ingredienti = stessa cache)
- **Pipeline completa**: Gemini → Spoonacular → Unsplash → Firestore
- **Refresh**: Se la cache è scaduta, viene eseguita nuovamente l'intera pipeline

## Monitoraggio

Puoi monitorare l'utilizzo dell'API controllando la collection `api_usage_log` su Firestore:

```javascript
// Esempio query per vedere le chiamate API fallite
db.collection('api_usage_log')
  .where('success', '==', false)
  .orderBy('timestamp', 'desc')
  .limit(10)
  .get();
```

## Costi

### API Costs
- **Spoonacular API**: Piano gratuito (150 richieste/giorno)
- **Gemini API**: Piano gratuito (15 richieste/minuto, 1,500 richieste/giorno)
- **Unsplash API**: Piano gratuito (50 richieste/ora, 500 richieste/mese per Search API)

### Firebase Costs
- **Firestore**: Costi basati su letture/scritture
- **Cloud Functions**: Costi basati su invocazioni

### Ottimizzazione Costi
Con il caching di 7 giorni:
- **Spoonacular**: Riduci drasticamente le chiamate API mantenendo i dati aggiornati
- **Gemini**: Stessi ingredienti = stessa cache = zero chiamate API
- **Unsplash**: Le immagini vengono cachate per evitare chiamate ripetute

## Best Practices

1. **Non chiamare l'API direttamente dal frontend**: Usa sempre le Cloud Functions
2. **Usa il batch endpoint** quando hai bisogno di più ricette
3. **Monitora i log** per identificare problemi rapidamente
4. **Aggiorna la cache** periodicamente (7 giorni è un buon compromesso)
5. **Attribuisci le immagini** usando i dati dalla collection `image_credits`
6. **Usa callable functions** per Flutter (migliore gestione errori e autenticazione)
7. **Gemini per suggerimenti, Spoonacular per dettagli**: Usa Gemini per idee creative, Spoonacular per dati strutturati

## Troubleshooting

### Errori comuni

**"Invalid recipe ID"**
- Verifica che l'ID sia un numero valido

**"Spoonacular API error"**
- Verifica che la tua API Key sia corretta
- Controlla di non aver superato il limite del piano gratuito

**"Gemini API error"**
- Verifica che la tua API Key sia corretta
- Controlla di non aver superato il limite del piano gratuito

**"Service unavailable"**
- Verifica la tua connessione internet
- Controlla che le API siano online

**"ingredients must be a non-empty array"**
- Verifica di aver inviato un array di ingredienti valido

## Supporto

Per problemi o domande:
- Documentazione Spoonacular: https://spoonacular.com/food-api
- Documentazione Firebase Functions: https://firebase.google.com/docs/functions

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../models.dart';
import 'api_cache_service.dart';

class GeminiService {
  // Modello principale (Pro) e fallback (Flash)
  final _proModel = GenerativeModel(
    model: 'gemini-3.5-pro',
    apiKey: ApiConfig.geminiApiKey,
  );
  
  final _flashModel = GenerativeModel(
    model: 'gemini-3.5-flash',
    apiKey: ApiConfig.geminiApiKey,
  );

  final ApiCacheService _cacheService = ApiCacheService();

  // Cache per evitare chiamate duplicate
  final Map<String, String> _priceCache = {};
  final Map<String, String> _imageCache = {};

  // Funzione unica per gestire i prompt con caching e retry con exponential backoff e fallback
  Future<String> chiediAGemini(String prompt) async {
    // Genera una chiave di cache basata sul prompt
    final cacheKey = 'gemini_${prompt.hashCode}';

    // Controlla la cache prima di chiamare l'API
    final cachedResponse = await _cacheService.getResultFromCache(cacheKey);
    if (cachedResponse != null) {
      debugPrint("RISPOSTA DA CACHE GEMINI");
      return cachedResponse;
    }

    // Retry logic con exponential backoff e fallback
    int maxRetries = 5;
    int retryCount = 0;
    bool useProModel = true;

    while (retryCount < maxRetries) {
      try {
        final model = useProModel ? _proModel : _flashModel;
        final response = await model.generateContent(
            [Content.text(prompt)]).timeout(const Duration(seconds: 30));
        final responseText = response.text ?? "Nessuna risposta ricevuta.";
        debugPrint("RISPOSTA RICEVUTA DA GEMINI (${useProModel ? 'Pro' : 'Flash'}): $responseText");

        // Salva la risposta nella cache
        await _cacheService.saveResultToCache(cacheKey, responseText);

        return responseText;
      } catch (e) {
        retryCount++;
        debugPrint("ERRORE GEMINI (tentativo $retryCount/$maxRetries, modello: ${useProModel ? 'Pro' : 'Flash'}): $e");

        // Analizza il tipo di errore
        final errorStr = e.toString().toLowerCase();
        final is429 = errorStr.contains("429") || errorStr.contains("quota exceeded") || errorStr.contains("too many requests");
        final is503 = errorStr.contains("503") || errorStr.contains("service unavailable") || errorStr.contains("overloaded");

        if (retryCount >= maxRetries) {
          if (is429) {
            return "Limite di richieste superato. Riprova tra qualche minuto.";
          } else if (is503) {
            return "Servizio temporaneamente sovraccarico. Riprova tra qualche minuto.";
          }
          return "Errore di connessione: $e";
        }

        // Se è un errore 503 e stiamo usando il modello Pro, passa a Flash
        if (is503 && useProModel) {
          debugPrint("Errore 503 con modello Pro, passando a Flash model");
          useProModel = false;
          retryCount = 0; // Reset retry count per il nuovo modello
          continue;
        }

        // Se è un errore 429, non ha senso riprovare con un modello diverso
        if (is429) {
          // Exponential backoff più aggressivo per quota exceeded
          final backoffDelay = Duration(seconds: (1 << (retryCount - 1)) * 2);
          debugPrint("Attendo $backoffDelay prima di riprovare (quota exceeded)");
          await Future.delayed(backoffDelay);
          continue;
        }

        // Exponential backoff standard per altri errori: 1s, 2s, 4s, 8s, 16s
        final backoffDelay = Duration(seconds: 1 << (retryCount - 1));
        debugPrint("Attendo $backoffDelay prima di riprovare");
        await Future.delayed(backoffDelay);
      }
    }

    return "Errore: impossibile ottenere risposta dopo $maxRetries tentativi.";
  }

  // Comando 1: Ricetta dalla dispensa (versione JSON strutturata con approccio misto)
  Future<Map<String, dynamic>> generaRicettaDallaDispensaJSON(
      List<String> ingredienti, {
      int? eta,
      int? obiettivoCalorico,
      String? tipoDieta,
      List<String>? allergie,
      List<Map<String, dynamic>>? ricetteLocali,
      }) async {
    String preferencesContext = '';
    if (eta != null || obiettivoCalorico != null || tipoDieta != null || (allergie != null && allergie.isNotEmpty)) {
      preferencesContext = '\n\nCONTESTO UTENTE:\n';
      if (eta != null) {
        preferencesContext += '- Età: $eta anni\n';
      }
      if (obiettivoCalorico != null) {
        preferencesContext += '- Obiettivo calorico giornaliero: $obiettivoCalorico kcal\n';
      }
      if (tipoDieta != null) {
        preferencesContext += '- Tipo di dieta: $tipoDieta\n';
      }
      if (allergie != null && allergie.isNotEmpty) {
        preferencesContext += '- Allergie/intolleranze: ${allergie.join(', ')}\n';
      }
      preferencesContext += '\nAdatta la ricetta a queste preferenze, evitando ingredienti allergenici e rispettando le restrizioni dietetiche.';
    }
    
    String ricetteContext = '';
    if (ricetteLocali != null && ricetteLocali.isNotEmpty) {
      ricetteContext = '\n\nRICETTARIO LOCALE:\n';
      for (final ricetta in ricetteLocali) {
        ricetteContext += '- ${ricetta['nome']}: ${ricetta['ingredienti']}\n';
      }
    }
    
    final prompt = """
    Agisci come un esperto assistente culinario personale per l'app 'PlanEats'. Il tuo obiettivo è generare un suggerimento di pasto basato sugli ingredienti forniti dall'utente e sul ricettario esistente.

    Segui rigorosamente questo processo logico:

    Analisi del Ricettario Locale: Analizza la lista di ricette fornite nel contesto $ricetteContext. Verifica se è possibile preparare un pasto completo utilizzando esclusivamente queste ricette e gli ingredienti disponibili: ${ingredienti.join(', ')}.

    Generazione creativa (Fallback): Se non esistono ricette nel DB che soddisfano i criteri, o se le ricette esistenti non sono sufficienti, crea una nuova ricetta originale che sia coerente con gli ingredienti disponibili.$preferencesContext

    Modalità di risposta: Indica chiaramente nella risposta se la ricetta suggerita proviene dal 'Ricettario' (già esistente) o se è stata 'Generata' (nuova).

    Format di Output Obbligatorio:
    Devi rispondere ESCLUSIVAMENTE in formato JSON valido, senza testo di introduzione o conclusione, rispettando la seguente struttura:

    {
      "tipo": "Ricettario" OR "Generata",
      "titolo": "[nome della ricetta]",
      "categoria": "Antipasti/Primi Piatti/Secondi/Contorni/Dolci/Altre Ricette",
      "sottocategoria": "[sottocategoria specifica, es: Pasta, Carne, Torte, ecc.]",
      "calorie": [calorie totali della ricetta per porzione],
      "tempo_preparazione": [tempo di preparazione in minuti],
      "difficolta": "facile/media/difficile",
      "ingredienti": [
        {"nome": "[ingrediente]", "quantita": "[quantità per 1 persona]", "unita": "[unità]", "categoria": "[reparto: ortofrutta/carne/pesce/latticini/panetteria/surgelati/dispensa/bevande]"}
      ],
      "istruzioni": ["[passaggio 1]", "[passaggio 2]", "[passaggio 3]"],
      "motivazione": "Breve spiegazione sul perché hai scelto questa ricetta basata sul ricettario o sugli ingredienti forniti.",
      "prompt_immagine": "descrizione dettagliata e appetitosa del piatto finito per un generatore di immagini, includendo stile fotografico, illuminazione, composizione e dettagli visivi"
    }
    
    IMPORTANTE per le calorie:
    - Calcola le calorie per 1 persona (1 porzione)
    - Usa valori realistici basati sugli ingredienti e sulle quantità
    - Valori di riferimento: carboidrati ~4 kcal/g, proteine ~4 kcal/g, grassi ~9 kcal/g
    - Esempio: 100g pasta = 350 kcal, 100g pollo = 165 kcal, 1 cucchiaio olio = 120 kcal
    
    IMPORTANTE per il tempo di preparazione:
    - Stima il tempo di preparazione in minuti
    - Considera taglio, cottura, preparazione ingredienti
    - Valori tipici: antipasti 10-20 min, primi 20-40 min, secondi 25-45 min, contorni 15-30 min, dolci 30-60 min
    
    IMPORTANTE per la difficoltà:
    - Valuta la difficoltà in base al numero di passaggi, complessità delle tecniche, tempo richiesto
    - "facile": ricette semplici con ingredienti comuni e passaggi facili
    - "media": ricette con alcune tecniche culinarie o ingredienti specifici
    - "difficile": ricette complesse con tecniche avanzate o molti passaggi
    
    Regole di sicurezza:
    - Non includere markdown di formattazione (come \`\`\`json) se non richiesto.
    - Se mancano ingredienti essenziali, suggerisci una sostituzione logica.
    - Se l'input dell'utente non è pertinente alla cucina, rispondi con un messaggio di errore in formato JSON: {"errore": "Input non valido"}
    """;

    final response = await chiediAGemini(prompt);
    return _parseRecipeJSON(response);
  }

  // Comando 1: Ricetta dalla dispensa (versione legacy per compatibilità)
  Future<String> generaRicettaDallaDispensa(List<String> ingredienti) async {
    final prompt = """
    Sei un esperto chef. Crea una ricetta semplice e gustosa usando solo questi ingredienti: ${ingredienti.join(', ')}.
    
    Rispondi in questo formato esatto:
    
    TITOLO: [nome della ricetta]
    
    INGREDIENTI (per 1 persona):
    - [quantità] [unità] [ingrediente] - [reparto supermercato: ortofrutta/carne/pesce/latticini/panetteria/surgelati/dispensa/bevande]
    
    Esempi:
    - 200g pomodori - ortofrutta
    - 100g pasta - dispensa
    - 2 uova - latticini
    - 150g pollo - carne
    
    PROCEDIMENTO:
    [passaggi per preparare la ricetta]
    """;
    return await chiediAGemini(prompt);
  }

  // Parsa la risposta JSON di Gemini
  Map<String, dynamic> _parseRecipeJSON(String response) {
    try {
      // Pulisci la risposta rimuovendo eventuali markdown code blocks
      String cleanedResponse = response.trim();
      if (cleanedResponse.startsWith('```json')) {
        cleanedResponse = cleanedResponse.substring(7);
      }
      if (cleanedResponse.startsWith('```')) {
        cleanedResponse = cleanedResponse.substring(3);
      }
      if (cleanedResponse.endsWith('```')) {
        cleanedResponse =
            cleanedResponse.substring(0, cleanedResponse.length - 3);
      }
      cleanedResponse = cleanedResponse.trim();

      // Check for server error responses before attempting JSON decode
      if (cleanedResponse.contains('503') || 
          cleanedResponse.contains('Server Error') ||
          cleanedResponse.contains('Service Unavailable')) {
        debugPrint('ERRORE SERVER: Servizio AI momentaneamente non disponibile (503)');
        return {'errore': 'Servizio AI momentaneamente non disponibile. Riprova tra poco.'};
      }

      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(cleanedResponse) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('ERRORE FORMATO JSON: $e');
        debugPrint('RISPOSTA: $cleanedResponse');
        return {'errore': 'Formato risposta non valido. Riprova.'};
      }

      // Controlla se c'è un errore
      if (jsonData.containsKey('errore')) {
        debugPrint('ERRORE GEMINI: ${jsonData['errore']}');
        return {'errore': jsonData['errore']};
      }

      // Validazione e normalizzazione della categoria
      final categoria = jsonData['categoria'] as String?;
      final sottocategoria = jsonData['sottocategoria'] as String?;

      // Verifica che la categoria sia valida
      final categoriaValida =
          CategoriaRicetta.categorie.any((c) => c.nome == categoria);
      if (!categoriaValida && categoria != null) {
        // Se la categoria non è valida, prova a mapparla
        jsonData['categoria'] = _mappaCategoria(categoria);
      }

      // Verifica che la sottocategoria sia valida per la categoria
      if (categoria != null && sottocategoria != null) {
        final sottocategorieValide =
            CategoriaRicetta.getSottocategorie(categoria);
        if (!sottocategorieValide.contains(sottocategoria)) {
          // Se la sottocategoria non è valida, lasciala ma logga un warning
          debugPrint(
              'WARNING: Sottocategoria "$sottocategoria" non valida per categoria "$categoria"');
        }
      }

      return jsonData;
    } catch (e) {
      debugPrint('ERRORE PARSING JSON: $e');
      debugPrint('RISPOSTA: $response');
      // Ritorna un oggetto vuoto in caso di errore
      return {};
    }
  }

  // Mappa una categoria stringa a una categoria valida
  String _mappaCategoria(String categoria) {
    final categoriaLower = categoria.toLowerCase();

    if (categoriaLower.contains('antipasto') ||
        categoriaLower.contains('antipasti')) {
      return 'Antipasti';
    } else if (categoriaLower.contains('primo') ||
        categoriaLower.contains('pasta') ||
        categoriaLower.contains('riso')) {
      return 'Primi Piatti';
    } else if (categoriaLower.contains('secondo') ||
        categoriaLower.contains('carne') ||
        categoriaLower.contains('pesce')) {
      return 'Secondi';
    } else if (categoriaLower.contains('contorno') ||
        categoriaLower.contains('verdura') ||
        categoriaLower.contains('insalata')) {
      return 'Contorni';
    } else if (categoriaLower.contains('dolce') ||
        categoriaLower.contains('dessert') ||
        categoriaLower.contains('torta')) {
      return 'Dolci';
    }

    return 'Altre Ricette';
  }

  // Estrae il titolo dalla risposta di Gemini
  String? estraiTitoloDaRisposta(String risposta) {
    final lines = risposta.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('TITOLO:')) {
        return trimmed.replaceFirst('TITOLO:', '').trim();
      }
    }
    return null;
  }

  // Estrae gli ingredienti dalla risposta di Gemini con quantità, unità e categoria
  List<Map<String, dynamic>> estraiIngredientiDaRisposta(String risposta) {
    final ingredienti = <Map<String, dynamic>>[];
    final lines = risposta.split('\n');
    bool inIngredienti = false;

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.startsWith('INGREDIENTI')) {
        inIngredienti = true;
        continue;
      }

      if (trimmed.startsWith('PROCEDIMENTO:')) {
        break;
      }

      if (inIngredienti && trimmed.startsWith('-')) {
        final ingredienteStr = trimmed.replaceFirst('-', '').trim();
        if (ingredienteStr.isNotEmpty) {
          // Parsa il formato: [quantità] [unità] [ingrediente] - [categoria]
          final parts = ingredienteStr.split(' - ');
          if (parts.length >= 2) {
            final ingredientePart = parts[0].trim();
            final categoriaPart = parts[1].trim().toLowerCase();

            // Estrai quantità, unità e nome
            final ingParts = ingredientePart.split(' ');
            String quantitaStr = '';
            String unita = '';
            String nome = '';

            // Cerca di estrarre quantità e unità
            int i = 0;
            while (i < ingParts.length) {
              final part = ingParts[i];
              // Se è un numero (quantità)
              if (RegExp(r'^\d+(\.\d+)?$').hasMatch(part)) {
                quantitaStr = part;
                i++;
                // Prossima parte potrebbe essere l'unità
                if (i < ingParts.length) {
                  final nextPart = ingParts[i];
                  // Se non è un numero, probabilmente è l'unità
                  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(nextPart)) {
                    unita = nextPart;
                    i++;
                  }
                }
                break;
              }
              i++;
            }

            // Il resto è il nome
            nome = ingParts.sublist(i).join(' ');

            // Mappa la categoria del supermercato a IngredientCategory
            IngredientCategory categoria = IngredientCategory.altro;
            if (categoriaPart.contains('ortofrutta') ||
                categoriaPart.contains('verdura') ||
                categoriaPart.contains('frutta')) {
              categoria = IngredientCategory.ortofrutta;
            } else if (categoriaPart.contains('carne')) {
              categoria = IngredientCategory.carne;
            } else if (categoriaPart.contains('pesce')) {
              categoria = IngredientCategory.pesce;
            } else if (categoriaPart.contains('latticini') ||
                categoriaPart.contains('formaggio') ||
                categoriaPart.contains('latte')) {
              categoria = IngredientCategory.latticini;
            } else if (categoriaPart.contains('panetteria') ||
                categoriaPart.contains('pane')) {
              categoria = IngredientCategory.panetteria;
            } else if (categoriaPart.contains('surgelati') ||
                categoriaPart.contains('congelato')) {
              categoria = IngredientCategory.surgelati;
            } else if (categoriaPart.contains('dispensa') ||
                categoriaPart.contains('pasta') ||
                categoriaPart.contains('riso')) {
              categoria = IngredientCategory.dispensa;
            } else if (categoriaPart.contains('bevande') ||
                categoriaPart.contains('acqua') ||
                categoriaPart.contains('vino')) {
              categoria = IngredientCategory.bevande;
            }

            ingredienti.add({
              'nome': nome,
              'quantita':
                  quantitaStr.isNotEmpty ? double.tryParse(quantitaStr) : null,
              'unita': unita.isNotEmpty ? unita : null,
              'categoria': categoria,
            });
          }
        }
      }
    }

    return ingredienti;
  }

  // Estrae il procedimento dalla risposta di Gemini
  String? estraiProcedimentoDaRisposta(String risposta) {
    final lines = risposta.split('\n');
    final procedimentoLines = <String>[];
    bool inProcedimento = false;

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.startsWith('PROCEDIMENTO:')) {
        inProcedimento = true;
        continue;
      }

      if (inProcedimento) {
        procedimentoLines.add(line);
      }
    }

    if (procedimentoLines.isEmpty) return null;
    return procedimentoLines.join('\n').trim();
  }

  // Genera ricetta e restituisce i dati strutturati per il salvataggio (versione JSON con sottocategorie)
  Future<Map<String, dynamic>> generaRicettaStrutturata(
      List<String> ingredienti, {
      int? eta,
      int? obiettivoCalorico,
      String? tipoDieta,
      List<String>? allergie,
      List<Map<String, dynamic>>? ricetteLocali,
      }) async {
    String preferencesContext = '';
    if (eta != null || obiettivoCalorico != null || tipoDieta != null || (allergie != null && allergie.isNotEmpty)) {
      preferencesContext = '\n\nCONTESTO UTENTE:\n';
      if (eta != null) {
        preferencesContext += '- Età: $eta anni\n';
      }
      if (obiettivoCalorico != null) {
        preferencesContext += '- Obiettivo calorico giornaliero: $obiettivoCalorico kcal\n';
      }
      if (tipoDieta != null) {
        preferencesContext += '- Tipo di dieta: $tipoDieta\n';
      }
      if (allergie != null && allergie.isNotEmpty) {
        preferencesContext += '- Allergie/intolleranze: ${allergie.join(', ')}\n';
      }
      preferencesContext += '\nAdatta la ricetta a queste preferenze, evitando ingredienti allergenici e rispettando le restrizioni dietetiche.';
    }
    
    String ricetteContext = '';
    if (ricetteLocali != null && ricetteLocali.isNotEmpty) {
      ricetteContext = '\n\nRICETTARIO LOCALE:\n';
      for (final ricetta in ricetteLocali) {
        ricetteContext += '- ${ricetta['nome']}: ${ricetta['ingredienti']}\n';
      }
    }
    
    final prompt = """
    Agisci come un esperto assistente culinario personale per l'app 'PlanEats'. Il tuo obiettivo è generare un suggerimento di pasto basato sugli ingredienti forniti dall'utente e sul ricettario esistente.

    Segui rigorosamente questo processo logico:

    Analisi del Ricettario Locale: Analizza la lista di ricette fornite nel contesto $ricetteContext. Verifica se è possibile preparare un pasto completo utilizzando esclusivamente queste ricette e gli ingredienti disponibili: ${ingredienti.join(', ')}.

    Generazione creativa (Fallback): Se non esistono ricette nel DB che soddisfano i criteri, o se le ricette esistenti non sono sufficienti, crea una nuova ricetta originale che sia coerente con gli ingredienti disponibili.$preferencesContext

    Modalità di risposta: Indica chiaramente nella risposta se la ricetta suggerita proviene dal 'Ricettario' (già esistente) o se è stata 'Generata' (nuova).

    Format di Output Obbligatorio:
    Devi rispondere ESCLUSIVAMENTE in formato JSON valido, senza testo di introduzione o conclusione, rispettando la seguente struttura:

    {
      "tipo": "Ricettario" OR "Generata",
      "titolo": "Nome della ricetta",
      "categoria": "Antipasti/Primi Piatti/Secondi/Contorni/Dolci/Altre Ricette",
      "sottocategoria": "[sottocategoria specifica valida per la categoria scelta]",
      "calorie": [calorie totali della ricetta per porzione],
      "tempo_preparazione": [tempo di preparazione in minuti],
      "difficolta": "facile/media/difficile",
      "procedimento": "Procedimento dettagliato",
      "ingredienti": [
        {"nome": "nome ingrediente", "quantita": "1", "unita": "gr", "categoria": "ortofrutta/carne/pesce/latticini/panetteria/surgelati/dispensa/bevande"}
      ],
      "motivazione": "Breve spiegazione sul perché hai scelto questa ricetta basata sul ricettario o sugli ingredienti forniti.",
      "prompt_immagine": "Professional food photography of [NOME_PIATTO], high resolution, top-down view or 45-degree angle, natural daylight, describe texture (creamy/glistening/crispy), describe colors (vibrant/golden/brown), include garnish details (fresh herbs/parmesan/sauce), rustic wooden table background, soft focus background, warm ambiance, 8k resolution, avoid artificial or plastic look"
    }
    
    IMPORTANTE per le calorie:
    - Calcola le calorie per 1 persona (1 porzione)
    - Usa valori realistici basati sugli ingredienti e sulle quantità
    - Valori di riferimento: carboidrati ~4 kcal/g, proteine ~4 kcal/g, grassi ~9 kcal/g
    - Esempio: 100g pasta = 350 kcal, 100g pollo = 165 kcal, 1 cucchiaio olio = 120 kcal
    
    IMPORTANTE per il tempo di preparazione:
    - Stima il tempo di preparazione in minuti
    - Considera taglio, cottura, preparazione ingredienti
    - Valori tipici: antipasti 10-20 min, primi 20-40 min, secondi 25-45 min, contorni 15-30 min, dolci 30-60 min
    
    IMPORTANTE per la difficoltà:
    - Valuta la difficoltà in base al numero di passaggi, complessità delle tecniche, tempo richiesto
    - "facile": ricette semplici con ingredienti comuni e passaggi facili
    - "media": ricette con alcune tecniche culinarie o ingredienti specifici
    - "difficile": ricette complesse con tecniche avanzate o molti passaggi
    
    Regole di sicurezza:
    - Non includere markdown di formattazione (come \`\`\`json) se non richiesto.
    - Se mancano ingredienti essenziali, suggerisci una sostituzione logica.
    - Se l'input dell'utente non è pertinente alla cucina, rispondi con un messaggio di errore in formato JSON: {"errore": "Input non valido"}
    
    IMPORTANTE per categoria e sottocategoria:
    - Usa ESATTAMENTE una di queste categorie: "Antipasti", "Primi Piatti", "Secondi", "Contorni", "Dolci", "Altre Ricette"
    - Per "Antipasti" usa una di queste sottocategorie: "Crudité", "Fritti", "Stuzzichini", "Bruschette", "Tartine"
    - Per "Primi Piatti" usa una di queste sottocategorie: "Pasta", "Riso", "Zuppe", "Gnocchi", "Crespelle"
    - Per "Secondi" usa una di queste sottocategorie: "Carne", "Pesce", "Uova", "Legumi", "Formaggi"
    - Per "Contorni" usa una di queste sottocategorie: "Verdure", "Insalate", "Patate", "Legumi"
    - Per "Dolci" usa una di queste sottocategorie: "Torte", "Biscotti", "Gelati", "Mousse", "Frutta"
    - Per "Altre Ricette" usa una di queste sottocategorie: "Salse", "Conservazioni", "Bevande", "Altro"
    
    IMPORTANTE per la categoria degli ingredienti (reparto supermercato):
    - Usa ESATTAMENTE una di queste categorie per ogni ingrediente: "ortofrutta", "carne", "pesce", "latticini", "panetteria", "surgelati", "dispensa", "bevande"
    - "ortofrutta": per verdure, frutta, erbe aromatiche
    - "carne": per carne bovina, suina, pollo, coniglio
    - "pesce": per pesce, molluschi, crostacei
    - "latticini": per latte, formaggi, yogurt, burro, uova
    - "panetteria": per pane, farina, lievito
    - "surgelati": per alimenti congelati
    - "dispensa": per pasta, riso, legumi secchi, olio, spezie, condimenti
    - "bevande": per acqua, vino, succhi, bibite
    
    IMPORTANTE per il campo prompt_immagine:
    - Usa sempre termini professionali: 'Professional food photography', 'High resolution', 'Top-down view' o '45-degree angle', 'Natural daylight'
    - Descrivi dettagli sensoriali: consistenza (creamy texture, glistening sauce), colore (fresh vibrant herbs, golden brown)
    - Aggiungi contesto accogliente: 'Rustic wooden table background', 'Soft focus background', 'Warm ambiance'
    - Evita l'effetto artificiale: punta al realismo e all'appetibilità, non a renderizzazioni plasticose
    - Esempio: 'Professional food photography of a steaming pasta carbonara, creamy egg sauce glistening, crispy guanciale bits, fresh cracked black pepper, rustic ceramic plate, natural morning light, wood table, 8k resolution'
    """;

    final response = await _proModel.generateContent([Content.text(prompt)]);
    final cleanedResponse =
        response.text!.replaceAll('```json', '').replaceAll('```', '').trim();

    // Check for server error responses before attempting JSON decode
    if (cleanedResponse.contains('503') || 
        cleanedResponse.contains('Server Error') ||
        cleanedResponse.contains('Service Unavailable')) {
      debugPrint('ERRORE SERVER: Servizio AI momentaneamente non disponibile (503)');
      throw Exception('Servizio AI momentaneamente non disponibile. Riprova tra poco.');
    }

    Map<String, dynamic> jsonData;
    try {
      jsonData = jsonDecode(cleanedResponse) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('ERRORE FORMATO JSON: $e');
      debugPrint('RISPOSTA: $cleanedResponse');
      throw Exception('Formato risposta non valido. Riprova.');
    }

    // Validazione e normalizzazione della categoria
    final categoria = jsonData['categoria'] as String?;
    final sottocategoria = jsonData['sottocategoria'] as String?;

    // Verifica che la categoria sia valida
    final categoriaValida =
        CategoriaRicetta.categorie.any((c) => c.nome == categoria);
    if (!categoriaValida && categoria != null) {
      // Se la categoria non è valida, prova a mapparla
      jsonData['categoria'] = _mappaCategoria(categoria);
    }

    // Verifica che la sottocategoria sia valida per la categoria
    if (categoria != null && sottocategoria != null) {
      final sottocategorieValide =
          CategoriaRicetta.getSottocategorie(categoria);
      if (!sottocategorieValide.contains(sottocategoria)) {
        // Se la sottocategoria non è valida, lasciala ma logga un warning
        debugPrint(
            'WARNING: Sottocategoria "$sottocategoria" non valida per categoria "$categoria"');
      }
    }

    return jsonData;
  }

  // Comando 2: Prezzo medio spesa
  Future<String> stimaPrezzoSpesa(List<String> listaSpesa, {String? regione}) async {
    // Crea una chiave unica per la cache basata sulla lista ordinata e regione
    final cacheKey = listaSpesa..sort();
    final key = '${cacheKey.join(',')}_${regione ?? 'default'}';

    // Controlla se il risultato è già in cache
    if (_priceCache.containsKey(key)) {
      debugPrint('RISULTATO PRESO DALLA CACHE: ${_priceCache[key]}');
      return _priceCache[key]!;
    }

    String regioneContext = '';
    if (regione != null) {
      regioneContext = '\n\nCONTESTO REGIONALE:\n';
      regioneContext += '- Regione: $regione\n';
      regioneContext += '- Calcola i prezzi medi per questa specifica regione italiana, considerando le variazioni regionali dei prezzi.\n';
      regioneContext += '- Le regioni del Nord (Lombardia, Veneto, Piemonte, ecc.) tendono ad avere prezzi leggermente più alti.\n';
      regioneContext += '- Le regioni del Sud (Sicilia, Calabria, Puglia, ecc.) tendono ad avere prezzi leggermente più bassi.\n';
    }
    
    final prompt = """
    Analizza questa lista della spesa con quantità e unità: ${listaSpesa.join(', ')}.$regioneContext
    
    IMPORTANTE: Calcola i prezzi correttamente considerando le unità di misura:
    - Se l'unità è 'g' (grammi), dividi per 1000 per ottenere kg (es: 200g = 0.2kg)
    - Se l'unità è 'kg', usa direttamente il valore
    - Se l'unità è 'ml', dividi per 1000 per ottenere litri (es: 500ml = 0.5l)
    - Se l'unità è 'l', usa direttamente il valore
    - Se l'unità è 'pezzi' o numero senza unità, calcola per pezzo
    
    Usa prezzi medi realistici per il mercato italiano (in euro):
    - Farina: ~1.2€/kg
    - Pasta: ~1.8€/kg
    - Riso: ~2.8€/kg
    - Pomodori: ~2.8€/kg
    - Carne (pollo): ~9.5€/kg
    - Carne (manzo): ~18€/kg
    - Pesce: ~15-25€/kg
    - Uova: ~0.35€/pezzo
    - Latte: ~1.6€/l
    - Pane: ~4€/kg
    
    Rispondi SOLTANTO con il prezzo totale stimato in euro (es: '12.50').
    NON scrivere frasi, NON aggiungere spiegazioni, NON usare valuta o simboli.
    Output richiesto: solo il numero.
    """;

    final result = await chiediAGemini(prompt);

    // Salva il risultato in cache
    _priceCache[key] = result;
    debugPrint('RISULTATO SALVATO IN CACHE: $result');

    return result;
  }

  // Comando 3: Ricetta da URL
  Future<String> estraiRicettaDaUrl(String url) async {
    final prompt = """
    Analizza il contenuto di questo sito: $url. Estrai solo la ricetta (titolo, ingredienti) e pulisci il testo da pubblicità o chiacchiere.
    
    NON estrarre il procedimento. Dividi gli ingredienti per 1 persona.
    
    Rispondi in questo formato esatto:
    
    TITOLO: [nome della ricetta]
    
    INGREDIENTI (per 1 persona):
    - [quantità] [unità] [ingrediente] - [reparto supermercato: ortofrutta/carne/pesce/latticini/panetteria/surgelati/dispensa/bevande]
    
    Esempi:
    - 200g pomodori - ortofrutta
    - 100g pasta - dispensa
    - 2 uova - latticini
    - 150g pollo - carne
    
    NON includere il procedimento.
    """;
    return await chiediAGemini(prompt);
  }

  // Genera ingredienti, dosi e procedimento basandosi sul titolo della ricetta
  Future<Map<String, dynamic>> generaDettagliRicettaDaTitolo(
      String titolo) async {
    final prompt = """
    Sei un assistente culinario esperto. Genera i dettagli completi per questa ricetta: "$titolo".
    
    Rispondi ESCLUSIVAMENTE in formato JSON con questa struttura esatta:
    {
      "ingredienti": [
        {"nome": "[ingrediente]", "quantita": "[quantità per 1 persona]", "unita": "[unità]"}
      ],
      "procedimento": ["[passaggio 1]", "[passaggio 2]", "[passaggio 3]"],
      "prompt_immagine": "descrizione dettagliata e appetitosa del piatto finito per un generatore di immagini"
    }
    
    NON aggiungere testo al di fuori del JSON. Assicurati che il JSON sia valido e ben formattato.
    Genera ingredienti realistici con dosi calcolate per 1 persona.
    """;

    final response = await chiediAGemini(prompt);

    try {
      final jsonData = json.decode(response);
      return jsonData as Map<String, dynamic>;
    } catch (e) {
      debugPrint("Errore nel parsing della risposta JSON: $e");
      return {
        'ingredienti': [],
        'procedimento': ['Procedimento non disponibile'],
        'prompt_immagine': titolo
      };
    }
  }

  // Genera un'immagine pertinente basandosi sul titolo della ricetta
  Future<String?> generaImmagineDaTitolo(String titolo) async {
    // Genera un prompt per l'immagine basandosi sul titolo
    final promptImmagine =
        "Delicious $titolo dish, professional food photography, appetizing presentation";
    return await generaImmagineDaPrompt(promptImmagine);
  }

  // Genera un'immagine usando il prompt_immagine dal JSON
  Future<String?> generaImmagineDaPrompt(String promptImmagine) async {
    // Controlla cache
    final cacheKey = promptImmagine.hashCode.toString();
    if (_imageCache.containsKey(cacheKey)) {
      debugPrint('IMMAGINE PRESA DALLA CACHE: ${_imageCache[cacheKey]}');
      return _imageCache[cacheKey];
    }

    try {
      // Prima prova con Unsplash Search API
      final imageUrl = await fetchFoodImage(promptImmagine);
      if (imageUrl != null) {
        _imageCache[cacheKey] = imageUrl;
        debugPrint('IMMAGINE GENERATA (Unsplash API): $imageUrl');
        return imageUrl;
      }

      // Fallback a Unsplash Source API
      final encodedPrompt = Uri.encodeComponent(promptImmagine);
      final fallbackImageUrl =
          'https://source.unsplash.com/800x600/?food,$encodedPrompt&sig=${DateTime.now().millisecondsSinceEpoch}';

      // Verifica che l'URL sia valido
      final response = await http.head(Uri.parse(fallbackImageUrl));
      if (response.statusCode == 200) {
        _imageCache[cacheKey] = fallbackImageUrl;
        debugPrint('IMMAGINE GENERATA (Unsplash Source): $fallbackImageUrl');
        return fallbackImageUrl;
      } else {
        debugPrint('ERRORE: Unsplash non ha restituito immagine valida');
        return null;
      }
    } catch (e) {
      debugPrint('ERRORE GENERAZIONE IMMAGINE: $e');
      return null;
    }
  }

  // Recupera un'immagine reale dall'API di Unsplash
  Future<String?> fetchFoodImage(String query) async {
    try {
      // Raffina la query con termini di qualità fotografica
      final refinedQuery = 'food photography $query high quality professional';
      final encodedQuery = Uri.encodeComponent(refinedQuery);
      final url = Uri.parse(
          'https://api.unsplash.com/search/photos?query=$encodedQuery&per_page=1&orientation=landscape');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Client-ID ${ApiConfig.unsplashAccessKey}',
        },
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['results'] != null && data['results'].isNotEmpty) {
            final imageUrl = data['results'][0]['urls']['regular'] as String?;
            if (imageUrl != null) {
              debugPrint('IMMAGINE UNSPLASH: $imageUrl');
              return imageUrl;
            }
          }
        } catch (e) {
          debugPrint('ERRORE PARSING UNSPLASH RESPONSE: $e');
        }
      }

      debugPrint('NESSUNA IMMAGINE TROVATA SU UNSPLASH PER: $query');
      return null;
    } catch (e) {
      debugPrint('ERRORE FETCH UNSPLASH: $e');
      return null;
    }
  }

  // Genera un prompt per la generazione di immagini della ricetta
  Future<String?> generaPromptImmagineRicetta(
      String titoloRicetta, String descrizioneRicetta) async {
    // Controlla cache
    final cacheKey = '${titoloRicetta}_prompt';
    if (_imageCache.containsKey(cacheKey)) {
      debugPrint('PROMPT IMMAGINE PRESO DALLA CACHE: ${_imageCache[cacheKey]}');
      return _imageCache[cacheKey];
    }

    try {
      final prompt = '''
      Genera un prompt dettagliato e appetitoso per un modello di generazione immagini AI (come DALL-E, Midjourney, o Stable Diffusion) che rappresenti il seguente piatto:
      
      Titolo: $titoloRicetta
      Descrizione: $descrizioneRicetta
      
      Il prompt deve essere in inglese, dettagliato e includere:
      - Stile fotografico professionale: 'Professional food photography', 'High resolution', 'Top-down view' o '45-degree angle', 'Natural daylight'
      - Dettagli sensoriali: descrivi consistenza (creamy texture, glistening sauce, crispy), colore (vibrant, golden brown), guarnizioni (fresh herbs, parmesan, sauce)
      - Contesto accogliente: 'Rustic wooden table background', 'Soft focus background', 'Warm ambiance'
      - Evita l'effetto artificiale: punta al realismo e all'appetibilità, non a renderizzazioni plasticose
      - Esempio: 'Professional food photography of a steaming pasta carbonara, creamy egg sauce glistening, crispy guanciale bits, fresh cracked black pepper, rustic ceramic plate, natural morning light, wood table, 8k resolution'
      
      Rispondi solo con il prompt, senza altre spiegazioni.
      ''';

      final response = await chiediAGemini(prompt);

      if (response.isNotEmpty) {
        _imageCache[cacheKey] = response;
        debugPrint('PROMPT IMMAGINE GENERATO: $response');
        return response;
      } else {
        debugPrint('ERRORE: Gemini non ha restituito un prompt valido');
        return null;
      }
    } catch (e) {
      debugPrint('ERRORE GENERAZIONE PROMPT IMMAGINE: $e');
      return null;
    }
  }

  // Genera un'immagine per la ricetta usando Unsplash Source API (fallback)
  // Nota: Per una vera generazione AI, integrare con DALL-E, Imagen (Vertex AI), o Stability AI
  Future<String?> generaImmagineRicetta(String titoloRicetta) async {
    // Controlla cache
    if (_imageCache.containsKey(titoloRicetta)) {
      debugPrint('IMMAGINE PRESA DALLA CACHE: ${_imageCache[titoloRicetta]}');
      return _imageCache[titoloRicetta];
    }

    try {
      // Prima prova con Unsplash Search API con termini di qualità
      final keywords = _estraiKeywordCibo(titoloRicetta);
      final searchResult = await fetchFoodImage(keywords);
      if (searchResult != null) {
        _imageCache[titoloRicetta] = searchResult;
        debugPrint('IMMAGINE GENERATA (Unsplash Search): $searchResult');
        return searchResult;
      }

      // Fallback a Unsplash Source API con termini di qualità
      final refinedQuery =
          'food photography $keywords high quality professional';
      final encodedKeywords = Uri.encodeComponent(refinedQuery);
      final imageUrl =
          'https://source.unsplash.com/800x600/?$encodedKeywords&sig=${DateTime.now().millisecondsSinceEpoch}';

      // Verifica che l'URL sia valido
      final response = await http.head(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        _imageCache[titoloRicetta] = imageUrl;
        debugPrint('IMMAGINE GENERATA (Unsplash Source): $imageUrl');
        return imageUrl;
      } else {
        debugPrint('ERRORE: Unsplash non ha restituito immagine valida');
        return null;
      }
    } catch (e) {
      debugPrint('ERRORE GENERAZIONE IMMAGINE: $e');
      return null;
    }
  }

  // Estrae keyword rilevanti dal titolo della ricetta per la ricerca immagini
  String _estraiKeywordCibo(String titolo) {
    // Rimuovi parole comuni che non sono utili per la ricerca
    final paroleComuni = [
      'con',
      'senza',
      'e',
      'al',
      'alla',
      'ai',
      'del',
      'della',
      'dei',
      'di',
      'in',
      'per',
      'da',
      'su',
      'un',
      'una',
      'il',
      'la',
      'lo',
      'le',
      'i',
      'ricetta',
      'piatto',
      'preparazione',
      'facile',
      'veloce',
      'gustoso'
    ];

    final parole = titolo.toLowerCase().split(' ');
    final keyword = parole
        .where((parola) => !paroleComuni.contains(parola))
        .take(3) // Prendi max 3 parole più rilevanti
        .join(',');

    return keyword.isEmpty ? 'food,delicious' : keyword;
  }
}

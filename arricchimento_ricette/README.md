# Arricchimento Ricette

Script Python per arricchire il database delle ricette con ingredienti, dosi, procedimento e immagini generate da Gemini e Unsplash.

## Prerequisiti

- Python 3.8 o superiore
- API Key di Gemini
- API Key di Unsplash (opzionale)

## Installazione

1. Installa le dipendenze:
```bash
pip install -r requirements.txt
```

2. Crea il file `.env` basandoti su `.env.example`:
```bash
cp .env.example .env
```

3. Modifica `.env` e inserisci le tue API keys:
```
GEMINI_API_KEY=la_tua_chiave_gemini
UNSPLASH_ACCESS_KEY=la_tua_chiave_unsplash
```

## Utilizzo

Esegui lo script:
```bash
python arricchisci_ricette.py

```

Lo script:
- Legge il database originale `../assets/SQLite.db`
- Per ogni ricetta, genera ingredienti e procedimento con Gemini
- Cerca un'immagine pertinente su Unsplash
- Salva tutto in `ricette_complete.db`

## Output

Il file `ricette_complete.db` conterrà una tabella `ricette` con:
- `titolo`: Titolo pulito della ricetta
- `descrizione`: Descrizione originale
- `immagine_url`: URL dell'immagine da Unsplash
- `ingredienti`: JSON con lista ingredienti e dosi
- `procedimento`: Procedimento passo-passo

## Integrazione nel progetto Flutter

Una volta generato `ricette_complete.db`:

1. Copia il file nella cartella `assets/` del progetto Flutter
2. Aggiorna `pubspec.yaml` per includere il nuovo file
3. Modifica `DatabaseHelper` per usare il nuovo database

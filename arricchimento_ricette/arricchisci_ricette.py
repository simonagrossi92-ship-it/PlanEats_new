import sqlite3
import os
import json
import time
import ssl
from dotenv import load_dotenv
import google.generativeai as genai
import requests

# Disabilita verifica SSL (per problemi sistemici Windows)
ssl._create_default_https_context = ssl._create_unverified_context

# Carica le variabili d'ambiente
load_dotenv()

GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
UNSPLASH_ACCESS_KEY = os.getenv('UNSPLASH_ACCESS_KEY')

# Configura Gemini
genai.configure(api_key=GEMINI_API_KEY)

# Elenca i modelli disponibili
print("=== MODELLI GEMINI DISPONIBILI ===")
for m in genai.list_models():
    print(m.name)
print("================================\n")

model = genai.GenerativeModel('models/gemini-2.5-flash')

def pulisci_titolo(titolo_grezzo):
    """Rimuove ID numerici e prefissi dal titolo"""
    if not titolo_grezzo:
        return 'Nome Ricetta'
    
    cleaned = titolo_grezzo
    
    # Rimuovi prefissi comuni come 'views/'
    if cleaned.startswith('views/'):
        cleaned = cleaned[6:]
    
    # Rimuovi ID numerico all'inizio (pattern: 10+ caratteri alfanumerici)
    import re
    id_pattern = re.compile(r'^[a-f0-9]{10,}')
    cleaned = id_pattern.sub('', cleaned)
    
    # Rimuovi spazi iniziali
    cleaned = cleaned.strip()
    
    # Capitalizza la prima lettera
    if cleaned:
        cleaned = cleaned[0].upper() + cleaned[1:]
    
    return cleaned if cleaned else 'Nome Ricetta'

def genera_dettagli_ricetta(titolo):
    """Usa Gemini per generare ingredienti, dosi e procedimento"""
    prompt = f"""
    Sei un assistente culinario esperto. Genera i dettagli completi per questa ricetta: "{titolo}".

    Rispondi ESCLUSIVAMENTE in formato JSON con questa struttura esatta:
    {{
      "categoria": "[Antipasti|Primi|Secondi|Dolci]",
      "ingredienti": [
        {{"nome": "[ingrediente]", "quantita": "[quantità]", "unita": "[unità]"}}
      ],
      "procedimento": ["[passaggio 1]", "[passaggio 2]", "[passaggio 3]"]
    }}

    NON aggiungere testo al di fuori del JSON. Assicurati che il JSON sia valido e ben formattato.
    Genera ingredienti realistici e dosi appropriate per 1 persona.
    Classifica questa ricetta in una di queste categorie: Antipasti, Primi, Secondi, Dolci. Restituisci la categoria nel campo 'categoria'.
    """
    
    try:
        response = model.generate_content(prompt)
        response_text = response.text
        
        # Rimuovi eventuali backticks e "json" wrapper
        response_text = response_text.replace('```json', '').replace('```', '').strip()
        
        # Parsa il JSON
        dettagli = json.loads(response_text)
        return dettagli
    except Exception as e:
        if "429" in str(e):
            print(f"Limite API raggiunto per '{titolo}'! Attendo 60 secondi prima di riprovare...")
            time.sleep(60)
            # Riprova la chiamata
            try:
                response = model.generate_content(prompt)
                response_text = response.text
                response_text = response_text.replace('```json', '').replace('```', '').strip()
                dettagli = json.loads(response_text)
                return dettagli
            except Exception as retry_e:
                print(f"Errore anche dopo retry per '{titolo}': {retry_e}")
                return {
                    'categoria': 'Altro',
                    'ingredienti': [{'nome': 'Ingredienti non disponibili', 'quantita': '', 'unita': ''}],
                    'procedimento': ['Procedimento non disponibile']
                }
        else:
            print(f"Errore nella generazione dettagli per '{titolo}': {e}")
            return {
                'categoria': 'Altro',
                'ingredienti': [{'nome': 'Ingredienti non disponibili', 'quantita': '', 'unita': ''}],
                'procedimento': ['Procedimento non disponibile']
            }

def cerca_immagine_unsplash(titolo):
    """Cerca un'immagine pertinente su Unsplash"""
    if not UNSPLASH_ACCESS_KEY:
        print("UNSPLASH_ACCESS_KEY non configurata, uso placeholder")
        return None
    
    try:
        # Usa Unsplash Search API con query più specifica
        url = f"https://api.unsplash.com/search/photos"
        params = {
            'query': f"{titolo} italian cuisine food dish",
            'per_page': 5,  # Aumenta risultati per migliore selezione
            'orientation': 'landscape',
            'order_by': 'relevant'  # Ordina per pertinenza
        }
        headers = {
            'Authorization': f'Client-ID {UNSPLASH_ACCESS_KEY}'
        }
        
        response = requests.get(url, params=params, headers=headers, timeout=10, verify=False)
        
        if response.status_code == 200:
            data = response.json()
            if data['results'] and len(data['results']) > 0:
                # Scegli l'immagine più pertinente (prima risultato)
                return data['results'][0]['urls']['regular']
        
        # Fallback a Unsplash Source API con query più specifica
        encoded_query = requests.utils.quote(f"{titolo} italian food")
        return f"https://source.unsplash.com/800x600/?food,{encoded_query}&sig={int(time.time())}"
    except Exception as e:
        print(f"Errore nella ricerca immagine per '{titolo}': {e}")
        return None

def main():
    # Percorsi dei file
    file_titoli = 'ricette.txt'
    db_completo = 'ricette_complete.db'
    
    print(f"Lettura titoli da: {file_titoli}")
    
    # Leggi i titoli dal file
    with open(file_titoli, 'r', encoding='utf-8') as f:
        titoli = [line.strip() for line in f if line.strip()]
    
    print(f"Trovati {len(titoli)} titoli nel file")
    
    # Crea il nuovo database
    conn_nuovo = sqlite3.connect(db_completo)
    cursor_nuovo = conn_nuovo.cursor()
    
    # Crea la tabella pulita (se non esiste)
    cursor_nuovo.execute('''
        CREATE TABLE IF NOT EXISTS ricette (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            titolo TEXT NOT NULL UNIQUE,
            descrizione TEXT,
            immagine_url TEXT,
            ingredienti TEXT,
            procedimento TEXT,
            categoria TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Processa ogni ricetta
    for i, titolo in enumerate(titoli):
        print(f"\nProcessando ricetta {i+1}/{len(titoli)}")
        
        # Usa il titolo direttamente dal file
        titolo_pulito = titolo
        print(f"  Titolo: {titolo_pulito}")
        
        # Genera dettagli con Gemini
        print(f"  Generazione dettagli con Gemini...")
        dettagli = genera_dettagli_ricetta(titolo_pulito)
        
        # Converti ingredienti in testo semplice con formato standard per parsing
        testo_ingredienti = "\n".join([f"{i['nome']}, {i.get('quantita', '')}{i.get('unita', '')}" for i in dettagli['ingredienti']])
        
        # Converti procedimento in testo semplice
        testo_procedimento = '\n'.join(dettagli['procedimento'])
        
        # Estrai categoria
        categoria = dettagli.get('categoria', 'Altro')
        
        # Cerca immagine su Unsplash
        print(f"  Ricerca immagine su Unsplash...")
        immagine_url = cerca_immagine_unsplash(titolo_pulito)
        
        # Rate limiting: aspetta 25 secondi tra le chiamate API
        time.sleep(25)
        
        # Inserisci nel database (se il titolo esiste già, non fa nulla)
        cursor_nuovo.execute('''
            INSERT OR IGNORE INTO ricette (titolo, descrizione, immagine_url, ingredienti, procedimento, categoria)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (
            titolo_pulito,
            testo_procedimento,
            immagine_url,
            testo_ingredienti,
            testo_procedimento,
            categoria
        ))
        
        print(f"  ✓ Ricetta salvata")
        
        # Pausa per evitare rate limiting
        time.sleep(1)
    
    # Salva e chiudi
    conn_nuovo.commit()
    conn_nuovo.close()
    
    print(f"\n✓ Database completato salvato in: {db_completo}")
    print(f"✓ Processate {len(titoli)} ricette")

if __name__ == "__main__":
    main()

# Verifiche iOS

## Regressioni della scadenza

Dalla root della repository:

```sh
python3 Tests/run_model_tests.py
```

Esegue 6 gruppi di asserzioni sui modelli Foundation del sorgente reale: ultima
settimana, istante esatto di scadenza, cambio dell'ora, date passate e proprietà
usata dalla UI, incluse le etichette singolari/plurali e meno di un giorno. Non accede a Firebase e non richiede un target XCTest.

## Controllo visivo della Home

Con un iOS Simulator già avviato:

```sh
python3 Tests/run_home_previews.py \
  --simulator UDID_DEL_SIMULATORE \
  --output /tmp/sportili-home-previews
```

L'opzione facoltativa `--packages /percorso/SourcePackages` permette di riutilizzare
le dipendenze già risolte da Xcode. Il simulatore deve supportare la versione
minima dell'app e le dipendenze fissate dal progetto devono essere disponibili.

Il comando copia il progetto in una cartella temporanea e sostituisce soltanto
l'avvio con `HomePreviewHost.swift`, escluso dal target dell'app reale. Usa la
`HomeView` e i modelli di produzione con dati in memoria e caricamento remoto
disabilitato; Firebase non viene configurato. Non modifica il progetto originale.
Installa un'app distinta (`com.sportili.local-home-preview`) e la disinstalla
alla fine, lasciando log di build e sette screenshot nella cartella indicata.

Gli screenshot **richiedono controllo visivo**, non sono asserzioni automatiche:

| Scenario | Risultato atteso |
| --- | --- |
| `active` | Status card “Scheda attiva”, riepilogo e giorno principale |
| `expiring` | Status card “Scheda in scadenza” con data residua leggibile |
| `expired` | Unica status card “Scheda terminata” con “Richiedi nuova scheda” |
| `requested` | Status card “Richiesta inviata” e nessun pulsante duplicato |
| `empty` | Stato vuoto distinto con spiegazione e “Riprova” |
| `error` | Errore non tecnico con controllo connessione e “Riprova” |
| `dark` | Stato attivo con palette scura e contrasto semantico |

La UI mostra i giorni interi di calendario nell’ultima settimana e “Meno di un
giorno rimanente” sotto un giorno; scadenza e disponibilità della richiesta
continuano a usare l’istante effettivo di fine.

Questo host non verifica login, trasmissione di una richiesta o intero percorso
Firebase. È separato dalla build completa dell'app, che va verificata anch'essa.

## Login e osservatori: regressioni automatiche

```sh
python3 Tests/run_lifecycle_tests.py
```

Compila il codice reale di `LoginSession` (incluso l’adattatore Firebase),
`SchedaManager` e `SchedaViewModel` sostituendo soltanto il confine SDK con
`FirebaseDoubles.swift`. Copre login valido/admin, codice inesistente e non
valido, errori di entrambe le letture e Auth, timeout, nuovo tentativo,
cancellazione e callback tardive; refresh ripetuti, aggiornamenti realtime,
cambio utente anche tramite UserDefaults, logout e rilascio degli osservatori.
Il runner verifica la logica e i percorsi, non il networking del vero SDK iOS.
Non configura Firebase e non accede al backend.

## Controllo visivo del login

Con un iOS Simulator già avviato:

```sh
python3 Tests/run_login_previews.py \
  --simulator UDID_DEL_SIMULATORE \
  --output /tmp/sportili-login-previews
```

Come il controllo della Home, il runner usa una copia temporanea e un bundle
separato, senza configurare Firebase. Produce screenshot light, dark, Dynamic
Type accessibilità e campo focalizzato per la verifica con tastiera; rimuove
l'app temporanea al termine. Se il Simulator usa una tastiera hardware, lo
screenshot `keyboard.png` conferma focus e layout adattato ma la tastiera
software deve essere verificata interattivamente disattivando “Connect Hardware
Keyboard”.

## Esito del 23 settembre 2026

- Entrambi i runner automatici superati.
- Build Debug Simulator e Release dispositivo con firma disabilitata verificate.
- Tre schermate Home controllate visivamente su iPhone 17 Pro / iOS 26.2:
  giorni residui, scheda scaduta e richiesta inviata.
- Login Auth/rete con il vero SDK iOS e binari già distribuiti non provati.
  Nessun dato, regola o configurazione Firebase di produzione modificato.

## Note per parte: regressioni del 24 settembre 2026

```sh
python3 Tests/run_note_tests.py
```

Esegue le azioni note estratte dalla View di produzione insieme al vero
`ExerciseDetailViewModel`, usando doppi SDK in memoria. Verifica una sola
scrittura in `exerciseData`, parti indipendenti, errore e retry, rimozione della
nota senza perdita di storico e conservazione delle copie legacy nella scheda.
La nota iniziale usa anch’essa `exerciseData`; non viene più sincronizzata una
seconda copia nella scheda. Nessun percorso o formato Firebase è stato cambiato.
Questa prova non sostituisce un test iOS del networking reale e non è una verifica
visiva manuale. Build Debug Simulator e Release dispositivo eseguite senza firma.

## Firebase SDK reale su emulatori locali

Con un iOS Simulator avviato, dalla cartella `firebase-compatibility` della repo
Android:

```sh
IOS_SIMULATOR_UDID=UDID npm run test:ios-sdk
```

Il runner copia temporaneamente il progetto, sostituisce il solo punto di avvio
con `FirebaseSDKHost.swift` e collega il vero SDK iOS agli emulatori Auth e RTDB
del progetto `demo-sportili-compat`. Copre login valido, codice inesistente e non
valido, errore Firebase e retry, refresh ripetuti, cambio utente, realtime e note
con storico/campi sconosciuti preservati. Non accede al progetto di produzione e
rimuove l'app temporanea dal simulatore al termine.

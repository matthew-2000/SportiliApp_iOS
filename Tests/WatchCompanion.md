# Apple Watch companion — prima versione

Target `SportiliWatch`, watchOS 10+, incorporato in `SportiliApp`. Xcode 16+ è
necessario per le nuove cartelle sincronizzate; verificato con Xcode 27.2.
Il deployment target iPhone esistente resta invariato. Nessun SDK Firebase sul
Watch, HealthKit, sessione workout, modifica Android, migrazione o deploy backend.

## Uso

1. Accedere con il codice su iPhone e aprire SportiliApp. Installare il companion
   tramite l'app Watch; il primo trasferimento richiede le app abbinate.
2. Sul Watch aprire giorno ed esercizio. La prescrizione originale e il recupero
   sono sempre visibili. `Peso singolo` salva nel formato storico; disattivandolo
   si possono inserire fino a 20 serie, incluse ripetizioni manuali per istruzioni
   composte che non possono essere interpretate automaticamente.
3. Toccare peso/ripetizioni, ruotare la Crown o usare +/− e confermare. `Usa ultimi
   pesi` compare soltanto quando l'intera sequenza ordinata delle ripetizioni
   coincide. I pesi legacy non ricevono ripetizioni inventate.
4. Le spunte sono locali e indipendenti dai carichi registrati. `Registra carichi`
   crea una registrazione immutabile; modificarne poi i valori e registrare crea
   un'altra registrazione. Non è un editor dello storico iPhone.
5. `Registrazioni` distingue salvataggio locale, ricezione iPhone, attesa/errori
   Firebase, salvataggio effettivo e conflitti. Riapertura, raggiungibilità,
   riconnessione Firebase e `Aggiorna / riprova` riattivano i tentativi. Con app
   Watch attiva c'è anche un controllo ogni minuto; nessun timer mantiene viva
   l'app in background.
6. Il recupero usa una scadenza persistente e una notifica locale watchOS,
   indipendente dalla sincronizzazione. Non richiede sessioni salute/workout.
   Se le notifiche sono negate, il messaggio lo segnala e il conto alla rovescia
   resta visibile. Avviso e vibrazione dipendono dalle impostazioni di sistema
   (Focus, silenzioso, notifiche); vanno provati al polso.

## Contratto e affidabilità

- Protocollo JSON v1: snapshot scheda, registrazione e ricevuta. Sul Watch non
  transitano codice di accesso, UID, password o token Firebase. Il binding è un
  UUID opaco, valido solo per la sessione utente corrente sull'iPhone.
- Snapshot sostituibili: `updateApplicationContext`, messaggio immediato quando
  raggiungibile e `transferFile` per schede oltre 55 KB. Revisione monotona
  persistente: un vecchio file/context non può ripristinare l'utente precedente.
  Le richieste `refresh` del Watch ricevono anche la scheda come risposta diretta:
  questo percorso non dipende dal flag di raggiungibilità visto dall'iPhone.
  Un fallimento del contesto non impedisce il tentativo di messaggio immediato.
- Registrazioni e ricevute: `transferUserInfo` durevole più messaggi immediati
  opzionali. La sola consegna non elimina la coda. Ritardi in background non
  hanno una durata garantita; `isReachable` non equivale a connessione Firebase.
- Ogni registrazione ha UUID `watch_<UUID>`, timestamp millisecondi e contenuto
  immutabili. Coda Watch e inbox/ricevute iPhone sono JSON salvati con sostituzione
  atomica in Application Support **prima** di inviare o confermare la ricezione.
  Un errore disco non viene presentato come successo; un archivio corrotto non
  viene sovrascritto silenziosamente.
- Singoli: `users/{code}/exerciseData/{aliasEsistente}/weightLogs/{id}`.
  Serie: `users/{code}/weightSessions/{canonicalExerciseKey}/{id}`.
  Stessi payload di `Tests/WeightSessions.md`; nessun campo aggiunto al backend,
  nessuna sostituzione di interi sottoalberi. Le chiavi provengono dalle schede
  già emesse dall'iPhone e vengono conservate per le registrazioni offline.
  Per ogni singolo accettato viene fissato anche l'alias legacy: un suo cambio
  successivo non può deviare il retry su un secondo percorso e creare duplicati.
- La transazione Firebase inserisce solo un nodo assente; un retry identico
  verifica comunque il commit sul server. Un valore differente è un conflitto,
  mai una sovrascrittura. Una ricevuta salvata sul telefono evita di riapplicare
  un retry se la stessa registrazione è stata successivamente modificata o
  eliminata su iPhone. Un crash tra commit e ricevuta viene recuperato tramite
  UUID e confronto atomico. Le transazioni offline Firebase da sole non sono
  persistenti: l'inbox applicativa le ricrea al riavvio.
- Al cambio scheda viene aggiornata l'impronta delle prescrizioni. Bozze,
  completamenti e timer della vecchia scheda vengono azzerati con un messaggio;
  le registrazioni già in coda mantengono esercizio e ripetizioni originali.
- Logout/cambio codice o UID revocano il binding. I percorsi di una scrittura
  già iniziata restano quelli dell'utente originale; le callback tardive non
  confermano operazioni della nuova sessione. La coda del vecchio utente resta
  isolata sul Watch e non viene associata automaticamente neppure a un nuovo
  accesso con lo stesso codice. I valori possono essere consultati per un
  eventuale reinserimento manuale nell'account originale.

## Verifiche riproducibili

```sh
python3 Tests/run_watch_sync_tests.py
python3 Tests/run_watch_transport_tests.py
python3 Tests/run_weight_session_tests.py
python3 Tests/run_s05_tests.py
python3 Tests/run_note_tests.py
python3 Tests/run_lifecycle_tests.py
```

Le fixture Foundation eseguono i modelli di produzione: UUID duplicati,
immutabilità, consegna distinta dal commit, errore/retry, ricevute fuori ordine,
riavvio di entrambi gli archivi, conflitti, aggiornamento scheda, vecchi context,
logout/cambio utente/nuovo login, alias legacy, corruzione, dati invalidi e recuperi.

Con un iPhone Simulator già avviato e Java disponibile:

```sh
npx -y firebase-tools@latest emulators:exec \
  --project demo-sportili-watch --config Tests/WatchEmulator/firebase.json \
  --only auth,database \
  'python3 Tests/run_watch_firebase_tests.py --simulator IPHONE_UDID'
```

`--packages /percorso/SourcePackages` riusa le dipendenze Xcode esistenti.
L'host configura esclusivamente `demo-sportili-watch` e loopback 19199/19100,
namespace `demo-sportili-watch-default-rtdb`, senza usare il plist di produzione.
Il bundle di test distinto viene disinstallato alla fine. Le regole in
`WatchEmulator` sono solo fixture locali: **non sono le regole di produzione né
una verifica di autorizzazione delle release installate** e non vanno distribuite.
Il writer Firebase reale verifica insert/retry, conflitto con edit iPhone,
compatibilità con il parser iOS esistente, singoli senza alterare note/storico,
nessuna conferma offline, riconnessione, scrittura negata e isolamento utenti.

Build:

```sh
xcodebuild -project SportiliApp.xcodeproj -scheme SportiliApp \
  -destination 'generic/platform=iOS Simulator' build
xcodebuild -project SportiliApp.xcodeproj -scheme SportiliWatch \
  -destination 'generic/platform=watchOS Simulator' build
```

Gli harness iPhone preesistenti usano `companion_test_support.py` per copiare le
nuove sorgenti e separare il target Watch nella copia temporanea, mantenendo
validi i bundle isolati delle preview. Nessun progetto originale viene alterato
dagli harness. `Tools/WatchProjectSetup` usa Swift/XcodeProj, senza Ruby o parsing
manuale del pbxproj; non occorre rieseguirlo dopo aver aperto il progetto.

Solo nelle build Debug, avviare `SportiliWatch` con `--watch-fixture` per dati
completamente locali. `--watch-screen=exercise`, `--watch-screen=crown` e
`--watch-screen=queue` mostrano le viste dedicate. `--watch-self-check` esercita
in-app piramidale, spunta, accodamento e reset; scrive PASS nel file indicato da
`WATCH_TEST_RESULT` (tramite `SIMCTL_CHILD_WATCH_TEST_RESULT` con simctl).
Le fixture non attivano Watch Connectivity né scrivono su Firebase.

Interfaccia aggiornata con accento arancio condiviso, card dei giorni numerate,
quantità di esercizi, controlli delle serie con valori separati e recupero più
leggibile. Verifica visiva su Simulator 40 e 46 mm; sfondi e caratteri restano
nativi SwiftUI. Le fixture Debug aggiuntive `--watch-screen=day`,
`--watch-screen=sets` e `--watch-screen=timer` permettono di controllare le viste
intermedie senza modificare dati reali o programmare notifiche.

## Risultati e limiti

Verificati il 14 novembre 2026: build dei due target per Simulator; tutti i test
sopra; writer nativo contro emulatori Auth/RTDB; avvio e controllo visivo con
fixture su Apple Watch SE 3 40 mm/watchOS 26.2, editor Crown, esercizio e coda;
self-check nell'app Watch e preview Home iPhone 17 Pro/iOS 26.2.

Servono ancora iPhone e Apple Watch **fisici abbinati** per verificare consegna
`transferUserInfo`, risveglio/background/terminazione, cambio Watch abbinato,
Crown fisica e notifica/vibrazione con display spento, Focus e riavvio reale.
I simulatori non dimostrano l'affidabilità del trasporto Watch Connectivity.
Non è stata eseguita una validazione App Store/provisioning o una pubblicazione.

Il 15 novembre è stato verificato anche lo scambio effettivo della scheda fra
iPhone 18 Pro Max/iOS 27 e Apple Watch Series 12/watchOS 27 su Simulator,
senza scritture di prova su Firebase. Il runtime riportava sul telefono
`WCErrorCodeWatchAppNotInstalled` nonostante il companion fosse installato e
raggiungesse l'iPhone. Dopo l'aggiornamento in-place e il riavvio delle due app,
il runtime ha riallineato lo stato di installazione e la scheda è stata ricevuta
e persistita sul Watch. È stato aggiunto anche il percorso di risposta diretta a
`refresh`. I test del trasporto coprono questo percorso, il fallimento
indipendente del contesto e la risposta vuota durante il caricamento iniziale.
Questa verifica in primo piano non sostituisce quella del trasporto in background
su dispositivi fisici.

L'archivio conserva le registrazioni e le ricevute per non perdere deduplicazione;
una politica di archiviazione/esportazione è rinviata. Un Watch offline non può
sapere immediatamente che sull'iPhone è avvenuto un logout: conserva la scheda
con data/stato di aggiornamento fino al prossimo contatto; il telefono comunque
rifiuta le operazioni del binding revocato. Rimozione dell'app, perdita o
corruzione del suo archivio locale non sono equivalenti a un normale riavvio;
in questi casi dati non sincronizzati potrebbero richiedere recupero manuale.

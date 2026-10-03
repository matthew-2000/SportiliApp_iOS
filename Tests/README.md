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
alla fine, lasciando log di build e gli screenshot selezionati nella cartella indicata.

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
Copre anche il mantenimento della scheda durante refresh/failure, retry, snapshot
assente e isolamento dopo cambio utente (S03). Il runner verifica la logica e i
percorsi, non il networking del vero SDK iOS.
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

## Controllo visivo giorno ed esercizio

Con un iOS Simulator già avviato:

```sh
python3 Tests/run_exercise_previews.py \
  --simulator UDID_DEL_SIMULATORE \
  --output /tmp/sportili-exercise-previews
```

Il runner usa una copia temporanea, non configura Firebase e produce gli stati
giorno con nomi lunghi/superset, esercizio con e senza immagine, storico vuoto e
popolato, timer, inserimento peso con tastiera, salvataggio, Dynamic Type
accessibilità e dark mode. Gli screenshot richiedono controllo visivo; se il
Simulator usa una tastiera hardware, la tastiera numerica software va verificata
anche interattivamente.

## Controllo visivo avvisi e impostazioni

Con un iOS Simulator già avviato:

```sh
python3 Tests/run_alerts_settings_previews.py \
  --simulator UDID_DEL_SIMULATORE \
  --output /tmp/sportili-alerts-settings-previews
```

Il runner crea un host temporaneo che non configura Firebase e non osserva il
database. Produce screenshot degli avvisi caricati, vuoti e in errore, oltre a
light/dark e Dynamic Type accessibilità per avvisi e impostazioni. Verificare
visivamente gerarchia delle priorità, assenza di falsi indicatori “nuovo”,
leggibilità delle sezioni, versione/build e assenza di troncamenti.

La conferma di logout e il feedback quando un link esterno non si apre restano
controlli interattivi: l'host inietta azioni innocue e non modifica la sessione.

## Scenari S03 e controllo interattivo

`run_home_previews.py --scenarios` seleziona gli stati: `active`, `expiring`,
`expired`, `requested`, `empty`, `error`, `dark`, `accessibility`, `cached-error`,
`refreshing`, `loading`, `expired-dark`, `error-large`, `empty-large`,
`cached-error-large`. I due giorni locali conservano nomi/gruppi e non contengono
esercizi, per aprire la `DayView` reale senza richiedere immagini Storage. Non
attivare Riprova/richiesta in questo host: i callback Home restano quelli di
produzione. Il retry del modello è coperto dal runner lifecycle con SDK doubles.

Il login supporta `light`, `dark`, `accessibility`, `keyboard`, `long-code`,
`error`, `error-large`, `keyboard-large` tramite `--scenarios`; usa `LoginSession`
con letture fake fallite e nessun salvataggio. Focus iniziale non garantisce
l'apertura della tastiera software: toccare il campo nel Simulator e verificare
la tastiera visibile prima di acquisire una prova. Aiuto e submit sono reali,
con confine Firebase sostituito.

Entrambi i runner accettano `--derived-data /tmp/cartella-isolata` per riusare
una build di fixture e `--keep-installed` per proseguire con verifiche manuali.
In questo caso rimuovere poi il bundle con `xcrun simctl uninstall UDID
com.sportili.local-home-preview` o `com.sportili.local-login-preview`. Le opzioni
predefinite continuano a disinstallare l'host.


## Sprint S04 — giorno e dettaglio

`python3 Tests/run_s04_previews.py --simulator UDID --output /tmp/s04-ios`
usa un host separato senza Firebase. Supporta `--packages`, `--derived-data`,
`--scenarios` e `--keep-installed` come il runner Home. Scenari predefiniti:
giorno e dettaglio 1/2/3 parti, nome lungo singolo, success/loading/error,
light/dark e accessibility3. DayView/EsercizioView e navigazione sono reali;
immagini locali e ExerciseDetailViewModel(autoObserve: false, userCode: "")
eviteranno accessi e salvataggi al backend. I dati per parte sono distinti:
10/20/30 kg, note 1/2/3; Élite risolve la chiave legacy `lite`.

Controllare scroll, apertura giorno→dettaglio, cambio parte, timer e fullscreen.
Non trattare le acquisizioni automatiche come test UI. Al termine disinstallare
`com.sportili.local-s04-preview` se si è usato `--keep-installed`.
`python3 Tests/run_image_loader_tests.py` controlla reset, callback tardive,
errore/retry e dati immagine invalidi, compilando ImageLoader reale con doubles.
`python3 Tests/run_note_tests.py` copre note per parte e chiavi canoniche/legacy.

## S05 — pesi, note, progressi e timer

`python3 Tests/run_s05_tests.py` compila parser, handler peso, finestra campioni e parser timer reali con doubles SDK. Verifica virgola/punto, invalido/non-finito, pending/duplicati/cancel, failure/retry/edit, chiave legacy, payload/history e 0/1/10/>10 campioni con date irregolari. `python3 Tests/run_note_tests.py` include snapshot emesso da @Published (willSet), bozza durante refresh e isolamento delle parti.

`python3 Tests/run_s05_previews.py --simulator <UDID già booted> --output <directory> --packages <SourcePackages> [--derived-data <directory isolata>] [--keep-installed]` costruisce un host separato senza Firebase configurato: grafico 0/1/10/12, editor/sheet reali, tastiera, errore/pending, note vuote/lunghe, timer/fallback, chiaro/scuro/accessibility3. Le environment Dynamic Type sono applicate esplicitamente anche al contenuto delle sheet. La copia temporanea del model riceve solo una funzione locale di aggiornamento fixture; la sorgente produzione e il progetto restano invariati. `ExerciseDetailActions` delega al model in produzione; soltanto la fixture fornisce callback locali.

Gli screenshot sono prove visive, non UI assertions. Verificare manualmente selezione parti, peso vicino allo storico, espansione, bozza/Scarta/Continua, salvataggio riuscito senza badge dirty, valori/date e timer Inizia/Pausa/Azzera. Nessuna prova Firebase/Storage o notifiche/background aggiunta. Disinstallare `com.sportili.local-s05-preview` dopo la verifica.

## S06 — avvisi e impostazioni

`run_alerts_settings_previews.py` accetta `--derived-data`, `--keep-installed` e
`--scenarios`. Gli scenari predefiniti comprendono tutte le priorità (anche
nessuna/senza scadenza), testo lungo, loading, vuoto ed errore in chiaro/scuro e
accessibilityExtraExtraLarge. Le impostazioni mantengono Form/Link e dialoghi
reali. `settings-link-error[-dark|-accessibility]` inietta OpenURLAction.discarded;
`settings-logout-error[-dark|-accessibility]` inietta un signOut fallito.
Gli altri scenari settings usano link gestiti localmente e logout innocuo;
il login dopo logout usa callback fake sostituite soltanto nella copia temporanea.
Il log console stampa gli URL ricevuti senza aprire siti. Non vengono configurati
Firebase, credenziali o sessioni reali. Le azioni e lo scroll sono controlli manuali,
non assert UI automatici. Disinstallare `com.sportili.local-alerts-settings-preview`
al termine se si è usato `--keep-installed`.

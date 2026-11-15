# Recupero, widget e complicazione

## Implementazione e uso

- Aprire un esercizio, aprire il timer e toccare Avvia. La durata viene dal parser esistente dell’esercizio. La scadenza e la durata vengono salvate sul telefono; chiudere la schermata non interrompe il recupero. Pausa e Reimposta cancellano l’avviso e terminano la Live Activity; Riprendi programma una nuova scadenza.
- ActivityKit mostra il countdown sulla schermata bloccata e nella Dynamic Island compatibile. La notifica locale di fine recupero è separata e richiede il consenso. Nessun audio continuo, HealthKit, workout o servizio remoto.
- Aprire un giorno della scheda lo sceglie per il widget. Aggiungere «Scheda» dalla galleria Home o schermata bloccata. Il riepilogo contiene solo identificativo del giorno, nome, numero di esercizi e identificativo casuale della sessione. Non contiene codice d’accesso, UID o token Firebase.
- Sul Watch aprire un giorno e aggiungere «Scheda» alle complicazioni compatibili. Il Watch usa esclusivamente il proprio snapshot già ricevuto da WatchConnectivity. Un collegamento non più valido mostra «Giorno non disponibile» e consente di tornare alla scheda.
- Le app invalidano lo snapshot al cambio di sessione; i collegamenti includono una sessione casuale, così un vecchio collegamento non può aprire il giorno omonimo di un altro utente. Nuovi dati aggiornano o cancellano il giorno scelto.

## iPhone e Watch: avvisi distinti

Il companion aveva già una scadenza persistente e una notifica locale. Il suo recupero resta locale al Watch: l’iPhone non programma una seconda notifica per quella scadenza. Gli avvisi iPhone possono essere inoltrati dal sistema al Watch; non ne viene creata una seconda copia watchOS. Avviare volontariamente due recuperi sui due dispositivi crea due timer indipendenti. Non è introdotta una sincronizzazione del timer tramite un canale che può essere offline.

Le richieste hanno identificativi univoci per evitare che una risposta tardiva del sistema ripristini un avviso cancellato o sostituisca quello nuovo. Rimosso l’impulso aptico manuale in primo piano sul Watch: presentazione, suono e vibrazione dipendono dal sistema.

## Limiti reali

- Permessi, modalità silenziosa, Full immersion e impostazioni notifiche possono silenziare, spostare o ritardare gli avvisi. Il testo nel timer segnala le notifiche negate. L’app non forza una vibrazione separata.
- Senza esecuzione in background o push, iOS non garantisce di eseguire codice alla scadenza per rimuovere la Live Activity. Il countdown si ferma a zero e l’attività diventa obsoleta alla scadenza; viene terminata alla riapertura o con Pausa/Reimposta/logout. Può restare visibile fino alla rimozione del sistema. La notifica locale rimane indipendente.
- WidgetKit decide quando applicare i reload. La cancellazione locale e l’invalidazione dei link sono immediate nel processo dell’app; una rappresentazione già memorizzata dal sistema può persistere temporaneamente.
- Un Watch scollegato non può conoscere immediatamente un logout/cambio codice avvenuto sull’iPhone. Il protocollo esistente invalida dati, timer e avviso quando arriva il nuovo binding o la revoca. Non è garantita una cancellazione remota immediata offline. Non sono introdotte restrizioni che eliminino il funzionamento offline esistente.
- I widget iPhone aggiunti richiedono iOS 17; complicazioni watchOS 10. La Live Activity richiede ActivityKit e autorizzazione del sistema. Nessuna modifica al deployment target delle app esistenti.
- Per dispositivi fisici occorre abilitare l’App Group `group.com.matthew.SportiliApp.surfaces` nei profili dei quattro target e registrare/provisionare i due identificativi delle estensioni. Sono state aggiunte soltanto configurazioni locali, senza modifiche al portale Apple.

## Verifiche

- Build Debug simulatore dello schema SportiliApp: include app iPhone, SportiliWatch, SportiliWidgets e SportiliWatchWidgets; firma disabilitata soltanto dal comando di build.
- Installazione e avvio su iPhone 18 Pro Max / iOS 27 e Apple Watch Series 12 / watchOS 27. Verificati la scelta del giorno iPhone e l’elenco esercizi Watch con fixture locali.
- `--qa-screen=active --qa-native-checks`: usa un’istanza del timer con defaults isolati e nessuna autenticazione. Verifica scadenza, durata originale, sostituzione, cancellazione durante richieste asincrone, singolo avviso programmato con consenso, ripristino, scadenza, cancellazione snapshot e rotazione sessione. Esito in Documents/native-checks.txt. Non attiva il bridge Firebase di produzione.
- Passano `python3 Tests/run_lifecycle_tests.py`, `python3 Tests/run_watch_sync_tests.py` e `python3 Tests/run_watch_transport_tests.py`.
- Ancora da provare su dispositivi fisici: suono/vibrazione reali, instradamento iPhone/Watch con polso e blocco schermo, Do Not Disturb, durata in background prolungata, installazione dei widget nelle varie gallerie e quadranti, provisioning App Groups, percorsi con scheda reale e cambio utente fra dispositivi offline. Non sono dichiarati verificati tutti i layout delle gallerie o la precisione degli avvisi su hardware.

## Fonti ufficiali

- [ActivityKit e Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
- [staleDate](https://developer.apple.com/documentation/activitykit/activitycontent/staledate)
- [Notifiche locali](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/SchedulingandHandlingLocalNotifications.html)
- [Inoltro iPhone/Watch](https://developer.apple.com/documentation/watchos-apps/taking-advantage-of-notification-forwarding)
- [WidgetKit](https://developer.apple.com/documentation/widgetkit/)

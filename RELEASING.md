# Rilasci con Xcode Cloud

## Stato

Il repository contiene il post-clone hook che esegue otto runner di regressione
prima della build. Non contiene credenziali o procedure di pubblicazione della
produzione. Collegamento e workflow Xcode Cloud vanno verificati nell'account Apple.

## Configurazione iniziale, una sola volta

1. Pubblicare su GitHub questi file insieme alla revisione dell'app da provare.
2. Controllare prima i workflow esistenti in App Store Connect, senza duplicarli.
   In Xcode aprire `SportiliApp.xcodeproj`, selezionare lo schema condiviso
   `SportiliApp` e usare Product > Xcode Cloud > Create Workflow. Collegare
   il repository esistente ad App Store Connect.
3. Scegliere una versione Xcode compatibile con il progetto (sviluppato con
   Xcode 27.2) e con gli SDK iOS/watchOS necessari. Se non disponibile nel cloud,
   fermare il setup e verificare la compatibilità, senza abbassare i requisiti
   o cambiare il progetto automaticamente.
4. Creare il workflow `Verifica`: avvio sui push e sulle pull request verso il branch
   principale, azione Build. Il post-clone esegue già i runner; lo schema non
   ha un target XCTest e non va presentato come una suite `xcodebuild test`.
   Eseguire `ci_scripts/ci_post_clone.sh` anche localmente per verificare gli
   stessi otto runner; lo script deve restare eseguibile nel repository.
5. Creare il workflow `Beta`: avvio manuale sul branch principale, azione
   Archive per distribuzione TestFlight e post-action per il gruppo di tester
   interni desiderato. Non aggiungere invii automatici alla produzione.
6. Confermare la firma di app, widget iOS, app Watch e widget Watch, con tutti
   gli identificativi e gli entitlement esistenti. Verificare che l'archivio
   includa gli stessi componenti della distribuzione locale.
7. Confrontare il massimo numero di build già caricato su App Store Connect
   con il contatore Xcode Cloud; impostare il prossimo numero sopra il massimo.
   Verificare sul primo archivio i numeri di app e componenti incorporati.
8. Eseguire una Beta, verificare log dei runner, archivio firmato, disponibilità
   TestFlight e funzionamento su iPhone/Watch. Abilitare notifiche native Apple.

## Ogni aggiornamento

- Aggiornare la versione commerciale quando necessario, coerente tra tutti i
  target. Xcode Cloud gestisce il numero progressivo delle build: non usare il
  numero locale come prova del numero effettivamente distribuito.
- Avviare `Beta`, provare la build ricevuta e conservare il riferimento al commit.
- Se approvata dal proprietario, selezionare quella stessa build in App Store
  Connect, completare novità/dichiarazioni e inviare alla revisione.
- Per i primi rilasci mantenere l'uscita manuale dopo la revisione e attivare
  il rilascio graduale ufficiale di sette giorni quando appropriato.

La selezione della build e l'invio alla revisione restano manuali in questa
prima configurazione. L'automazione della produzione viene dopo una Beta
riuscita, con una scelta esplicita sul momento di pubblicazione.

## Limiti dei controlli

Il hook verifica logica e boundary doubles, non networking Firebase, StoreKit,
firma, UI completa o trasporto reale su Watch. Una build cloud verde non prova
la compatibilità di ogni versione installata. Per cambi a Firebase/admin usare
anche la suite `firebase-compatibility` del repository Android e le verifiche
native pertinenti, annotando gli SHA di entrambi i repository. Nessuno di questi
workflow deve pubblicare regole Firebase o modificare dati di produzione.

Fonti: [script Xcode Cloud](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts),
[avvio Xcode Cloud](https://developer.apple.com/xcode-cloud/get-started/),
[rilascio graduale](https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases).

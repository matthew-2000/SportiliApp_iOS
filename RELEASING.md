# Produzione iOS: Xcode Cloud e App Store Connect API

## Flusso

GitHub coordina la procedura; **compilazione e firma restano su Xcode Cloud**.
Pubblicare un tag `vX.Y.Z` sul commit corrente di `main` (oppure avviare
manualmente `iOS - Produzione App Store` da `main`): archive Apple, attesa elaborazione,
riepilogo con commit/versione/build/note, **una approvazione** nell'environment
`app-store-production`, invio della stessa build ad App Review.
La versione usa `releaseType=AFTER_APPROVAL`: Apple rilascia dopo la propria
approvazione. Nessun passaggio obbligatorio su TestFlight.
Nessuna modifica a Firebase, dati, accessi o flussi delle app installate.

## Setup una sola volta

1. Unire la PR. Controllare i workflow Apple esistenti prima di crearne altri.
2. Mantenere `Verifica` su push/PR verso `main`, azione Build.
   `ci_scripts/ci_post_clone.sh` esegue gli otto runner; non sono target XCTest.
3. Configurare un workflow Xcode Cloud `Produzione`, avviabile tramite API,
   schema `SportiliApp`, Archive per **App Store Connect**, Xcode compatibile
   con il progetto (27.2 nel checkout). Nessun gruppo tester obbligatorio.
   Non usare `Internal Only`. Confermare l'upload dell'archive ad App Store
   Connect e la firma di app, Watch ed entrambi i widget.
4. Impostare il contatore Cloud sopra il massimo numero di build già caricato.
   Conservare gli identificativi e gli entitlement esistenti.
5. In App Store Connect > Users and Access > Integrations creare una chiave
   API di team App Manager con l'accesso necessario all'app e a Xcode Cloud.
   Conservare Issuer ID, Key ID e file P8. Non sostituisce i certificati Cloud.
6. Impostare variabili e segreti della tabella. Per trovare gli ID via API:
   `GET /v1/apps?filter[bundleId]=com.matthew.SportiliApp`, relazione `ciProduct`,
   `GET /v1/ciProducts/{id}/workflows`, relazione `repository` del workflow,
   `GET /v1/scmRepositories/{id}/gitReferences`. Scegliere il riferimento con
   `canonicalName=refs/heads/main`.
7. Creare l'environment `app-store-production`, limitato al branch `main` e ai tag `v*`, con Matteo
   come **required reviewer**. Consentire l'approvazione della propria
   esecuzione se Matteo avvia il workflow; disabilitare il bypass delle regole.
   Il solo campo `environment:` nel YAML NON crea la regola di approvazione.
8. Verificare contratti, privacy, contatti e requisiti App Review nello store.
   Completare l'export compliance reale della build: lo script non inventa
   dichiarazioni e non imposta `usesNonExemptEncryption=false` automaticamente.
9. Solo dopo il setup impostare `APP_STORE_PRODUCTION_ENABLED=true`.

| Variabile di repository | Contenuto |
| --- | --- |
| `APP_STORE_PRODUCTION_ENABLED` | true solo con account e reviewer pronti |
| `ASC_APP_ID` | ID numerico della scheda SportiliApp |
| `XCODE_CLOUD_WORKFLOW_ID` | UUID del workflow Apple Produzione |
| `XCODE_CLOUD_MAIN_REF_ID` | ID del riferimento Git Apple per main |

| Secret di repository | Contenuto |
| --- | --- |
| `ASC_ISSUER_ID` | Issuer ID della chiave API di team |
| `ASC_KEY_ID` | Key ID |
| `ASC_PRIVATE_KEY_P8` | Intero contenuto della chiave privata P8 |

La chiave di repository serve anche al primo job per avviare Cloud prima
che sia richiesta l'approvazione. Il job di invio è protetto dall'environment.
Proteggere `main` e revisionare workflow/script: chi può modificarli può
cambiare l'uso della chiave API. Non mettere il P8 in Git, chat o artifact.
JWT firmati tramite OpenSSL, senza fastlane o dipendenze Python aggiuntive.

## Ogni rilascio

1. Impostare la versione commerciale in tutti i target Xcode e fare commit
   su `main` con un JSON di note sotto `release-notes/`, per tutte le lingue
   già configurate nello store.
2. Actions > `iOS - Produzione App Store`, su `main`: versione, percorso JSON
   e rilascio graduale Apple (predefinito) oppure completo.
3. Il workflow avvia Cloud e attende fino a due ore. Controlla successo, SHA,
   workflow, riferimento main, versione, bundle ID, elaborazione valida ed
   eleggibilità App Store della build.
4. Leggere il riepilogo e approvare una volta.
5. La procedura ricontrolla i dati Apple, crea la versione se manca (Apple
   trasferisce i metadati correnti), aggiorna note/build/rilascio e invia ad
   App Review. Eventuali metadati o dichiarazioni mancanti producono un errore
   Apple da risolvere; nessuna risposta viene inventata.

Il rilascio graduale Apple progredisce automaticamente in sette giorni dopo
l'approvazione; gli utenti possono comunque aggiornare manualmente.
La ricevuta prova l'invio, non l'approvazione o la disponibilità pubblica.

Non modificare la stessa release contemporaneamente nella console. Le review
pendenti non vengono cancellate o riutilizzate. Un errore dopo la creazione
può lasciare una review in bozza: verificare e risolvere quella bozza prima
di ripetere la procedura. Nessun retry automatico delle scritture.
Se l'attesa Cloud scade, controllare il run nel log prima di avviare una nuova
build. Se main cambia prima che Cloud prelevi il codice, lo SHA blocca l'invio.

## Verifica e limiti

`python3 -m unittest discover -s ci_scripts -p 'test_*.py' -v`

Test con API simulate e verifica di una firma JWT reale tramite OpenSSL.
Non sono una prova di firma dell'app o di invio allo store. Setup degli
account e prima esecuzione reale restano necessari. Versioni commerciali e
dichiarazioni legali non vengono cambiate automaticamente.

Fonti: [Cloud API](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-cibuildruns),
[versioni](https://developer.apple.com/help/app-store-connect/update-your-app/create-a-new-version),
[review](https://developer.apple.com/documentation/appstoreconnectapi/review-submissions),
[rilascio graduale](https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases).

## Avvio da tag

Prima del tag fare commit su main delle versioni commerciali Xcode e delle
note in `release-notes/X.Y.Z.json`, con la mappa delle lingue già descritta.
Pubblicare il tag `vX.Y.Z` su quel commit: avvia automaticamente Cloud, poi
richiede l'approvazione. I tag usano il rilascio graduale Apple di sette giorni;
per scegliere il rilascio completo usare l'avvio manuale.

Il tag deve indicare il commit corrente di main e corrispondere alla versione
di tutti i target. Cloud continua a prelevare main: se il branch avanza prima
del checkout Apple, lo SHA differisce e l'invio viene bloccato. Evitare push
successivi durante la preparazione della release. Non spostare tag pubblicati.

Nell'environment app-store-production consentire branch main e tag v*.
Un push normale avvia solo i controlli. Non abilitare in parallelo un ulteriore
trigger automatico per tag su Xcode Cloud: è GitHub ad avviare l'archive via API.

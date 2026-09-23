# Verifiche iOS

## Regressioni della scadenza

Dalla root della repository:

```sh
python3 Tests/run_model_tests.py
```

Esegue 5 gruppi di asserzioni sui modelli Foundation del sorgente reale: ultima
settimana, istante esatto di scadenza, cambio dell'ora, date passate e proprietà
usata dalla UI. Non accede a Firebase e non richiede un target XCTest.

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
alla fine, lasciando log di build e tre screenshot nella cartella indicata.

Gli screenshot **richiedono controllo visivo**, non sono asserzioni automatiche:

| Scenario | Risultato atteso |
| --- | --- |
| `last-week` | 6 giorni residui: nessun banner di scadenza o pulsante di richiesta; conteggio non rosso |
| `expired` | Banner rosso e pulsante “Richiedi nuova scheda” |
| `requested` | Banner rosso, “Richiesta inviata” e nessun pulsante per inviarla di nuovo |

La UI attuale mostra ancora “0 settimane rimanenti” nell'ultima settimana;
questa prova conferma che ciò non attiva prematuramente lo stato di scadenza.

Questo host non verifica login, trasmissione di una richiesta o intero percorso
Firebase. È separato dalla build completa dell'app, che va verificata anch'essa.

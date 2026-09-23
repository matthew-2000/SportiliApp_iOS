"""Run regression assertions against production Foundation models, without Firebase.

Usage from the iOS repository: python3 Tests/run_model_tests.py
The Xcode project has no test target. Scheda.swift currently also contains its
Firebase manager, so this runner compiles only the model portion of that file.
No model implementation is copied into the tests or modified on disk.
"""

from pathlib import Path
import subprocess


root = Path(__file__).resolve().parents[1]
models = root / "SportiliApp" / "Model"
scheda_source = (models / "Scheda.swift").read_text()
model_source, separator, _ = scheda_source.partition("\nclass SchedaManager {")
if not separator or "class Scheda: Codable" not in model_source:
    raise SystemExit("Scheda.swift layout changed: update the model test runner.")
model_source = model_source.replace("import Firebase\n", "")
sources = [(models / name).read_text() for name in (
    "Esercizio.swift", "GruppoMuscolare.swift", "Giorno.swift"
)]
sources.extend([model_source, (root / "Tests" / "SchedaExpiryTests.swift").read_text()])
result = subprocess.run(["xcrun", "swift", "-"], input="\n".join(sources), text=True)
raise SystemExit(result.returncode)

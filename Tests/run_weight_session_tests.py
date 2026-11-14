"""Run production session models and Firebase manager against local SDK doubles."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
sources = ["import Foundation\nimport Combine", (root / "Tests/FirebaseDoubles.swift").read_text()]
sources += [(root / "SportiliApp/Model" / name).read_text().replace("import FirebaseDatabase", "")
            for name in ["Esercizio.swift", "ExerciseDetailViewModel.swift"]]
sources.append((root / "Tests/WeightSessionTests.swift").read_text())
raise SystemExit(subprocess.run(["xcrun", "swift", "-"], input="\n".join(sources), text=True).returncode)

"""Compile production login/observer code against deterministic in-memory SDK doubles.
No network, Firebase configuration, credentials or production writes are used.
"""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
app = root / 'SportiliApp'
login = (app / 'LoginView.swift').read_text().split('final class LoginSession:', 1)[1].split('#Preview', 1)[0]
sources = ['import Foundation\nimport Combine', (root/'Tests/FirebaseDoubles.swift').read_text()]
sources += [(app/'Model'/name).read_text().replace('import Firebase\n', '') for name in
            ['Esercizio.swift', 'GruppoMuscolare.swift', 'Giorno.swift', 'Scheda.swift', 'SchedaViewModel.swift']]
sources += ['final class LoginSession:' + login, (root/'Tests/FirebaseLifecycleTests.swift').read_text()]
raise SystemExit(subprocess.run(['xcrun', 'swift', '-'], input='\n'.join(sources), text=True).returncode)

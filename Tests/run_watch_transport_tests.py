"""Exercise real companion transport against local WCSession boundary doubles."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
transport = (root / 'CompanionShared/CompanionTransport.swift').read_text().replace('import WatchConnectivity', '')
sources = [
    (root / 'CompanionShared/WatchProtocol.swift').read_text(),
    (root / 'Tests/WatchConnectivityDoubles.swift').read_text(),
    transport,
    (root / 'Tests/WatchTransportTests.swift').read_text(),
]
raise SystemExit(subprocess.run(['xcrun', 'swift', '-'], input='\n'.join(sources), text=True).returncode)

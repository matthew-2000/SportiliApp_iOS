"""Execute production Foundation companion state machines without Firebase or devices."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
sources = [root / 'CompanionShared/WatchProtocol.swift', root / 'CompanionShared/PhoneLedger.swift', root / 'CompanionShared/WatchRestDuration.swift', root / 'Tests/WatchSyncTests.swift']
raise SystemExit(subprocess.run(['xcrun', 'swift', '-'], input='\n'.join(p.read_text() for p in sources), text=True).returncode)

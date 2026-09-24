"""Exercise actual note actions and ExerciseDetailViewModel with in-memory SDK doubles."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
app = root / 'SportiliApp'
view = (app/'User/EsercizioView.swift').read_text()
actions = view.split('    private func saveNote(', 1)[1].split('    private func syncNote(', 1)[0]
actions = ('    func saveNote(' + actions).replace('private func ', 'func ')
# The harness is a reference type; make the value-type View's implicit capture explicit.
actions = actions.replace('{ result in', '{ [self] result in')
fixture = '''
enum Color { case green, orange }
final class NoteActions {
    let viewModel: ExerciseDetailViewModel
    var noteInput = ""
    var lastSyncedNote = ""
    var lastSyncedNoteKey = ""
    var error: String?
    var toast: String?
    init(_ model: ExerciseDetailViewModel) { viewModel = model }
    func showError(_ message: String) { error = message }
    func showToast(message: String, color: Color = .green) { toast = message }
'''
sources = ['import Foundation\nimport Combine', (root/'Tests/FirebaseDoubles.swift').read_text(),
           (app/'Model/Esercizio.swift').read_text(),
           (app/'Model/ExerciseDetailViewModel.swift').read_text().replace('import FirebaseDatabase', ''),
           fixture + actions + '\n}', (root/'Tests/NoteTests.swift').read_text()]
raise SystemExit(subprocess.run(['xcrun', 'swift', '-'], input='\n'.join(sources), text=True).returncode)

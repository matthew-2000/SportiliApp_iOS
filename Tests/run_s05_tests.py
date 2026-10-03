"""Compile real S05 handlers with SDK boundary doubles, no Firebase service."""
from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[1]
view=(root/'SportiliApp/User/EsercizioView.swift').read_text()
helpers=view.split('// Feature-local callbacks; production delegates to the existing model.\n',1)[1].split('// MARK: - Main View',1)[0]
handlers=view.split('    private func handleWeightConfirm()',1)[1].split('    private func handleDeletion',1)[0]
handlers=('    func handleWeightConfirm()'+handlers).replace('{ result in','{ [self] result in')
mode=view.split('enum WeightDialogMode:',1)[1].split('private struct WeightDeletionContext',1)[0]
uniform=view.split('struct UniformLog:',1)[1].split('enum WeightDialogMode',1)[0]
samples=view.split('    private var samples:',1)[1].split('    private var summary:',1)[0]
fixture="""
enum Color { case green }
final class WeightActions {
    var actions: ExerciseDetailActions
    var weightInput = ""
    var weightError: String?
    var dialogExerciseKey = "lite"
    var isWeightSaving = false
    var weightDialogMode: WeightDialogMode = .create
    var toast: String?
    init(_ actions: ExerciseDetailActions) { self.actions = actions }
    func showToast(message: String, color: Color = .green) { toast = message }
    func dismissWeightSheet() { if !isWeightSaving { weightDialogMode = .hidden; weightInput = "" } }
"""
sources=['import Foundation\nimport Combine',(root/'Tests/FirebaseDoubles.swift').read_text(),
 (root/'SportiliApp/Model/Esercizio.swift').read_text(),
 (root/'SportiliApp/Model/ExerciseDetailViewModel.swift').read_text().replace('import FirebaseDatabase',''),
 'enum WeightDialogMode:'+mode, 'struct UniformLog:'+uniform,helpers,
 'struct SampleCard { let data: [UniformLog]; var samples:'+samples+'}',
 fixture+handlers+'}',
 'enum TimerParsing { private static let fallbackDuration = 60; private struct ParseResult { let seconds: Int; let usedFallback: Bool };'+view.split('    static func parseRiposo(',1)[1].split('    func playSound()',1)[0].join(['    static func parseRiposo(', '}']),(root/'Tests/S05Tests.swift').read_text()]
raise SystemExit(subprocess.run(['xcrun','swift','-'],input='\n'.join(sources),text=True).returncode)

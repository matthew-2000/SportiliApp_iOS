//
//  LoginView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 03/06/24.
//

import SwiftUI
import FirebaseAuth
import FirebaseDatabase

struct LoginView: View {
    
    @State private var code: String = ""
    @StateObject private var login = LoginSession.firebase()
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var inlineError: String?
    
    var body: some View {
        VStack {
            Spacer()
            VStack {
                Image("icon")
                    .resizable()
                    .frame(width: 200, height: 200)
                Text("SportiliApp")
                    .montserrat(size: 30)
                    .bold()
            }
            Spacer()
            
            VStack {
                TextField("Codice", text: $code)
                    .textFieldStyle(.roundedBorder)
                    .montserrat(size: 20)
                    .fontWeight(.semibold)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit {
                        attemptLogin()
                    }
                    .onChange(of: code) { _ in
                        inlineError = nil
                    }

                if let inlineError = inlineError ?? login.errorMessage {
                    Text(inlineError)
                        .montserrat(size: 14)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Text("Inserisci il codice fornito dal tuo personal trainer.")
                    .montserrat(size: 13)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 24)
                
                if login.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .accent))
                        .padding()
                } else {
                    Button(action: attemptLogin, label: {
                        Text("Entra")
                            .frame(maxWidth: .infinity)
                    })
                    .alert(isPresented: $showAlert) {
                        Alert(title: Text("Attenzione"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                    }
                    .montserrat(size: 20)
                    .bold()
                    .buttonStyle(BorderedProminentButtonStyle())
                    .controlSize(.large)
                }
                
                Button("Non hai il codice?", action: {
                    self.alertMessage = "Per accedere è necessario avere un codice fornito dal personal trainer. Ti preghiamo di contattarlo per assistenza."
                    self.showAlert.toggle()
                })
                .alert(isPresented: $showAlert) {
                    Alert(title: Text("Attenzione!"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                }
                .montserrat(size: 15)
                
            }
            .padding()
            
            Spacer()
        }
        .padding()
        .onDisappear { login.cancel() }
        .fullScreenCover(isPresented: $login.isLoggedIn) {
            ContentView()
        }
    }
    
    private func attemptLogin() {
        inlineError = nil
        code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        login.start(code: code)
    }
}

// Kept independent of Firebase so failures, retries and late callbacks can be tested.
final class LoginSession: ObservableObject {
    typealias Read = (String, @escaping (Result<Any?, Error>) -> Void) -> (() -> Void)
    typealias SignIn = (String?, @escaping (Error?) -> Void) -> Void
    @Published var isLoading = false
    @Published var isLoggedIn = false
    @Published var errorMessage: String?
    private let read: Read
    private let signIn: SignIn
    private let save: (String, Bool) -> Void
    private var generation = UUID()
    private var cancelRead: (() -> Void)?
    private var timeout: DispatchWorkItem?

    init(read: @escaping Read, signIn: @escaping SignIn, save: @escaping (String, Bool) -> Void) {
        self.read = read
        self.signIn = signIn
        self.save = save
    }

    static func validUserCode(_ code: String) -> Bool {
        !code.isEmpty && code.utf8.count <= 768 && !code.unicodeScalars.contains {
            CharacterSet(charactersIn: ".#$[]/").contains($0) || $0.value < 32 || $0.value == 127
        }
    }

    func cancel() {
        generation = UUID()
        cancelRead?()
        cancelRead = nil
        timeout?.cancel()
        timeout = nil
        isLoading = false
    }

    deinit { cancelRead?(); timeout?.cancel() }

    func start(code: String, timeoutInterval: TimeInterval = 20) {
        guard !isLoading else { return }
        cancel()
        errorMessage = nil
        guard !code.isEmpty else { errorMessage = "Inserisci il codice."; return }
        isLoading = true
        let token = generation
        let deadline = DispatchWorkItem { [weak self] in
            guard let self, self.generation == token else { return }
            self.fail("Connessione non disponibile. Riprova.")
        }
        timeout = deadline
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutInterval, execute: deadline)
        cancelRead = read("fausto") { [weak self] result in
            guard let self, self.generation == token else { return }
            self.cancelRead?(); self.cancelRead = nil
            switch result {
            case .failure: self.fail("Errore durante l'accesso. Riprova.")
            case .success(let value):
                if let adminCode = value as? String, adminCode == code {
                    self.authenticate(code: code, admin: true, name: nil, token: token)
                } else if !Self.validUserCode(code) {
                    self.fail("Codice non valido.")
                } else {
                    self.cancelRead = self.read("users/" + code) { [weak self] result in
                        guard let self, self.generation == token else { return }
                        self.cancelRead?(); self.cancelRead = nil
                        switch result {
                        case .failure: self.fail("Errore durante il recupero del profilo. Riprova.")
                        case .success(let value):
                            guard let profile = value as? [String: Any] else {
                                self.fail("Codice non autorizzato."); return
                            }
                            self.authenticate(code: code, admin: false, name: profile["nome"] as? String, token: token)
                        }
                    }
                }
            }
        }
    }

    private func fail(_ message: String) { cancel(); errorMessage = message }

    private func authenticate(code: String, admin: Bool, name: String?, token: UUID) {
        signIn(name) { [weak self] error in
            guard let self, self.generation == token else { return }
            guard error == nil else { self.fail("Errore durante l'accesso. Riprova."); return }
            self.save(code, admin)
            self.cancel()
            self.isLoggedIn = true
        }
    }
}

extension LoginSession {
    static func firebase() -> LoginSession {
        LoginSession(read: { path, completion in
            let ref = Database.database().reference().child(path)
            var finished = false
            let handle = ref.observe(.value, with: { snapshot in
                guard !finished else { return }
                finished = true
                completion(.success(snapshot.value))
            }, withCancel: { error in
                guard !finished else { return }
                finished = true
                completion(.failure(error))
            })
            return { finished = true; ref.removeObserver(withHandle: handle) }
        }, signIn: { name, completion in
            Auth.auth().signInAnonymously { result, error in
                if error == nil, let name {
                    let change = result?.user.createProfileChangeRequest()
                    change?.displayName = name
                    change?.commitChanges(completion: nil)
                }
                completion(error)
            }
        }, save: { code, admin in
            UserDefaults.standard.set(admin, forKey: "isAdmin")
            UserDefaults.standard.set(code, forKey: "code")
        })
    }
}

#Preview { LoginView() }

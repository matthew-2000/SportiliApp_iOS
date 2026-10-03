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
    @StateObject private var login: LoginSession
    @State private var showCodeHelp = false
    @State private var inlineError: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var isCodeFocused: Bool
    private let initiallyFocused: Bool

    init(login: LoginSession = .firebase(), initiallyFocused: Bool = false, initialCode: String = "") {
        _code = State(initialValue: initialCode)
        _login = StateObject(wrappedValue: login)
        self.initiallyFocused = initiallyFocused
    }
    
    var body: some View {
        ZStack {
            SportiliPalette.background
                .ignoresSafeArea()

            GeometryReader { geometry in
                let compact = isCodeFocused || geometry.size.height < 600 || dynamicTypeSize.isAccessibilitySize
                ScrollView {
                    VStack(spacing: compact ? SportiliSpacing.standard : SportiliSpacing.section) {
                        brand(compact: compact)
                        loginForm
                    }
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, SportiliSpacing.section)
                    .padding(.vertical, compact ? SportiliSpacing.standard : SportiliSpacing.large)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .alert("Come ottenere il codice", isPresented: $showCodeHelp) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Per accedere serve il codice fornito dal trainer. Contattalo se non lo hai o non funziona.")
        }
        .onAppear {
            guard initiallyFocused else { return }
            DispatchQueue.main.async { isCodeFocused = true }
        }
        .onDisappear { login.cancel() }
        .fullScreenCover(isPresented: $login.isLoggedIn) {
            ContentView()
        }
    }

    private func brand(compact: Bool) -> some View {
        VStack(spacing: SportiliSpacing.compact) {
            if compact {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: SportiliSpacing.small) {
                        brandIcon(size: 48)
                        Text("SportiliApp")
                            .font(SportiliTypography.headline)
                            .fixedSize(horizontal: true, vertical: true)
                    }
                    VStack(spacing: SportiliSpacing.compact) {
                        brandIcon(size: 48)
                        Text("SportiliApp")
                            .font(SportiliTypography.headline)
                            .multilineTextAlignment(.center)
                    }
                }
            } else {
                brandIcon(size: 88)
                Text("SportiliApp")
                    .font(SportiliTypography.headline)
                Text("Il tuo allenamento, sempre con te.")
                    .font(SportiliTypography.bodySmall)
                    .foregroundStyle(SportiliPalette.onSurfaceMuted)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func brandIcon(size: CGFloat) -> some View {
        Image("icon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var loginForm: some View {
        VStack(spacing: SportiliSpacing.standard) {
            VStack(alignment: .leading, spacing: SportiliSpacing.compact) {
                Text("Codice di accesso")
                    .font(SportiliTypography.label)

                TextField("Inserisci il codice", text: $code)
                    .font(SportiliTypography.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .focused($isCodeFocused)
                    .padding(.horizontal, SportiliSpacing.standard)
                    .padding(.vertical, 14)
                    .background(SportiliPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: SportiliShape.control, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: SportiliShape.control, style: .continuous)
                            .stroke(
                                currentError == nil ? SportiliPalette.outline : SportiliPalette.onCriticalContainer,
                                lineWidth: currentError == nil ? 1 : 2
                            )
                    }
                    .accessibilityLabel("Codice di accesso")
                    .accessibilityHint("Inserisci il codice fornito dal trainer")
                    .onSubmit(attemptLogin)
                    .onChange(of: code) { _ in inlineError = nil }

                if let currentError {
                    Label(currentError, systemImage: "exclamationmark.circle.fill")
                        .font(SportiliTypography.bodySmall)
                        .foregroundStyle(SportiliPalette.onCriticalContainer)
                        .accessibilityLabel("Errore: \(currentError)")
                }

                Text("Inserisci il codice fornito dal trainer.")
                    .font(SportiliTypography.bodySmall)
                    .foregroundStyle(SportiliPalette.onSurfaceMuted)
            }

            VStack(spacing: SportiliSpacing.small) {
                Button(action: attemptLogin) {
                    ZStack {
                        Text("Accedi")
                            .opacity(login.isLoading ? 0 : 1)

                        if login.isLoading {
                            ProgressView()
                                .tint(SportiliPalette.onPrimary)
                        }
                    }
                }
                .buttonStyle(SportiliPrimaryButtonStyle())
                .disabled(login.isLoading)
                .accessibilityLabel(login.isLoading ? "Accesso in corso" : "Accedi")

                Button("Non hai il codice?") {
                    showCodeHelp = true
                }
                .font(SportiliTypography.label)
                .foregroundStyle(SportiliPalette.primary)
                .frame(minHeight: 44)
            }
        }
    }

    private var currentError: String? {
        inlineError ?? login.errorMessage
    }
    
    private func attemptLogin() {
        code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            inlineError = "Inserisci il codice."
            isCodeFocused = true
            return
        }
        inlineError = nil
        isCodeFocused = false
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

private extension LoginSession {
    static func preview(errorMessage: String? = nil) -> LoginSession {
        let session = LoginSession(
            read: { _, _ in { } },
            signIn: { _, completion in completion(nil) },
            save: { _, _ in }
        )
        session.errorMessage = errorMessage
        return session
    }
}

#Preview("Light") {
    LoginView(login: .preview())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    LoginView(login: .preview())
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type") {
    LoginView(login: .preview(errorMessage: "Codice non autorizzato."))
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Keyboard") {
    LoginView(login: .preview(), initiallyFocused: true)
}

import SwiftUI

struct WelcomeView: View {
    @Bindable var appModel: AppModel
    @State private var accountMode: WelcomeAccountMode?

    var body: some View {
        ZStack {
            WeektableTheme.canvas
                .ignoresSafeArea()

            Image("cove-welcome-kitchen")
                .resizable()
                .scaledToFill()
                .offset(y: -55)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            Color.white.opacity(0.04)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 82)

                VStack(spacing: 12) {
                    CoveBrandMark()
                        .scaleEffect(1.72)
                        .padding(.bottom, 14)

                    Text("Your week of food,\nfigured out.")
                        .font(.system(size: 23, weight: .regular, design: .rounded))
                        .foregroundStyle(WeektableTheme.ink)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .accessibilityAddTraits(.isHeader)
                }

                Spacer()

                VStack(spacing: 14) {
                    Button("Create account") { accountMode = .create }
                        .buttonStyle(PrimaryButtonStyle())

                    Button("Sign in") { accountMode = .signIn }
                        .buttonStyle(WelcomeSecondaryButtonStyle())

                    Button("Continue as guest") { appModel.completeWelcome() }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(WeektableTheme.ink)
                        .frame(minHeight: 44)
                }
                .padding(.horizontal, 32)

                HStack(spacing: 18) {
                    Circle().fill(WeektableTheme.brand).frame(width: 10, height: 10)
                    Circle().fill(WeektableTheme.ink.opacity(0.14)).frame(width: 10, height: 10)
                    Circle().fill(WeektableTheme.ink.opacity(0.14)).frame(width: 10, height: 10)
                }
                .padding(.top, 54)
                .padding(.bottom, 22)
                .accessibilityHidden(true)
            }
        }
        .sheet(item: $accountMode) { mode in
            WelcomeAccountSheet(appModel: appModel, mode: mode)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
                .presentationBackground(WeektableTheme.canvas)
        }
    }
}

private enum WelcomeAccountMode: String, Identifiable {
    case create
    case signIn

    var id: String { rawValue }
    var title: String { self == .create ? "Create your Cove account" : "Welcome back" }
    var actionTitle: String { self == .create ? "Create account" : "Sign in" }
}

private struct WelcomeAccountSheet: View {
    @Bindable var appModel: AppModel
    let mode: WelcomeAccountMode
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                if mode == .create {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .coveTextField()
                }
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .coveTextField()
                SecureField("Password", text: $password)
                    .textContentType(mode == .create ? .newPassword : .password)
                    .coveTextField()

                Text("Your planning data remains available on this device.")
                    .font(.caption)
                    .foregroundStyle(WeektableTheme.secondaryInk)

                Button(mode.actionTitle) {
                    dismiss()
                    appModel.completeWelcome()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(email.isEmpty || password.isEmpty || (mode == .create && name.isEmpty))
            }
            .padding(WeektableTheme.pagePadding)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(WeektableTheme.canvas)
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct WelcomeSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(WeektableTheme.ink)
            .background(Color.white.opacity(configuration.isPressed ? 0.72 : 0.9))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private extension View {
    func coveTextField() -> some View {
        padding(.horizontal, 16)
            .frame(minHeight: 54)
            .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: WeektableTheme.controlRadius, style: .continuous)
                    .stroke(WeektableTheme.divider, lineWidth: 1)
            }
    }
}

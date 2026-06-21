import SwiftUI
import SwiftData

/// Etapa de Palabras (flujo único del MVP): el niño ve la imagen y la palabra,
/// escucha el modelo/TTS y habla; el STT base on-device + `PhonemeWordEvaluator`
/// dan coincidencia aproximada con regla por fonema y feedback positivo.
///
/// Layout (Fase 3): el contenido se monta dentro de un `ScrollView` cuyo alto
/// mínimo es el del viewport. Así llena toda la pantalla cuando cabe y permite
/// scroll vertical cuando no (pantallas chicas, texto grande o panel de feedback).
///
/// Visual (Fase 3B): fondo amigable, color por fonema/grupo (`VoziTheme`), botón
/// circular de Hablar con pulso al grabar, Escuchar tonal y feedback animado.
/// Las animaciones respetan `accessibilityReduceMotion`.
struct SpeakingExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let stageProgress: StageProgress
    @State private var vm: SpeakingExerciseViewModel

    init(content: StageContent, phoneme: Phoneme, stageProgress: StageProgress) {
        self.stageProgress = stageProgress
        _vm = State(initialValue: SpeakingExerciseViewModel(
            content: content,
            phoneme: phoneme,
            profile: stageProgress.phonemeProgress?.child
        ))
    }

    private var color: Color { VoziTheme.color(for: vm.phoneme) }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                Group {
                    if vm.finished {
                        completionView
                    } else {
                        exerciseView(viewport: proxy.size)
                    }
                }
                // Llena la pantalla cuando el contenido cabe; si no, deja crecer y scrollear.
                .frame(minHeight: proxy.size.height)
                .frame(maxWidth: .infinity)
            }
            // Solo rebota/scrollea cuando el contenido realmente excede el viewport.
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(VoziTheme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(vm.isRecording)
        .onDisappear { vm.stopAll() }
    }

    // MARK: - Ejercicio

    private func exerciseView(viewport: CGSize) -> some View {
        // Imagen responsiva: ~30% del alto disponible, acotada para no deformar
        // ni colapsar en pantallas muy chicas o muy grandes.
        let imageHeight = min(max(viewport.height * 0.30, 160), 300)

        return VStack(spacing: 20) {
            counterPill

            VStack(spacing: 20) {
                WordImageView(imageKey: vm.item.imageKey, height: imageHeight, tint: color)

                Text(vm.item.text)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)

                Button { vm.playModel() } label: {
                    Label("Escuchar", systemImage: "speaker.wave.2.fill")
                }
                .buttonStyle(VoziTonalButtonStyle(tint: color))
                .disabled(vm.isRecording)
            }
            .id(vm.index)
            .transition(.opacity)

            // Espacio flexible: empuja la zona de acción hacia abajo cuando sobra
            // pantalla, y se colapsa a 24 cuando el contenido necesita scroll.
            Spacer(minLength: 24)

            Group {
                if vm.showResult {
                    feedbackPanel
                } else {
                    micButton
                }
            }
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.vertical, 24)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.78), value: vm.showResult)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: vm.index)
    }

    private var counterPill: some View {
        Text("\(vm.index + 1) de \(vm.totalItems)")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
            .background(color.opacity(0.14), in: Capsule())
    }

    // MARK: - Botón Hablar (circular, con pulso al grabar)

    private var micButton: some View {
        VStack(spacing: 14) {
            ZStack {
                if vm.isRecording && !reduceMotion {
                    RecordingPulse(color: .red)
                }
                Button { vm.micTapped(context: context) } label: {
                    Image(systemName: vm.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 116, height: 116)
                        .background(
                            Circle().fill(vm.isRecording ? Color.red : color)
                        )
                        .shadow(color: (vm.isRecording ? Color.red : color).opacity(0.45),
                                radius: 14, x: 0, y: 8)
                }
                .buttonStyle(VoziPressableStyle())
                .accessibilityLabel(vm.isRecording ? "Detener" : "Hablar")
            }
            .frame(height: 130)

            Text(vm.isRecording ? "Te escucho…" : "Toca y dilo en voz alta")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Feedback

    private var feedbackPanel: some View {
        // Dos estados: aprobado y "casi". Sin números ni lenguaje clínico para el niño.
        let success = vm.passed
        let title: String = {
            if success { return "¡Muy bien!" }
            if vm.lastPhonemeMissed { return "Casi, intentemos escuchar bien ese sonido." }
            return "¡Casi! Sigue practicando"
        }()

        return VStack(spacing: 16) {
            FeedbackIcon(success: success, reduceMotion: reduceMotion)

            Text(title)
                .font(.system(.title2, design: .rounded).bold())
                .foregroundStyle(success ? VoziTheme.success : VoziTheme.almost)
                .multilineTextAlignment(.center)

            if !success {
                Button { vm.playModel() } label: {
                    Label("Escuchar pista", systemImage: "speaker.wave.2.fill")
                }
                .buttonStyle(VoziTonalButtonStyle(tint: color))
            }

            HStack(spacing: 12) {
                Button { vm.retry() } label: {
                    Label("Otra vez", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(VoziBigButtonStyle(fill: VoziTheme.almost))

                Button { vm.advance() } label: {
                    Label(vm.isLastItem ? "Terminar" : "Siguiente",
                          systemImage: vm.isLastItem ? "checkmark" : "chevron.right")
                        .frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(VoziBigButtonStyle(fill: success ? VoziTheme.success : color))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .voziCard(cornerRadius: 24, fill: Color(.systemBackground))
    }

    // MARK: - Completado (celebración)

    private var completionView: some View {
        // La recompensa (puntos + completación) requiere ≥90% de aciertos. Si no se
        // alcanza, se permite salir con un mensaje amable, sin sumar nada.
        let earned = vm.rewardEarned

        return VStack(spacing: 20) {
            Spacer(minLength: 24)

            FeedbackIcon(success: earned, reduceMotion: reduceMotion, size: 84)

            Text(earned ? "¡Práctica completada!" : "¡Buen intento!")
                .font(.system(.largeTitle, design: .rounded).bold())
                .multilineTextAlignment(.center)

            Text(earned
                 ? "¡Ganaste \(ProgressService.pointsPerCompletion) puntos! Acertaste \(vm.passedCount) de \(vm.totalItems)."
                 : "Buen intento, practiquemos un poco más para ganar la recompensa.")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 24)

            Button {
                ProgressService.completeStage(stageProgress, rewarded: earned, in: context)
                dismiss()
            } label: {
                Text("¡Listo!")
            }
            .buttonStyle(VoziBigButtonStyle(fill: earned ? VoziTheme.success : color))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.vertical, 24)
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Subvistas animadas

/// Anillos que laten alrededor del botón mientras se graba. Solo se monta cuando
/// `accessibilityReduceMotion` está apagado.
private struct RecordingPulse: View {
    var color: Color
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { i in
                Circle()
                    .stroke(color.opacity(0.5), lineWidth: 5)
                    .frame(width: 116, height: 116)
                    .scaleEffect(animate ? 1.7 : 1)
                    .opacity(animate ? 0 : 0.6)
                    .animation(
                        .easeOut(duration: 1.4).repeatForever(autoreverses: false).delay(Double(i) * 0.7),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

/// Icono de feedback con entrada en *spring* y chispas en el acierto.
private struct FeedbackIcon: View {
    var success: Bool
    var reduceMotion: Bool
    var size: CGFloat = 60

    @State private var appeared = false

    var body: some View {
        ZStack {
            if success && !reduceMotion {
                ForEach(0..<5, id: \.self) { i in
                    Image(systemName: "sparkle")
                        .font(.system(size: size * 0.28))
                        .foregroundStyle(VoziTheme.sunshine)
                        .offset(sparkleOffset(i))
                        .scaleEffect(appeared ? 1 : 0.1)
                        .opacity(appeared ? 1 : 0)
                }
            }

            Image(systemName: success ? "star.circle.fill" : "hand.thumbsup.circle.fill")
                .font(.system(size: size))
                .foregroundStyle(success ? VoziTheme.success : VoziTheme.almost)
                .scaleEffect(appeared ? 1 : 0.4)
                .rotationEffect(.degrees(appeared || success ? 0 : -8))
        }
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { appeared = true }
            }
        }
    }

    /// Posiciones de las chispas en abanico alrededor del icono.
    private func sparkleOffset(_ i: Int) -> CGSize {
        let angles: [Double] = [-90, -45, 0, 45, 90]
        let radius = size * 0.85
        let a = angles[i % angles.count] * .pi / 180
        return CGSize(width: cos(a) * radius, height: sin(a) * radius - radius * 0.2)
    }
}

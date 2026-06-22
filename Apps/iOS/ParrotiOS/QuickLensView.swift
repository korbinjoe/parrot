import ParrotSocial
import SwiftUI
import UIKit

struct QuickLensView: View {
    @EnvironmentObject private var state: IOSAppState
    @State private var cropMode = false
    @State private var cropStart: CGPoint?
    @State private var cropCurrent: CGPoint?
    @State private var cropRect: CGRectCodable?

    var body: some View {
        VStack(spacing: 0) {
            AppHeader(leadingTitle: "Close", leadingAction: {
                state.selectedTab = .today
                state.isQuickLensPresented = false
            }, title: "Quick Lens") {
                MiniIconButton(systemName: "arrow.clockwise") {
                    Task { await state.retryQuickLensOCR() }
                }
                .accessibilityLabel("Retry OCR")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    statusHeader
                    screenshotArea
                    sourceEditor
                    if state.quickLensStatus.isRecoverableFailure {
                        recoveryActions
                    }
                    resultArea
                    actionRow
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 78)
            }
            .scrollIndicators(.hidden)
        }
        .background(IOSTheme.paper.ignoresSafeArea())
        .accessibilityIdentifier("QuickLensView")
    }

    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                StatusPill(text: "Latest screenshot")
                StatusPill(text: state.quickLensStatus.title, tone: state.quickLensStatus == .ready ? .good : .blue)
                Spacer()
            }
            if let notice = state.quickLensNotice {
                Text(notice)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(IOSTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else if state.quickLensStatus == .ready {
                Text("Tap a highlighted block if Parrot picked the wrong text.")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(IOSTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var screenshotArea: some View {
        if let image = state.activeQuickLensImage() {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    GeometryReader { proxy in
                        let imageSize = state.activeSession?.quickLens?.imagePixelSize.cgSize ?? image.size
                        let fitRect = aspectFitRect(imageSize: imageSize, containerSize: proxy.size)

                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()

                        ForEach(Array((state.activeSession?.quickLens?.candidates ?? []).enumerated()), id: \.element.id) { index, candidate in
                            let rect = displayRect(candidate.boundingBox.cgRect, in: fitRect)
                            Button {
                                Task { await state.selectQuickLensCandidate(candidate.id) }
                            } label: {
                                CandidateBlockOverlay(
                                    index: index,
                                    selected: state.activeSession?.quickLens?.selectedCandidateID == candidate.id,
                                    isNoise: candidate.isNoise
                                )
                            }
                            .buttonStyle(.plain)
                            .frame(width: max(rect.width, 28), height: max(rect.height, 24))
                            .position(x: rect.midX, y: rect.midY)
                            .accessibilityLabel("Text block \(index + 1)")
                            .accessibilityIdentifier("QuickLensCandidate\(index)")
                        }

                        if cropMode {
                            cropOverlay(in: proxy.size, fitRect: fitRect)
                        }
                    }
                }
                .frame(height: min(UIScreen.main.bounds.height * 0.30, 260))
                .background(IOSTheme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous).stroke(IOSTheme.line))

                if cropMode {
                    HStack {
                        Button("Cancel crop") {
                            cropMode = false
                            cropStart = nil
                            cropCurrent = nil
                            cropRect = nil
                        }
                        .buttonStyle(.compactMuted)

                        Button("Use crop") {
                            if let cropRect {
                                Task {
                                    await state.applyQuickLensCrop(cropRect)
                                    cropMode = false
                                }
                            }
                        }
                        .buttonStyle(.compactBlue)
                        .disabled(cropRect == nil)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(IOSTheme.cyan)
                Text("No screenshot loaded")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                Text("Take a screenshot, then run Quick Lens again.")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(IOSTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .parrotCard()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("No recent screenshot")
            .accessibilityIdentifier("QuickLensNoRecent")
        }
    }

    private var sourceEditor: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Recognized source")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(IOSTheme.muted)
                    .textCase(.uppercase)
                Spacer()
                MiniIconButton(systemName: "doc.on.doc") {
                    state.copySourceDraft()
                }
                .accessibilityLabel("Copy selected text")
                .accessibilityIdentifier("QuickLensCopySource")
                .disabled((state.activeSession?.sourceDraft.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty)
            }
            TextEditor(text: Binding(
                get: { state.activeSession?.sourceDraft ?? "" },
                set: { state.updateSourceDraft($0) }
            ))
            .accessibilityIdentifier("QuickLensSourceEditor")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .frame(minHeight: 68)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(IOSTheme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))

            FlowLayout(spacing: 6) {
                ForEach(OCRCleanupAction.allCases, id: \.title) { action in
                    Button(action.shortTitle) {
                        state.applyOCRCleanup(action)
                    }
                    .buttonStyle(.compactBlue)
                }
            }

            Button {
                Task { await state.understandActiveSession() }
            } label: {
                Text("Rerun translation")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.compactGreen)
        }
        .padding(9)
        .parrotCard()
    }

    private var resultArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            if state.quickLensStatus == .recognizingText || state.quickLensStatus == .loadingScreenshot || state.quickLensStatus == .requestingPhotoPermission {
                ProgressView(state.quickLensStatus.title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            } else if state.quickLensStatus == .translating || state.isProcessing {
                ProgressView("Explaining selected text")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }

            if let error = state.errorNotice {
                Text(error)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)
            }

            if let result = state.activeSession?.understand {
                if let translation = visibleTranslation(result) {
                    HStack {
                        Text("Translation")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(IOSTheme.greenDeep)
                        Spacer()
                        MiniIconButton(systemName: "doc.on.doc") {
                            state.copy(translation)
                        }
                        .accessibilityLabel("Copy translation")
                        .accessibilityIdentifier("QuickLensCopyTranslation")
                    }
                    Text(translation)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(IOSTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("QuickLensTranslation")
                }
                Text("Meaning")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(IOSTheme.greenDeep)
                Text(result.meaningSummary)
                    .font(.system(size: visibleTranslation(result) == nil ? 13 : 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(IOSTheme.ink)
                    .accessibilityIdentifier("QuickLensMeaning")
                if let note = result.confidenceNote {
                    Text(note)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(IOSTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                FlowLayout(spacing: 7) {
                    ForEach(result.toneTags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(IOSTheme.subtleFill)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(
            LinearGradient(colors: [IOSTheme.meaningTint, IOSTheme.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: IOSTheme.cardRadius, style: .continuous).stroke(IOSTheme.line))
    }

    private func visibleTranslation(_ result: UnderstandResult) -> String? {
        let translation = result.fullTranslation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !translation.isEmpty else { return nil }
        let source = state.activeSession?.sourceDraft.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return translation == source ? nil : translation
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                state.openManualExpress()
                state.isQuickLensPresented = false
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.compactGreen)

            Button {
                state.editQuickLensSource()
            } label: {
                Label("Edit", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.compactBlue)

            Button {
                cropMode.toggle()
                state.openQuickLensManualCrop()
            } label: {
                Image(systemName: "crop")
            }
            .buttonStyle(.compactMuted)
            .accessibilityLabel("Crop")

            MiniIconButton(systemName: "doc.on.doc") {
                if let summary = state.activeSession?.understand?.meaningSummary {
                    state.copy(summary)
                }
            }
            .accessibilityLabel("Copy meaning")
        }
    }

    private var recoveryActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Task { await state.openQuickLensFromLatestScreenshot() }
            } label: {
                Label("Try latest screenshot again", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.compactGreen)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Open Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.compactBlue)

            Button {
                state.activeSession = SocialTextSession(origin: .manualInput, sourceDraft: "")
                state.selectedTab = .work
                state.isQuickLensPresented = false
            } label: {
                Label("Enter text manually", systemImage: "keyboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.compactMuted)
        }
    }

    private func cropOverlay(in size: CGSize, fitRect: CGRect) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.001))
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        cropStart = cropStart ?? value.startLocation
                        cropCurrent = value.location
                        if let cropStart, let cropCurrent {
                            cropRect = normalizedRect(from: cropStart, to: cropCurrent, fitRect: fitRect)
                        }
                    }
                    .onEnded { value in
                        cropCurrent = value.location
                        if let cropStart, let cropCurrent {
                            cropRect = normalizedRect(from: cropStart, to: cropCurrent, fitRect: fitRect)
                        }
                    }
            )
            .overlay {
                if let cropRect {
                    let rect = displayRect(cropRect.cgRect, in: fitRect)
                    Rectangle()
                        .stroke(IOSTheme.cyan, style: StrokeStyle(lineWidth: 3, dash: [7, 4]))
                        .background(IOSTheme.cyan.opacity(0.16))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
            .frame(width: size.width, height: size.height)
    }

    private func normalizedRect(from start: CGPoint, to end: CGPoint, fitRect: CGRect) -> CGRectCodable {
        let clampedStart = clamp(start, to: fitRect)
        let clampedEnd = clamp(end, to: fitRect)
        let minX = min(clampedStart.x, clampedEnd.x)
        let minY = min(clampedStart.y, clampedEnd.y)
        let maxX = max(clampedStart.x, clampedEnd.x)
        let maxY = max(clampedStart.y, clampedEnd.y)
        return CGRectCodable(
            x: Double((minX - fitRect.minX) / fitRect.width),
            y: Double((minY - fitRect.minY) / fitRect.height),
            width: Double((maxX - minX) / fitRect.width),
            height: Double((maxY - minY) / fitRect.height)
        ).clampedUnitRect
    }

    private func clamp(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    private func aspectFitRect(imageSize: CGSize, containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return CGRect(
            x: (containerSize.width - width) / 2,
            y: (containerSize.height - height) / 2,
            width: width,
            height: height
        )
    }

    private func displayRect(_ normalized: CGRect, in fitRect: CGRect) -> CGRect {
        CGRect(
            x: fitRect.minX + normalized.minX * fitRect.width,
            y: fitRect.minY + normalized.minY * fitRect.height,
            width: normalized.width * fitRect.width,
            height: normalized.height * fitRect.height
        )
    }
}

private struct CandidateBlockOverlay: View {
    let index: Int
    let selected: Bool
    let isNoise: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(border, lineWidth: selected ? 3 : 1.5)
                )
            Text("\(index + 1)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(border)
                .clipShape(Capsule())
                .padding(5)
        }
    }

    private var border: Color {
        if isNoise { return IOSTheme.amber }
        return selected ? IOSTheme.green : IOSTheme.cyan
    }

    private var fill: Color {
        if isNoise { return IOSTheme.amber.opacity(0.08) }
        return selected ? IOSTheme.green.opacity(0.22) : IOSTheme.cyan.opacity(0.14)
    }
}

private extension OCRCleanupAction {
    var shortTitle: String {
        switch self {
        case .removeUsernames: return "Remove @"
        case .removeTimestamps: return "Time"
        case .joinLines: return "Join lines"
        case .deleteEmptyLines: return "Trim"
        }
    }
}

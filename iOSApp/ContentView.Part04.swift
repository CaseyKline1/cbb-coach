import SwiftUI
import UniformTypeIdentifiers
import CBBCoachCore

struct RotationSettingsView: View {
    let roster: [UserRosterPlayerSummary]
    let slots: [UserRotationSlot]
    let onSave: ([UserRotationSlot]) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var editedSlots: [UserRotationSlot] = []
    @State private var isApplyingIncomingSlots: Bool = false
    @State private var statusText: String = "Set starters (1-5), then rank bench (6+). Totals can be temporary while you edit."
    @State private var showExitBalancePrompt: Bool = false
    @State private var draggedSlot: Int? = nil
    @State private var targetedDropSlot: Int? = nil
    @State private var selectedSlotForSwap: Int? = nil

    private let starterPositions = ["PG", "SG", "SF", "PF", "C"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Long-press and drag player names between rows, or tap one player then tap another to swap. Each row has its own minute target.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                rotationTable

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Total minutes: \(Int(totalMinutes.rounded()))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .navigationTitle("Rotation")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: attemptExit) {
                    Label("Back", systemImage: "chevron.backward")
                }
            }
        }
        .onAppear {
            applyIncomingSlots(slots)
        }
        .onChange(of: slots) { _, updated in
            applyIncomingSlots(updated)
        }
        .onChange(of: editedSlots) { _, updated in
            if isApplyingIncomingSlots { return }
            let sanitizedUpdated = sanitized(updated)
            if !areSlotsEqual(updated, sanitizedUpdated) {
                editedSlots = sanitizedUpdated
                return
            }
            statusText = totalIsBalanced(updated)
                ? "Minutes balanced at \(Int(targetTotal.rounded())). Back out to save."
                : "Total is \(Int(totalMinutes.rounded())) / \(Int(targetTotal.rounded())). You can fix now or let assistants fix when leaving."
        }
        .onDisappear {
            saveBalancedEditsIfNeeded()
        }
        .alert("Minutes Need To Add Up", isPresented: $showExitBalancePrompt) {
            Button("Fix Manually", role: .cancel) {
                statusText = "Adjust minutes to \(Int(targetTotal.rounded())) before leaving, or use Let Assistants Fix."
            }
            Button("Let Assistants Fix") {
                let fixed = assistantFixedSlots(editedSlots)
                editedSlots = fixed
                onSave(fixed)
                dismiss()
            }
        } message: {
            Text("Rotation minutes are currently \(Int(totalMinutes.rounded())) and need to be \(Int(targetTotal.rounded())).")
        }
    }

    private var rotationTable: some View {
        GameCard {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    AppTableTextCell(text: "SLOT", width: 88, font: .caption2.weight(.bold), foreground: .secondary)
                    AppTableTextCell(text: "PLAYER", width: 220, alignment: .leading, font: .caption2.weight(.bold), foreground: .secondary)
                    AppTableTextCell(text: "MIN", width: 120, font: .caption2.weight(.bold), foreground: .secondary)
                }
                .padding(.vertical, 6)
                .background(AppTheme.cardBackground)
                Divider()

                ForEach(Array(editedSlots.enumerated()), id: \.element.id) { index, slot in
                    HStack(spacing: 0) {
                        AppTableTextCell(
                            text: slotLabel(for: index),
                            width: 88,
                            font: .caption.monospacedDigit().weight(.semibold)
                        )

                        playerCell(for: slot)
                            .frame(width: 220, alignment: .leading)

                        RotationMinuteControl(
                            label: "",
                            value: Binding(
                                get: { editedSlots[index].minutes },
                                set: { editedSlots[index].minutes = $0 }
                            ),
                            step: 1
                        )
                        .frame(width: 120)
                    }
                    .padding(.vertical, 6)
                    .background(rowHighlightColor(for: slot.slot))
                    .contentShape(Rectangle())
                    .onDrop(of: [UTType.plainText], isTargeted: dropTargetBinding(for: slot.slot)) { _ in
                        guard let sourceSlot = draggedSlot else { return false }
                        movePlayer(fromSlot: sourceSlot, toSlot: slot.slot)
                        draggedSlot = nil
                        selectedSlotForSwap = nil
                        targetedDropSlot = nil
                        return true
                    }
                    if index < editedSlots.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private func applyIncomingSlots(_ source: [UserRotationSlot]) {
        isApplyingIncomingSlots = true
        editedSlots = sanitized(source)
        isApplyingIncomingSlots = false
    }

    private func areSlotsEqual(_ lhs: [UserRotationSlot], _ rhs: [UserRotationSlot]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for index in lhs.indices {
            let left = lhs[index]
            let right = rhs[index]
            if left.slot != right.slot { return false }
            if left.playerIndex != right.playerIndex { return false }
            if left.position != right.position { return false }
            if left.minutes != right.minutes { return false }
        }
        return true
    }

    private func sanitized(_ source: [UserRotationSlot]) -> [UserRotationSlot] {
        let targetCount = max(source.count, roster.count)
        if targetCount == 0 { return [] }

        var base = source.sorted { $0.slot < $1.slot }
        if base.count < targetCount {
            for slot in (base.count + 1)...targetCount {
                base.append(UserRotationSlot(slot: slot, playerIndex: nil, position: nil, minutes: 0))
            }
        }

        let rosterIndexes = Set(roster.map(\.playerIndex))
        var used: Set<Int> = []
        for index in base.indices {
            let candidate = base[index].playerIndex
            if let candidate, rosterIndexes.contains(candidate), !used.contains(candidate) {
                used.insert(candidate)
            } else {
                base[index].playerIndex = nil
            }
        }
        let remaining = roster.map(\.playerIndex).filter { !used.contains($0) }
        var remainingCursor = 0
        for index in base.indices {
            if base[index].playerIndex != nil { continue }
            guard remainingCursor < remaining.count else { break }
            base[index].playerIndex = remaining[remainingCursor]
            remainingCursor += 1
        }

        for index in base.indices {
            base[index].slot = index + 1
            base[index].minutes = clampMinutes(base[index].minutes)
            if index < min(5, base.count) {
                let fallback = starterPositions[min(index, starterPositions.count - 1)]
                let current = (base[index].position ?? "").uppercased()
                base[index].position = starterPositions.contains(current) ? current : fallback
            } else {
                base[index].position = nil
            }
        }

        return base
    }

    private func positionFixedStarterSlots(_ source: [UserRotationSlot]) -> [UserRotationSlot] {
        guard source.count > 1 else { return source }

        var fixed = source
        var starterPlayerIndexes = fixed.prefix(min(5, fixed.count)).compactMap(\.playerIndex)
        guard starterPlayerIndexes.count > 1 else { return fixed }

        let slotPositions = Array(starterPositions.prefix(starterPlayerIndexes.count))
        var orderedPlayerIndexes: [Int] = []
        orderedPlayerIndexes.reserveCapacity(starterPlayerIndexes.count)

        for slotPosition in slotPositions {
            guard let best = starterPlayerIndexes.max(by: { lhs, rhs in
                let left = roster.first(where: { $0.playerIndex == lhs })
                let right = roster.first(where: { $0.playerIndex == rhs })
                let leftScore = starterPositionFitScore(left?.position ?? "", slot: slotPosition)
                let rightScore = starterPositionFitScore(right?.position ?? "", slot: slotPosition)
                if leftScore != rightScore { return leftScore < rightScore }
                return (left?.overall ?? 0) < (right?.overall ?? 0)
            }) else {
                continue
            }
            orderedPlayerIndexes.append(best)
            starterPlayerIndexes.removeAll { $0 == best }
        }

        orderedPlayerIndexes.append(contentsOf: starterPlayerIndexes)
        for index in orderedPlayerIndexes.indices where index < fixed.count {
            fixed[index].playerIndex = orderedPlayerIndexes[index]
        }
        return sanitized(fixed)
    }

    private func starterPositionFitScore(_ position: String, slot: String) -> Int {
        let normalizedPosition = position.uppercased()
        let normalizedSlot = slot.uppercased()
        if normalizedPosition == normalizedSlot { return 100 }

        switch normalizedSlot {
        case "PG":
            switch normalizedPosition {
            case "CG": return 88
            case "SG": return 70
            case "WING": return 46
            default: return 10
            }
        case "SG":
            switch normalizedPosition {
            case "CG": return 90
            case "WING": return 82
            case "PG": return 76
            case "SF": return 64
            default: return 18
            }
        case "SF":
            switch normalizedPosition {
            case "WING": return 92
            case "F": return 84
            case "SG": return 70
            case "PF": return 68
            case "BIG": return 46
            default: return 20
            }
        case "PF":
            switch normalizedPosition {
            case "F": return 92
            case "BIG": return 86
            case "C": return 78
            case "SF": return 72
            case "WING": return 60
            default: return 20
            }
        case "C":
            switch normalizedPosition {
            case "BIG": return 94
            case "PF": return 84
            case "F": return 66
            case "SF": return 42
            default: return 18
            }
        default:
            return 0
        }
    }

    private func clampMinutes(_ value: Double) -> Double {
        min(40, max(0, (value * 2).rounded() / 2))
    }

    private func normalizeMinutes(_ source: [UserRotationSlot], targetTotal: Double) -> [UserRotationSlot] {
        guard !source.isEmpty else { return source }
        var normalized = source
        let currentTotal = normalized.reduce(0) { $0 + $1.minutes }
        if currentTotal <= 0 {
            let even = clampMinutes(targetTotal / Double(max(1, normalized.count)))
            for index in normalized.indices {
                normalized[index].minutes = even
            }
        } else {
            let scale = targetTotal / currentTotal
            for index in normalized.indices {
                normalized[index].minutes = clampMinutes(normalized[index].minutes * scale)
            }
        }

        // Priority order: prefer adjusting slots that already have meaningful minutes
        // when reducing, and slots with highest current minutes when adding.
        let priorityOrder = normalized.indices.sorted { normalized[$0].minutes > normalized[$1].minutes }

        var guardCount = 0
        while abs(targetTotal - normalized.reduce(0) { $0 + $1.minutes }) >= 0.25 && guardCount < 4000 {
            guardCount += 1
            let diff = targetTotal - normalized.reduce(0) { $0 + $1.minutes }
            let step = diff > 0 ? 0.5 : -0.5
            let order = diff > 0 ? priorityOrder : Array(priorityOrder.reversed())
            var adjusted = false
            for index in order {
                let candidate = normalized[index].minutes + step
                if candidate < -0.001 || candidate > 40.001 { continue }
                normalized[index].minutes = candidate
                adjusted = true
                break
            }
            if !adjusted { break }
        }

        return normalized
    }

    private func assistantFixedSlots(_ source: [UserRotationSlot]) -> [UserRotationSlot] {
        let sanitizedSource = sanitized(source)
        let positionedSource = positionFixedStarterSlots(sanitizedSource)
        return normalizeMinutes(positionedSource, targetTotal: targetTotal)
    }

    private func totalIsBalanced(_ source: [UserRotationSlot]) -> Bool {
        abs(source.reduce(0) { $0 + $1.minutes } - targetTotal) < 0.49
    }

    private func saveBalancedEditsIfNeeded() {
        let cleaned = sanitized(editedSlots)
        guard !cleaned.isEmpty, totalIsBalanced(cleaned), !areSlotsEqual(cleaned, slots) else { return }
        onSave(cleaned)
    }

    private func attemptExit() {
        let cleaned = sanitized(editedSlots)
        if !areSlotsEqual(cleaned, editedSlots) {
            editedSlots = cleaned
        }
        guard !cleaned.isEmpty else {
            onSave(cleaned)
            dismiss()
            return
        }
        if totalIsBalanced(cleaned) {
            onSave(cleaned)
            dismiss()
        } else {
            showExitBalancePrompt = true
        }
    }

    private func slotLabel(for index: Int) -> String {
        if index < 5 {
            return "\(index + 1) \(starterPositions[min(index, starterPositions.count - 1)])"
        }
        return "\(index + 1) BEN"
    }

    private func playerCell(for slot: UserRotationSlot) -> some View {
        let playerLabel: String
        if let playerIndex = slot.playerIndex, let player = roster.first(where: { $0.playerIndex == playerIndex }) {
            playerLabel = "\(player.name) (\(player.position))"
        } else {
            playerLabel = "Unassigned"
        }

        return HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(playerLabel)
                .font(.caption.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)
        }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
            .onTapGesture {
                tapToSwap(slot: slot.slot)
            }
            .onDrag {
                draggedSlot = slot.slot
                return NSItemProvider(object: "\(slot.slot)" as NSString)
            }
            .accessibilityLabel("\(playerLabel). Drag to reorder or tap to swap.")
    }

    private func movePlayer(fromSlot sourceSlot: Int, toSlot destinationSlot: Int) {
        guard sourceSlot != destinationSlot else { return }
        guard
            let sourceIndex = editedSlots.firstIndex(where: { $0.slot == sourceSlot }),
            let destinationIndex = editedSlots.firstIndex(where: { $0.slot == destinationSlot })
        else {
            return
        }

        let sourcePlayer = editedSlots[sourceIndex].playerIndex
        editedSlots[sourceIndex].playerIndex = editedSlots[destinationIndex].playerIndex
        editedSlots[destinationIndex].playerIndex = sourcePlayer
    }

    private func tapToSwap(slot: Int) {
        if let selected = selectedSlotForSwap {
            if selected == slot {
                selectedSlotForSwap = nil
                statusText = totalIsBalanced(editedSlots)
                    ? "Minutes balanced at \(Int(targetTotal.rounded())). Back out to save."
                    : "Total is \(Int(totalMinutes.rounded())) / \(Int(targetTotal.rounded())). You can fix now or let assistants fix when leaving."
                return
            }
            movePlayer(fromSlot: selected, toSlot: slot)
            selectedSlotForSwap = nil
            statusText = "Swapped slots \(selected) and \(slot)."
            return
        }

        selectedSlotForSwap = slot
        statusText = "Selected slot \(slot). Tap another player row to swap."
    }

    private func rowHighlightColor(for slot: Int) -> Color {
        if targetedDropSlot == slot {
            return AppTheme.accent.opacity(0.16)
        }
        if selectedSlotForSwap == slot {
            return AppTheme.accent.opacity(0.10)
        }
        return .clear
    }

    private func dropTargetBinding(for slot: Int) -> Binding<Bool> {
        Binding(
            get: { targetedDropSlot == slot },
            set: { isTargeted in
                targetedDropSlot = isTargeted ? slot : (targetedDropSlot == slot ? nil : targetedDropSlot)
            }
        )
    }

    private var totalMinutes: Double {
        editedSlots.reduce(0) { $0 + $1.minutes }
    }

    private var targetTotal: Double {
        min(200.0, Double(editedSlots.count * 40))
    }
}

struct RotationMinuteControl: View {
    let label: String
    @Binding var value: Double
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !label.isEmpty {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button(action: decrement) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Decrease \(label.isEmpty ? "minutes" : label)")

                Text("\(Int(value.rounded()))")
                    .font(.body.monospacedDigit().weight(.semibold))
                    .frame(width: 36)

                Button(action: increment) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Increase \(label.isEmpty ? "minutes" : label)")
            }
        }
    }

    private func decrement() {
        value = min(40, max(0, value - step))
    }

    private func increment() {
        value = min(40, max(0, value + step))
    }
}

import AppKit
import SwiftUI

enum AutomationHealth: String {
    case active = "Active"
    case approval = "Needs Approval"
    case blocked = "Blocked"
    case paused = "Paused"
}

struct AutomationItem: Identifiable {
    let id: String
    let name: String
    let kind: String
    let status: String
    let schedule: String
    let model: String
    let reasoning: String
    let cwdCount: Int
    let needsApproval: Bool
    let blocker: String?
    let lastNote: String?
    let keyChanges: [String]
    let nextChanges: [String]
    let automationPath: String
    let workingPath: String?

    var health: AutomationHealth {
        if blocker != nil { return .blocked }
        if status.uppercased() != "ACTIVE" { return .paused }
        if needsApproval { return .approval }
        return .active
    }

    var keyPoint: String {
        if let blocker { return blocker }
        if needsApproval { return "Ask before writes or service changes." }
        if let lastNote { return lastNote }
        return "No recent note."
    }
}

final class AutomationModel: ObservableObject {
    @Published private(set) var items: [AutomationItem] = []
    @Published private(set) var lastUpdated: Date?

    private let automationsRoot = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".codex/automations")

    var rootURL: URL { automationsRoot }

    var activeCount: Int {
        items.filter { $0.status.uppercased() == "ACTIVE" }.count
    }

    var approvalCount: Int {
        items.filter(\.needsApproval).count
    }

    var blockedCount: Int {
        items.filter { $0.blocker != nil }.count
    }

    var overallHealth: AutomationHealth {
        if blockedCount > 0 { return .blocked }
        if approvalCount > 0 { return .approval }
        if activeCount > 0 { return .active }
        return .paused
    }

    var headline: String {
        switch overallHealth {
        case .blocked:
            return "\(blockedCount) blocked"
        case .approval:
            return "\(approvalCount) need OK"
        case .active:
            return "\(activeCount) active"
        case .paused:
            return "No active automations"
        }
    }

    func refresh() {
        let fileManager = FileManager.default
        guard let directories = try? fileManager.contentsOfDirectory(
            at: automationsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            items = []
            lastUpdated = Date()
            return
        }

        items = directories.compactMap { directory -> AutomationItem? in
            let configURL = directory.appendingPathComponent("automation.toml")
            guard fileManager.fileExists(atPath: configURL.path),
                  let config = try? String(contentsOf: configURL, encoding: .utf8)
            else { return nil }

            let values = Self.parseConfig(config)
            let prompt = values["prompt", default: ""]
            let memory = try? String(
                contentsOf: directory.appendingPathComponent("memory.md"),
                encoding: .utf8
            )
            let memoryTail = memory.map { Self.tail($0, characterLimit: 4_000) } ?? ""
            let blocker = Self.blockerHint(from: memoryTail)
            let lastNote = Self.lastUsefulNote(from: memoryTail)
            let keyChanges = Self.keyChanges(from: memoryTail)
            let nextChanges = Self.nextChanges(from: memoryTail, blocker: blocker, lastNote: lastNote)
            let cwdPaths = Self.arrayValues(values["cwds", default: ""])

            return AutomationItem(
                id: values["id", default: directory.lastPathComponent],
                name: values["name", default: directory.lastPathComponent],
                kind: values["kind", default: "automation"],
                status: values["status", default: "UNKNOWN"],
                schedule: Self.scheduleSummary(values["rrule", default: ""]),
                model: values["model", default: "unknown"],
                reasoning: values["reasoning_effort", default: "default"],
                cwdCount: Self.arrayCount(values["cwds", default: ""]),
                needsApproval: Self.needsApproval(prompt: prompt),
                blocker: blocker,
                lastNote: lastNote,
                keyChanges: keyChanges,
                nextChanges: nextChanges,
                automationPath: directory.path,
                workingPath: cwdPaths.first
            )
        }
        .sorted { lhs, rhs in
            if lhs.health != rhs.health {
                return Self.healthSort(lhs.health) < Self.healthSort(rhs.health)
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        lastUpdated = Date()
    }

    private static func parseConfig(_ text: String) -> [String: String] {
        var values: [String: String] = [:]
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"), let equals = line.firstIndex(of: "=") else {
                continue
            }

            let key = String(line[..<equals]).trimmingCharacters(in: .whitespaces)
            var value = String(line[line.index(after: equals)...]).trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value.removeFirst()
                value.removeLast()
                value = value
                    .replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\\n", with: " ")
            }
            values[key] = value
        }
        return values
    }

    private static func needsApproval(prompt: String) -> Bool {
        let text = prompt.lowercased()
        let markers = [
            "unless explicitly asked",
            "human request",
            "approval",
            "do not modify",
            "do not delete",
            "do not install",
            "do not update",
            "do not restart",
            "do not kill",
            "do not overwrite"
        ]
        return markers.contains { text.contains($0) }
    }

    private static func blockerHint(from memoryTail: String) -> String? {
        let text = memoryTail.lowercased()
        if text.contains("permissionerror") {
            return "Permission blocked."
        }
        if text.contains("failed with") || text.contains("failed immediately") {
            return "Last run failed."
        }
        return nil
    }

    private static func lastUsefulNote(from memoryTail: String) -> String? {
        let lines = memoryTail
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "---" }

        if let nextStep = lines.reversed().first(where: { $0.lowercased().hasPrefix("next step:") }) {
            return clean(nextStep.replacingOccurrences(of: "Next step:", with: "Next:"))
        }

        if let bullet = lines.reversed().first(where: { $0.hasPrefix("- ") }) {
            return clean(String(bullet.dropFirst(2)))
        }

        return lines.last.map(clean)
    }

    private static func keyChanges(from memoryTail: String) -> [String] {
        let block = latestMemoryBlock(from: memoryTail)
        let bullets = block
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap { line -> String? in
                guard line.hasPrefix("- ") else { return nil }
                let text = clean(String(line.dropFirst(2)))
                let lowercased = text.lowercased()
                if lowercased.hasPrefix("ran ")
                    || lowercased.hasPrefix("attempted ")
                    || lowercased.hasPrefix("next step:")
                    || lowercased.contains("recommended")
                    || lowercased.contains("follow-up")
                    || lowercased.contains("next action") {
                    return nil
                }
                return text
            }

        let latest = Array(bullets.suffix(3))
        if !latest.isEmpty { return latest }

        return lastUsefulNote(from: block).map { [$0] } ?? []
    }

    private static func nextChanges(from memoryTail: String, blocker: String?, lastNote: String?) -> [String] {
        let block = latestMemoryBlock(from: memoryTail)
        var items: [String] = []

        if let blocker {
            items.append(blocker)
        }

        let lines = block
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        for line in lines {
            let lowercased = line.lowercased()
            if lowercased.hasPrefix("next step:") {
                items.append(clean(line.replacingOccurrences(of: "Next step:", with: "")))
            } else if line.hasPrefix("- ")
                        && (lowercased.contains("recommended")
                            || lowercased.contains("follow-up")
                            || lowercased.contains("next action")
                            || lowercased.contains("risk")
                            || lowercased.contains("drift")) {
                items.append(clean(String(line.dropFirst(2))))
            }
        }

        if items.isEmpty, let lastNote {
            items.append(lastNote)
        }

        return Array(NSOrderedSet(array: items).compactMap { $0 as? String }.prefix(3))
    }

    private static func latestMemoryBlock(from text: String) -> String {
        let separatorBlocks = text
            .components(separatedBy: "\n---")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if let latest = separatorBlocks.last, separatorBlocks.count > 1 {
            return latest
        }

        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        if let headingIndex = lines.indices.reversed().first(where: {
            lines[$0].trimmingCharacters(in: .whitespaces).hasPrefix("## ")
        }) {
            return lines[headingIndex...].joined(separator: "\n")
        }

        return text
    }

    private static func clean(_ text: String) -> String {
        let stripped = text
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(
                of: #"^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s+[A-Z]+:\s*"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(of: "User explicitly approved", with: "Approved")
            .replacingOccurrences(of: "User clarified that", with: "Clarified:")
            .replacingOccurrences(of: "User clarified", with: "Clarified")
            .replacingOccurrences(of: "User pointed to", with: "Reviewed")
            .replacingOccurrences(of: "User asked", with: "Requested")
            .replacingOccurrences(of: "User ", with: "You ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if stripped.count <= 220 { return stripped }
        return String(stripped.prefix(217)) + "..."
    }

    private static func tail(_ text: String, characterLimit: Int) -> String {
        guard text.count > characterLimit else { return text }
        return String(text.suffix(characterLimit))
    }

    private static func arrayCount(_ rawValue: String) -> Int {
        guard rawValue.hasPrefix("[") else { return 0 }
        return rawValue.split(separator: "\"").enumerated().filter { $0.offset % 2 == 1 }.count
    }

    private static func arrayValues(_ rawValue: String) -> [String] {
        guard rawValue.hasPrefix("[") else { return [] }
        return rawValue
            .split(separator: "\"")
            .enumerated()
            .compactMap { index, value in
                index % 2 == 1 ? String(value) : nil
            }
    }

    private static func scheduleSummary(_ rrule: String) -> String {
        guard !rrule.isEmpty else { return "No schedule" }
        let parts: [String: String] = Dictionary(uniqueKeysWithValues: rrule.split(separator: ";").compactMap { part -> (String, String)? in
            let pair = part.split(separator: "=", maxSplits: 1)
            guard pair.count == 2 else { return nil }
            return (String(pair[0]), String(pair[1]))
        })

        let hour = parts["BYHOUR"].flatMap(Int.init) ?? 0
        let minute = parts["BYMINUTE"].flatMap(Int.init) ?? 0
        let time = String(format: "%02d:%02d", hour, minute)

        if parts["FREQ"] == "DAILY" {
            return "Daily at \(time)"
        }

        if parts["FREQ"] == "WEEKLY" {
            let days = [
                "MO": "Mon", "TU": "Tue", "WE": "Wed", "TH": "Thu",
                "FR": "Fri", "SA": "Sat", "SU": "Sun"
            ]
            let day = days[parts["BYDAY"] ?? ""] ?? "weekly"
            return "Weekly \(day) at \(time)"
        }

        return rrule
    }

    private static func healthSort(_ health: AutomationHealth) -> Int {
        switch health {
        case .blocked: return 0
        case .approval: return 1
        case .active: return 2
        case .paused: return 3
        }
    }
}

struct FastReportView: View {
    @ObservedObject var model: AutomationModel
    let onRefresh: () -> Void
    let onOpenCodex: () -> Void
    let onOpenReportWindow: () -> Void
    let onOpenFolder: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            header
            actionBar

            HStack(spacing: 8) {
                StatPill(title: "Active", value: "\(model.activeCount)", tint: .green)
                StatPill(title: "Need OK", value: "\(model.approvalCount)", tint: .orange)
                StatPill(title: "Blocked", value: "\(model.blockedCount)", tint: .red)
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(model.items.prefix(4)) { item in
                    FastStatusRow(item: item)
                }
            }

            footer
        }
        .padding(14)
        .frame(width: 334, height: 286)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(color(for: model.overallHealth).opacity(0.13))
                    .frame(width: 32, height: 32)
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color(for: model.overallHealth))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Codex Automations")
                    .font(.system(size: 14, weight: .semibold))
                Text(model.headline)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .font(.system(size: 13, weight: .medium))
            .help("Refresh")
        }
    }

    private var actionBar: some View {
        VStack(spacing: 8) {
            Button(action: onOpenCodex) {
                Label("Open Codex", systemImage: "arrow.up.forward.app")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(Color.accentColor.opacity(0.12))
            .foregroundStyle(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 8) {
                Button(action: onOpenReportWindow) {
                    Label("Full Report", systemImage: "rectangle.split.2x1")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background(Color(nsColor: .separatorColor).opacity(0.13))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button(action: onOpenFolder) {
                    Label("Folder", systemImage: "folder")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background(Color(nsColor: .separatorColor).opacity(0.13))
                .foregroundStyle(.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text(updatedText)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Button(action: onQuit) {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .font(.system(size: 13, weight: .medium))
            .help("Quit")
        }
    }

    private var updatedText: String {
        guard let date = model.lastUpdated else { return "Not refreshed yet" }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "Updated \(formatter.string(from: date))"
    }
}

struct FastStatusRow: View {
    let item: AutomationItem

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color(for: item.health))
                .frame(width: 6, height: 6)

            Text(item.name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)

            Spacer()

            Text(statusLabel(for: item.health))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color(for: item.health))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color(for: item.health).opacity(0.11))
                .clipShape(Capsule())
        }
    }
}

struct ReportWindowView: View {
    @ObservedObject var model: AutomationModel
    let onRefresh: () -> Void
    let onReviewAutomation: (AutomationItem) -> Void
    let onOpenFolder: () -> Void
    @State private var selectedAutomationID: String?

    private var selectedItem: AutomationItem? {
        if let selectedAutomationID,
           let selected = model.items.first(where: { $0.id == selectedAutomationID }) {
            return selected
        }
        return model.items.first
    }

    var body: some View {
        HSplitView {
            ReportSidebarView(
                model: model,
                selectedAutomationID: $selectedAutomationID
            )
            .frame(minWidth: 180, idealWidth: 230, maxWidth: 340)

            ReportDocumentView(
                model: model,
                selectedItem: selectedItem
            )
            .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)

            ReportContentsView(
                model: model,
                selectedItem: selectedItem,
                onRefresh: onRefresh,
                onReviewAutomation: onReviewAutomation,
                onOpenFolder: onOpenFolder
            )
            .frame(minWidth: 230, idealWidth: 270, maxWidth: 380)
        }
        .frame(minWidth: 920, minHeight: 620)
        .onAppear {
            if selectedAutomationID == nil {
                selectedAutomationID = model.items.first?.id
            }
        }
        .onReceive(model.$items) { items in
            guard !items.isEmpty else {
                selectedAutomationID = nil
                return
            }
            if let selectedAutomationID,
               items.contains(where: { $0.id == selectedAutomationID }) {
                return
            }
            selectedAutomationID = items.first?.id
        }
    }
}

struct ReportSidebarView: View {
    @ObservedObject var model: AutomationModel
    @Binding var selectedAutomationID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("RECENT")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1.6)
                .padding(.top, 22)
                .padding(.horizontal, 16)

            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(model.items) { item in
                        Button {
                            selectedAutomationID = item.id
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 13))
                                    .foregroundStyle(color(for: item.health))
                                    .frame(width: 16)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(statusLabel(for: item.health))
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                selectedAutomationID == item.id
                                ? Color.accentColor.opacity(0.16)
                                : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
            }

            Spacer(minLength: 0)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct ReportDocumentView: View {
    @ObservedObject var model: AutomationModel
    let selectedItem: AutomationItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let item = selectedItem {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Circle()
                                .fill(color(for: item.health))
                                .frame(width: 8, height: 8)
                            Text(item.name)
                                .font(.system(size: 22, weight: .semibold))
                                .lineLimit(2)
                            Spacer()
                            Text(statusLabel(for: item.health))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(color(for: item.health))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(color(for: item.health).opacity(0.12))
                                .clipShape(Capsule())
                        }

                        UpdateHero(item: item)

                        ReportDetailBlock(
                            title: "What is happening now",
                            icon: "arrow.right",
                            tint: color(for: item.health),
                            items: item.nextChanges
                        )

                        ReportDetailBlock(
                            title: "What it accomplished",
                            icon: "checkmark",
                            tint: color(for: item.health),
                            items: item.keyChanges
                        )
                    }
                } else {
                    EmptyStateView()
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.horizontal, 34)
            .padding(.vertical, 28)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

struct UpdateHero: View {
    let item: AutomationItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Latest Update")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1.1)
                .textCase(.uppercase)

            Text(item.keyPoint)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
                .lineSpacing(3)

            Text(updateSubtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
        }
        .padding(14)
        .background(color(for: item.health).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var updateSubtitle: String {
        switch item.health {
        case .blocked:
            return "The automation reached a real blocker. The next useful move is to clear that blocker, then re-run or review the task."
        case .approval:
            return "The automation is waiting for a human check before it changes files, services, or other sensitive state."
        case .active:
            return "The automation is active and its latest local memory does not show a blocker."
        case .paused:
            return "The automation is paused or inactive."
        }
    }
}

struct InfoGrid: View {
    let item: AutomationItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Run Context")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1.1)
                .textCase(.uppercase)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], alignment: .leading, spacing: 10) {
                InfoCell(title: "Schedule", value: item.schedule)
                InfoCell(title: "Model", value: item.model)
                InfoCell(title: "Reasoning", value: item.reasoning)
                InfoCell(title: "Folders", value: "\(item.cwdCount)")
            }
        }
    }
}

struct InfoCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ReportPromptSummary: View {
    let item: AutomationItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Automation Intent")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1.1)
                .textCase(.uppercase)

            Text(intentText)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .lineSpacing(2)
        }
    }

    private var intentText: String {
        switch item.health {
        case .blocked:
            return "This automation is active, but the latest local memory reports a blocker that needs attention before the run can finish cleanly."
        case .approval:
            return "This automation has guardrails that require explicit review before writes, cleanup, service changes, or other sensitive actions."
        case .active:
            return "This automation is active and has no blocker detected in its latest local memory."
        case .paused:
            return "This automation is not currently active."
        }
    }
}

struct ReportDetailBlock: View {
    let title: String
    let icon: String
    let tint: Color
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                    .textCase(.uppercase)
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(height: 1)
            }

            if items.isEmpty {
                Text("Nothing new.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: icon)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(tint)
                                .frame(width: 14)
                            Text(item)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .lineSpacing(2)
                        }
                    }
                }
            }
        }
    }
}

struct ReportContentsView: View {
    @ObservedObject var model: AutomationModel
    let selectedItem: AutomationItem?
    let onRefresh: () -> Void
    let onReviewAutomation: (AutomationItem) -> Void
    let onOpenFolder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Inspector")
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 18)
                .padding(.top, 22)
                .padding(.bottom, 16)

            Divider()

            if let selectedItem {
                VStack(alignment: .leading, spacing: 12) {
                    InfoGrid(item: selectedItem)
                }
                .padding(18)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    ReportPromptSummary(item: selectedItem)
                }
                .padding(18)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Key Changes")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                        .textCase(.uppercase)

                    if selectedItem.keyChanges.isEmpty {
                        Text("Nothing new.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(selectedItem.keyChanges.prefix(4).enumerated()), id: \.offset) { _, change in
                            HStack(alignment: .firstTextBaseline, spacing: 7) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(color(for: selectedItem.health))
                                    .frame(width: 12)
                                Text(change)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(1)
                            }
                        }
                    }
                }
                .padding(18)

                Divider()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Actions")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                    .textCase(.uppercase)

                Button(action: onRefresh) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .controlSize(.small)

                Button(action: onOpenFolder) {
                    Label("Automation Folder", systemImage: "folder")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .controlSize(.small)

                if let selectedItem {
                    Button {
                        let memoryURL = URL(fileURLWithPath: selectedItem.automationPath)
                            .appendingPathComponent("memory.md")
                        NSWorkspace.shared.open(memoryURL)
                    } label: {
                        Label("Full info", systemImage: "doc.text.magnifyingglass")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .controlSize(.small)
                }

                if let selectedItem, selectedItem.needsApproval {
                    Button(action: { onReviewAutomation(selectedItem) }) {
                        Label("Review in Codex", systemImage: "arrow.up.forward.app")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .controlSize(.small)
                }

            }
            .padding(18)

            Spacer()
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct StatPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Text(value)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MiniTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(nsColor: .separatorColor).opacity(0.16))
            .clipShape(Capsule())
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
            Text("No Codex automations found.")
                .font(.system(size: 12, weight: .medium))
            Text("The app checks ~/.codex/automations.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

func color(for health: AutomationHealth) -> Color {
    switch health {
    case .active: return Color(nsColor: NSColor.systemGreen)
    case .approval: return Color(nsColor: NSColor.systemOrange)
    case .blocked: return Color(nsColor: NSColor.systemRed)
    case .paused: return Color(nsColor: NSColor.systemGray)
    }
}

func nsColor(for health: AutomationHealth) -> NSColor {
    switch health {
    case .active: return .systemGreen
    case .approval: return .systemOrange
    case .blocked: return .systemRed
    case .paused: return .systemGray
    }
}

func symbol(for health: AutomationHealth) -> String {
    switch health {
    case .active: return "checkmark.circle.fill"
    case .approval: return "hand.raised.circle.fill"
    case .blocked: return "exclamationmark.triangle.fill"
    case .paused: return "pause.circle.fill"
    }
}

func statusLabel(for health: AutomationHealth) -> String {
    switch health {
    case .active: return "OK"
    case .approval: return "Needs OK"
    case .blocked: return "Blocked"
    case .paused: return "Paused"
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AutomationModel()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var reportWindow: NSWindow?
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model.refresh()

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.imagePosition = .imageOnly
            button.toolTip = "Codex Automations"
        }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 334, height: 286)
        popover.contentViewController = NSHostingController(
            rootView: FastReportView(
                model: model,
                onRefresh: { [weak self] in
                    self?.model.refresh()
                    self?.updateIcon()
                },
                onOpenCodex: { [weak self] in
                    self?.openCodex()
                },
                onOpenReportWindow: { [weak self] in
                    self?.showReportWindow()
                },
                onOpenFolder: { [weak self] in
                    guard let self else { return }
                    NSWorkspace.shared.open(self.model.rootURL)
                },
                onQuit: {
                    NSApp.terminate(nil)
                }
            )
        )

        updateIcon()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.model.refresh()
            self?.updateIcon()
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            model.refresh()
            updateIcon()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        button.image = makeStatusIcon(for: model.overallHealth)
        button.contentTintColor = nsColor(for: model.overallHealth)
        button.toolTip = "Codex Automations: \(model.headline)"
    }

    private func openCodex() {
        openCodex(at: model.rootURL.path)
    }

    private func reviewAutomation(_ item: AutomationItem) {
        openCodex(at: item.workingPath ?? item.automationPath)
    }

    private func showReportWindow() {
        model.refresh()
        updateIcon()
        popover.performClose(nil)

        if let reportWindow {
            reportWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex Automation Report"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: ReportWindowView(
                model: model,
                onRefresh: { [weak self] in
                    self?.model.refresh()
                    self?.updateIcon()
                },
                onReviewAutomation: { [weak self] item in
                    self?.reviewAutomation(item)
                },
                onOpenFolder: { [weak self] in
                    guard let self else { return }
                    NSWorkspace.shared.open(self.model.rootURL)
                }
            )
        )
        reportWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openCodex(at path: String) {
        let codexCLI = URL(fileURLWithPath: "/opt/homebrew/bin/codex")
        if FileManager.default.fileExists(atPath: codexCLI.path) {
            let process = Process()
            process.executableURL = codexCLI
            process.arguments = ["app", path]
            try? process.run()
            return
        }

        let codexURL = URL(fileURLWithPath: "/Applications/Codex.app")
        if FileManager.default.fileExists(atPath: codexURL.path) {
            NSWorkspace.shared.openApplication(
                at: codexURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
            return
        }

        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    private func makeStatusIcon(for health: AutomationHealth) -> NSImage {
        let symbolName = "gearshape.2"
        let fallbackName = symbol(for: health)
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "Codex automation status"
        ) ?? NSImage(
            systemSymbolName: fallbackName,
            accessibilityDescription: "Codex automation status"
        ) ?? NSImage(size: NSSize(width: 18, height: 18))
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

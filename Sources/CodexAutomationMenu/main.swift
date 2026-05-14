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
        if needsApproval { return "Needs your OK before changing files or services." }
        if let lastNote { return lastNote }
        return "No recent note."
    }

    var overviewLines: [String] {
        switch health {
        case .blocked:
            return ["Needs attention.", "The next run is waiting on access or a clear review."]
        case .approval:
            return ["Ready for human review.", "Changes are prepared but not applied."]
        case .active:
            return ["Running quietly.", "No guidance needed right now."]
        case .paused:
            return ["Paused.", "This automation is not running."]
        }
    }

    var recentActions: [String] {
        let cleaned = keyChanges.map(Self.operationalText)
        if !cleaned.isEmpty { return Array(cleaned.prefix(3)) }

        switch health {
        case .blocked:
            return ["Detected an access issue"]
        case .approval:
            return ["Prepared changes for review"]
        case .active:
            return ["Checked latest automation state"]
        case .paused:
            return ["No recent activity"]
        }
    }

    var permissionItems: [String] {
        let lowercasedName = name.lowercased()
        if lowercasedName.contains("obsidian") {
            return ["write project notes", "update daily note sections"]
        }
        if lowercasedName.contains("skill") || lowercasedName.contains("hygiene") {
            return ["modify local files", "update installed skill folders"]
        }
        if lowercasedName.contains("stack") || lowercasedName.contains("ai") || lowercasedName.contains("ollama") {
            return ["inspect local services", "clean unused local state"]
        }
        if health == .active {
            return ["no extra permission needed"]
        }
        return ["review proposed changes", "continue the automation"]
    }

    var confidenceText: String {
        switch health {
        case .blocked:
            return "Needs review"
        case .approval:
            return "Safe to review"
        case .active:
            return "High"
        case .paused:
            return "Paused"
        }
    }

    var safetyText: String {
        switch health {
        case .blocked:
            return "apply only after access is cleared"
        case .approval:
            return "no changes applied"
        case .active:
            return "no destructive action detected"
        case .paused:
            return "no action running"
        }
    }

    var affectedItems: [String] {
        let lowercasedName = name.lowercased()
        if lowercasedName.contains("obsidian") {
            return ["Obsidian project notes", "Daily note status"]
        }
        if lowercasedName.contains("skill") || lowercasedName.contains("hygiene") {
            return ["Codex skills", "Installed skill folders"]
        }
        if lowercasedName.contains("stack") || lowercasedName.contains("ai") || lowercasedName.contains("ollama") {
            return ["Local AI services", "Model cache"]
        }
        return ["Configured workspace", "Automation memory"]
    }

    var proposedChanges: [DiffLine] {
        let source = keyChanges.isEmpty ? nextChanges : keyChanges
        let rows = source.map { DiffLine.make(from: $0) }
        if !rows.isEmpty { return Array(rows.prefix(4)) }

        switch health {
        case .blocked:
            return [DiffLine(kind: .warning, text: "clear permission issue")]
        case .approval:
            return [DiffLine(kind: .addition, text: "continue after approval")]
        case .active:
            return [DiffLine(kind: .neutral, text: "no proposed change")]
        case .paused:
            return [DiffLine(kind: .neutral, text: "paused")]
        }
    }

    private static func operationalText(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("wrapper-style skills") || lowercased.contains("user-created") {
            return "Marked wrapper skills as user-created"
        }
        if lowercased.contains("lowercase skill") || lowercased.contains("filenames") {
            return "Fixed lowercase filenames"
        }
        if lowercased.contains("verified") || lowercased.contains("cleanup") {
            return "Verified cleanup"
        }
        if lowercased.contains("v8v") || lowercased.contains("bundle") || lowercased.contains("catalog") {
            return "Verified bundle source"
        }
        if lowercased.contains("project notes") && lowercased.contains("missing") {
            return "Found missing project notes"
        }
        if lowercased.contains("project progress block") {
            return "Checked progress block"
        }
        if lowercased.contains("ollama") || lowercased.contains("model") {
            return "Checked local AI stack"
        }
        if lowercased.contains("out of sync") {
            return "Found skills out of sync"
        }
        if lowercased.contains("removed") || lowercased.contains("non-keep") {
            return "Removed unused models"
        }

        var result = text
            .replacingOccurrences(of: "Clarified:", with: "Clarified")
            .replacingOccurrences(of: "Confirmed the", with: "Confirmed")
            .replacingOccurrences(of: "Fixed the", with: "Fixed")
            .replacingOccurrences(of: "Marked the", with: "Marked")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if result.hasSuffix(".") {
            result.removeLast()
        }

        return result.count > 44 ? String(result.prefix(41)) + "..." : result
    }
}

struct DiffLine: Identifiable {
    enum Kind {
        case addition
        case rename
        case deletion
        case warning
        case neutral
    }

    let id = UUID()
    let kind: Kind
    let text: String

    static func make(from text: String) -> DiffLine {
        let lowercased = text.lowercased()
        if lowercased.contains("duplicated filler") || lowercased.contains("filler blocks") {
            return DiffLine(kind: .deletion, text: "Removed duplicated filler blocks")
        }
        if lowercased.contains("wrapper-style skills") || lowercased.contains("user-created") {
            return DiffLine(kind: .addition, text: "Marked wrapper skills as user-created")
        }
        if lowercased.contains("lowercase skill") || lowercased.contains("filenames") {
            return DiffLine(kind: .rename, text: "Fixed lowercase filenames")
        }
        if lowercased.contains("verified") || lowercased.contains("cleanup") {
            return DiffLine(kind: .addition, text: "Verified cleanup")
        }
        if lowercased.contains("94 skill") || lowercased.contains("validated") {
            return DiffLine(kind: .warning, text: "Validated skill folders")
        }
        if lowercased.contains("synced") || lowercased.contains("out of sync") {
            return DiffLine(kind: .addition, text: "Synced installed skills")
        }
        if lowercased.contains("non-keep") || lowercased.contains("unused model") || lowercased.contains("removed") {
            return DiffLine(kind: .deletion, text: "Removed unused models")
        }
        if lowercased.contains("ollama") || lowercased.contains("model") {
            return DiffLine(kind: .addition, text: "Checked local AI stack")
        }
        if lowercased.contains("project notes") && lowercased.contains("missing") {
            return DiffLine(kind: .warning, text: "Found missing project notes")
        }
        if lowercased.contains("project progress block") {
            return DiffLine(kind: .warning, text: "Checked progress block")
        }
        if lowercased.contains("bundle") || lowercased.contains("catalog") || lowercased.contains("v8v") {
            return DiffLine(kind: .addition, text: "Verified bundle source")
        }
        if lowercased.contains("delete") || lowercased.contains("removed") {
            return DiffLine(kind: .deletion, text: compact(text))
        }
        if lowercased.contains("rename") || lowercased.contains("lowercase skill") {
            return DiffLine(kind: .rename, text: compact(text))
        }
        if lowercased.contains("permission") || lowercased.contains("missing") || lowercased.contains("blocked") {
            return DiffLine(kind: .warning, text: compact(text))
        }
        return DiffLine(kind: .addition, text: compact(text))
    }

    private static func compact(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasSuffix(".") {
            result.removeLast()
        }
        return result.count > 48 ? String(result.prefix(45)) + "..." : result
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
            return "\(blockedCount) need attention"
        case .approval:
            return "\(approvalCount) need OK"
        case .active:
            return "\(activeCount) active"
        case .paused:
            return "No active automations"
        }
    }

    var needsAttentionItems: [AutomationItem] {
        items.filter { $0.health == .blocked || $0.health == .approval }
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
            return "Permission needed."
        }
        if text.contains("failed with") || text.contains("failed immediately") {
            return "Needs review before the next run."
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

        let latest = Array(NSOrderedSet(array: bullets.suffix(3)).compactMap { $0 as? String })
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
        let normalized = text
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

        let strippedPaths = normalized
            .replacingOccurrences(
                of: #"/Users/[^\s,.;:)]+(?:/[^\s,.;:)]+)*"#,
                with: "local files",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"~/?\.codex/[^\s,.;:)]+(?:/[^\s,.;:)]+)*"#,
                with: "Codex files",
                options: .regularExpression
            )

        let summarized = friendlySummary(for: strippedPaths)
        if summarized.count <= 145 { return summarized }
        return String(summarized.prefix(142)) + "..."
    }

    private static func friendlySummary(for text: String) -> String {
        let lowercased = text.lowercased()

        if lowercased.contains("lowercase skill") || lowercased.contains("renamed 8 files") {
            return "Fixed the lowercase skill filenames and verified the cleanup."
        }

        if lowercased.contains("user-created") || lowercased.contains("wrapper-style skills") {
            return "Marked the wrapper-style skills as user-created so future checks leave them alone."
        }

        if lowercased.contains("bundle source") || lowercased.contains("catalog") || lowercased.contains("v8v") {
            return "Confirmed the V8V folder is a real bundle/catalog source, not cleanup noise."
        }

        if lowercased.contains("per-project notes") && lowercased.contains("missing") {
            return "Project notes are still missing and need vault write access before this can complete."
        }

        if lowercased.contains("project progress block") && lowercased.contains("no") {
            return "The daily note exists, but the Project Progress block is still missing."
        }

        if lowercased.contains("permissionerror") || lowercased.contains("operation not permitted") {
            return "Write access is needed before running this automation again."
        }

        if lowercased.contains("ollama") && lowercased.contains("model") {
            return "Checked the local AI stack and found model/service details worth reviewing."
        }

        if lowercased.contains("out of sync") {
            return "Found installed skills that are out of sync with the improved pack."
        }

        return text
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
    let onOpenReportWindow: () -> Void
    let onReviewAutomation: (AutomationItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            VStack(alignment: .leading, spacing: 3) {
                ForEach(model.items.prefix(4)) { item in
                    FastStatusRow(
                        item: item,
                        onOpen: onOpenReportWindow,
                        onReview: onOpenReportWindow
                    )
                }
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
        .frame(width: 340, height: fastPopoverHeight(for: model.items))
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Codex Automations")
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
            Text("\(model.activeCount) active · \(updatedText.lowercased())")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var updatedText: String {
        relativeUpdatedText(model.lastUpdated)
    }
}

func fastPopoverHeight(for items: [AutomationItem]) -> CGFloat {
    let visibleRows = CGFloat(min(max(items.count, 1), 4))
    return 76 + visibleRows * 40
}

struct FastStatusRow: View {
    let item: AutomationItem
    let onOpen: () -> Void
    let onReview: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onOpen) {
                HStack(spacing: 8) {
                    StatusDot(health: item.health, size: 6)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(statusLabel(for: item.health))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            if hovering && item.needsApproval {
                Button(action: onReview) {
                    Text("Review")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(color(for: item.health))
                }
                .buttonStyle(.plain)
            } else {
                Text(shortStatus(for: item.health))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(color(for: item.health))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(hovering ? Color.primary.opacity(0.045) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .onHover { hovering = $0 }
    }
}

struct StatusDot: View {
    let health: AutomationHealth
    let size: CGFloat
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if health == .active && !reduceMotion {
                Circle()
                    .fill(color(for: health).opacity(pulse ? 0.12 : 0.28))
                    .frame(width: size * 2.4, height: size * 2.4)
                    .scaleEffect(pulse ? 1.12 : 0.72)
            }

            Circle()
                .fill(color(for: health))
                .frame(width: size, height: size)
        }
        .frame(width: max(size * 2.4, size), height: max(size * 2.4, size))
        .onAppear {
            guard health == .active, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

struct HeartbeatDot: View {
    let health: AutomationHealth
    let size: CGFloat
    @State private var glow = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(color(for: health).opacity(glow ? 0.12 : 0.28), lineWidth: 1)
                .frame(width: size * 3.1, height: size * 3.1)
                .scaleEffect(glow ? 1.12 : 0.84)
                .opacity(health == .paused ? 0 : 1)

            Circle()
                .fill(color(for: health))
                .frame(width: size, height: size)
        }
        .frame(width: size * 3.1, height: size * 3.1)
        .onAppear {
            guard !reduceMotion, health != .paused else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

struct ReportWindowView: View {
    @ObservedObject var model: AutomationModel
    let onRefresh: () -> Void
    let onReviewAutomation: (AutomationItem) -> Void
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
                selectedAutomationID: $selectedAutomationID,
                onReviewAutomation: onReviewAutomation,
                onRefresh: onRefresh
            )
            .frame(minWidth: 170, idealWidth: 230, maxWidth: 320)

            ReportDocumentView(
                model: model,
                selectedItem: selectedItem
            )
            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)

            ReportContentsView(
                model: model,
                selectedItem: selectedItem
            )
            .frame(minWidth: 220, idealWidth: 270, maxWidth: 360)
        }
        .frame(minWidth: 820, minHeight: 560)
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
    let onReviewAutomation: (AutomationItem) -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 24)
                .padding(.horizontal, 18)

            ScrollView {
                LazyVStack(spacing: 9) {
                    ForEach(model.items) { item in
                        SidebarAutomationRow(
                            item: item,
                            isSelected: selectedAutomationID == item.id,
                            onSelect: {
                                selectedAutomationID = item.id
                            },
                            onReview: {
                                selectedAutomationID = item.id
                            },
                            onOpenCodex: {
                                onReviewAutomation(item)
                            },
                            onOpenFolder: {
                                NSWorkspace.shared.open(URL(fileURLWithPath: item.workingPath ?? item.automationPath))
                            },
                            onRefresh: onRefresh,
                            onCopySummary: {
                                copySummary(for: item)
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
            }

            Spacer(minLength: 0)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func copySummary(for item: AutomationItem) {
        let summary = """
        \(item.name)
        \(statusLabel(for: item.health)) · \(item.confidenceText)
        \(item.proposedChanges.map(\.text).joined(separator: "\n"))
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
    }
}

struct SidebarAutomationRow: View {
    let item: AutomationItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onReview: () -> Void
    let onOpenCodex: () -> Void
    let onOpenFolder: () -> Void
    let onRefresh: () -> Void
    let onCopySummary: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                StatusDot(health: item.health, size: 7)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.9))
                        .lineLimit(1)
                    Text(statusLabel(for: item.health))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary.opacity(0.68))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if hovering && item.needsApproval {
                    Button(action: onReview) {
                        Text("Review")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(color(for: item.health))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(isSelected ? Color.accentColor.opacity(0.028) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.035), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Review Changes", action: onReview)
            Button("Open in Codex", action: onOpenCodex)
            Button("Open Folder", action: onOpenFolder)
            Divider()
            Button("Refresh", action: onRefresh)
            Button("Copy Summary", action: onCopySummary)
        }
    }
}

struct ReportDocumentView: View {
    @ObservedObject var model: AutomationModel
    let selectedItem: AutomationItem?

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let item = selectedItem {
                        VStack(alignment: .leading, spacing: 18) {
                            LiveStateHeader(
                                item: item
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(item.overviewLines.enumerated()), id: \.offset) { index, line in
                                    Text(line)
                                        .font(.system(size: 15))
                                        .foregroundStyle(index == 0 ? .primary : .secondary)
                                        .lineLimit(2)
                                }
                            }

                            OperationalGroup(title: "Proposed Changes", prominence: .primary) {
                                ReviewDiffPreview(lines: item.proposedChanges)
                            }

                            if item.health == .approval || item.health == .blocked {
                                ApprovalRequestBlock(item: item)
                            }

                            SafetyLine(item: item)
                        }
                    } else {
                        EmptyStateView()
                    }
                }
                .frame(
                    maxWidth: min(max(proxy.size.width - 56, 420), 860),
                    alignment: .leading
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, proxy.size.width < 560 ? 20 : 28)
                .padding(.vertical, proxy.size.width < 560 ? 22 : 28)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

struct LiveStateHeader: View {
    let item: AutomationItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                HeartbeatDot(health: item.health, size: 8)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Text(liveLine)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(color(for: item.health))
                    }
                }

                Spacer(minLength: 0)
            }

            if item.health == .active {
                LiveShimmerLine(tint: color(for: item.health))
            }
        }
        .padding(.vertical, 4)
    }

    private var liveLine: String {
        switch item.health {
        case .active: return "Running"
        case .approval: return "Needs review"
        case .blocked: return "Needs attention"
        case .paused: return "Paused"
        }
    }
}

struct LiveShimmerLine: View {
    let tint: Color
    @State private var phase = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tint.opacity(0.09))
                    .frame(height: 2)

                if !reduceMotion {
                    Capsule()
                        .fill(tint.opacity(0.36))
                        .frame(width: max(proxy.size.width * 0.22, 70), height: 2)
                        .offset(x: phase ? proxy.size.width : -proxy.size.width * 0.25)
                }
            }
        }
        .frame(height: 2)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) {
                phase = true
            }
        }
    }
}

struct OperationalGroup<Content: View>: View {
    enum Prominence {
        case primary
        case secondary
    }

    let title: String
    let prominence: Prominence
    let content: Content

    init(title: String, prominence: Prominence = .secondary, @ViewBuilder content: () -> Content) {
        self.title = title
        self.prominence = prominence
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if prominence == .primary {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.86))
            } else {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            content
        }
    }
}

struct OperationalBullet: View {
    let symbol: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 15)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .lineSpacing(2)
        }
    }
}

struct ApprovalRequestBlock: View {
    let item: AutomationItem

    var body: some View {
        OperationalGroup(title: "Permissions Needed") {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(item.permissionItems, id: \.self) { permission in
                    OperationalBullet(
                        symbol: "circle",
                        text: permission,
                        tint: color(for: item.health)
                    )
                }
            }
        }
    }
}

struct ReviewDiffPreview: View {
    let lines: [DiffLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(lines) { line in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(prefix(for: line.kind))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(tint(for: line.kind))
                        .frame(width: 18, alignment: .center)
                        .fixedSize(horizontal: true, vertical: false)

                    Text(line.text)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.84))
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func prefix(for kind: DiffLine.Kind) -> String {
        switch kind {
        case .addition: return "+"
        case .rename: return "→"
        case .deletion: return "−"
        case .warning: return "!"
        case .neutral: return "·"
        }
    }

    private func tint(for kind: DiffLine.Kind) -> Color {
        switch kind {
        case .addition: return Color(nsColor: .systemGreen)
        case .rename: return Color(nsColor: .systemBlue)
        case .deletion: return Color(nsColor: .systemRed)
        case .warning: return Color(nsColor: .systemOrange)
        case .neutral: return .secondary
        }
    }
}

struct SafetyLine: View {
    let item: AutomationItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color(for: item.health))
            Text(item.confidenceText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
            Text("·")
                .foregroundStyle(.tertiary)
            Text(item.safetyText)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct ReportContentsView: View {
    @ObservedObject var model: AutomationModel
    let selectedItem: AutomationItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let selectedItem {
                    Text(compactSchedule(selectedItem.schedule))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.82))
                        .lineLimit(1)

                    InspectorList(items: selectedItem.affectedItems, marker: "–")

                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedItem.confidenceText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.74))
                        Text(selectedItem.safetyText)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary.opacity(0.66))
                            .lineLimit(2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

func compactSchedule(_ schedule: String) -> String {
    schedule
        .replacingOccurrences(of: "Weekly ", with: "Weekly · ")
        .replacingOccurrences(of: "Daily at ", with: "Daily · ")
        .replacingOccurrences(of: " at ", with: " ")
}

struct InspectorSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.64))

            content
        }
    }
}

struct InspectorList: View {
    let items: [String]
    let marker: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(marker)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.72))
                        .frame(width: 10, alignment: .leading)
                    Text(item)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary.opacity(0.78))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
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
    case .active: return "Live"
    case .approval: return "Needs review"
    case .blocked: return "Attention"
    case .paused: return "Paused"
    }
}

func shortStatus(for health: AutomationHealth) -> String {
    switch health {
    case .active: return "Live"
    case .approval: return "Review"
    case .blocked: return "!"
    case .paused: return "Paused"
    }
}

func relativeUpdatedText(_ date: Date?) -> String {
    guard let date else { return "not refreshed" }
    let seconds = Int(Date().timeIntervalSince(date))
    if seconds < 5 { return "updated just now" }
    if seconds < 60 { return "updated \(seconds)s ago" }
    let minutes = seconds / 60
    if minutes < 60 { return "updated \(minutes)m ago" }

    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return "updated \(formatter.string(from: date))"
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
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = "Codex Automations"
        }

        popover.behavior = .transient
        popover.contentSize = fastPopoverSize()
        popover.contentViewController = NSHostingController(
            rootView: FastReportView(
                model: model,
                onOpenReportWindow: { [weak self] in
                    self?.showReportWindow()
                },
                onReviewAutomation: { [weak self] item in
                    self?.reviewAutomation(item)
                }
            )
        )

        updateIcon()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.model.refresh()
            self?.updateIcon()
            self?.updateReportWindowTitle()
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu(from: sender)
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            model.refresh()
            updateIcon()
            updateReportWindowTitle()
            popover.contentSize = fastPopoverSize()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showStatusMenu(from sender: NSStatusBarButton) {
        model.refresh()
        updateIcon()
        updateReportWindowTitle()
        popover.performClose(nil)

        let menu = NSMenu()
        menu.autoenablesItems = false

        addMenuItem("Open Codex", systemSymbol: "arrow.up.forward.app", action: #selector(openCodexFromMenu), to: menu)
        addMenuItem("Open Control Window", systemSymbol: "macwindow", action: #selector(openWindowFromMenu), to: menu)

        let reviewItem = addMenuItem(
            "Review Next Approval",
            systemSymbol: "checkmark.seal",
            action: #selector(reviewNextApprovalFromMenu),
            to: menu
        )
        reviewItem.isEnabled = model.needsAttentionItems.contains { $0.needsApproval || $0.health == .blocked }

        menu.addItem(.separator())
        addMenuItem("Refresh", systemSymbol: "arrow.clockwise", action: #selector(refreshFromMenu), to: menu)
        addMenuItem("Open Automations Folder", systemSymbol: "folder", action: #selector(openFolderFromMenu), to: menu)
        addMenuItem("Automation Settings", systemSymbol: "slider.horizontal.3", action: #selector(openSettingsFromMenu), to: menu)

        menu.addItem(.separator())
        addMenuItem("Quit", systemSymbol: "power", action: #selector(quitFromMenu), to: menu)

        menu.popUp(positioning: nil, at: NSPoint(x: sender.bounds.midX, y: sender.bounds.minY - 4), in: sender)
    }

    @discardableResult
    private func addMenuItem(
        _ title: String,
        systemSymbol: String,
        action: Selector,
        to menu: NSMenu
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = NSImage(systemSymbolName: systemSymbol, accessibilityDescription: title)
        menu.addItem(item)
        return item
    }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        button.image = makeStatusIcon(for: model.overallHealth)
        button.contentTintColor = .white
        button.toolTip = "Codex Automations: \(model.headline)"
    }

    private func updateReportWindowTitle() {
        reportWindow?.title = "Codex Automations · \(model.activeCount) active · \(relativeUpdatedText(model.lastUpdated))"
    }

    private func fastPopoverSize() -> NSSize {
        NSSize(width: 340, height: fastPopoverHeight(for: model.items))
    }

    private func openCodex() {
        openCodex(at: model.rootURL.path)
    }

    private func reviewAutomation(_ item: AutomationItem) {
        openCodex(at: item.workingPath ?? item.automationPath)
    }

    @objc private func openCodexFromMenu() {
        openCodex()
    }

    @objc private func openWindowFromMenu() {
        showReportWindow()
    }

    @objc private func reviewNextApprovalFromMenu() {
        showReportWindow()
    }

    @objc private func refreshFromMenu() {
        model.refresh()
        updateIcon()
        updateReportWindowTitle()
    }

    @objc private func openFolderFromMenu() {
        NSWorkspace.shared.open(model.rootURL)
    }

    @objc private func openSettingsFromMenu() {
        NSWorkspace.shared.open(model.rootURL)
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    private func showReportWindow() {
        model.refresh()
        updateIcon()
        popover.performClose(nil)

        if let reportWindow {
            updateReportWindowTitle()
            reportWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex Automations · \(model.activeCount) active · \(relativeUpdatedText(model.lastUpdated))"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: ReportWindowView(
                model: model,
                onRefresh: { [weak self] in
                    self?.model.refresh()
                    self?.updateIcon()
                    self?.updateReportWindowTitle()
                },
                onReviewAutomation: { [weak self] item in
                    self?.reviewAutomation(item)
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
        let image = NSImage(size: NSSize(width: 24, height: 18))
        image.lockFocus()

        let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14.5, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        let symbolImage = (
            NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: "Codex automation status")
            ?? NSImage(systemSymbolName: "timer", accessibilityDescription: "Codex automation status")
            ?? NSImage(systemSymbolName: "clock", accessibilityDescription: "Codex automation status")
        )?.withSymbolConfiguration(symbolConfiguration)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 1.4
        shadow.shadowOffset = NSSize(width: 0, height: -0.4)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.36)
        shadow.set()

        symbolImage?.draw(
            in: NSRect(x: 3.2, y: 2.1, width: 14.6, height: 14.6),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        let dotRect = NSRect(x: 16.1, y: 3.1, width: 5.2, height: 5.2)
        NSColor.white.withAlphaComponent(0.92).setFill()
        NSBezierPath(ovalIn: dotRect.insetBy(dx: -1.1, dy: -1.1)).fill()
        nsColor(for: health).setFill()
        NSBezierPath(ovalIn: dotRect).fill()

        image.unlockFocus()
        image.isTemplate = false
        image.size = NSSize(width: 24, height: 18)
        return image
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

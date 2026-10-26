import SwiftUI
import SiftCore
import SiftAppModel

/// One sidebar section: each rule's items, grouped, with checkboxes.
struct CategoryView: View {
    @Environment(AppState.self) private var state
    let kind: SectionKind

    var body: some View {
        let categories = state.categories(in: kind)
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(categories) { category in
                    VStack(alignment: .leading, spacing: 4) {
                        CategoryHeader(category: category, kind: kind)
                        if category.needsFDA {
                            Label("Some items in this category need Full Disk Access to be seen.", systemImage: "lock.fill")
                                .font(.callout)
                                .foregroundStyle(Theme.muted)
                                .padding(.vertical, 4)
                        }
                        if !category.items.isEmpty {
                            Divider().overlay(Theme.accentSoft).padding(.vertical, 6)
                        }
                        GroupedItemList(category: category)
                    }
                    .card(padding: 18)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 14)
            .padding(.bottom, 110)   // room for the floating action bar
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
        .overlay {
            if categories.isEmpty {
                if state.isBusy {
                    ProgressView("Scanning…").tint(Theme.accent)
                } else {
                    VStack(spacing: 12) {
                        IconTile(symbol: "checkmark", size: 56, fill: Theme.gradient(for: kind))
                        Text("All clear").font(.system(.title2, design: .rounded).weight(.bold))
                        Text("Nothing to clean in the enabled areas.").foregroundStyle(Theme.muted)
                    }
                }
            }
        }
    }
}

struct CategoryHeader: View {
    @Environment(AppState.self) private var state
    let category: CleanCategory
    var kind: SectionKind = .junk

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CheckBox(state: state.checkState(of: category.items), label: "All of \(category.rule.title)") {
                state.toggleAll(category.items)
            }
            .disabled(category.items.isEmpty)
            IconTile(symbol: category.rule.symbol, size: 38, fill: Theme.gradient(for: kind))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(category.rule.title).font(.system(size: 15, weight: .semibold))
                    RiskBadge(risk: category.rule.risk)
                }
                Text(category.rule.subtitle)
                    .font(.callout)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Text(Format.bytes(category.total))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.accentDeep)
                .accessibilityLabel("Total \(Format.bytes(category.total))")
        }
        .textCase(nil)
    }
}

/// Items without a group are listed directly; grouped ones sit under a collapsible header.
struct GroupedItemList: View {
    @Environment(AppState.self) private var state
    let category: CleanCategory

    var body: some View {
        let ungrouped = category.items.filter { $0.group == nil }
        let groups = Dictionary(grouping: category.items.filter { $0.group != nil }, by: { $0.group! })
            .sorted { $0.value.reduce(0) { $0 + $1.size } > $1.value.reduce(0) { $0 + $1.size } }

        ForEach(groups, id: \.key) { name, items in
            let key = "\(category.id)/\(name)"
            GroupHeader(name: name, items: items, collapsed: state.collapsedGroups.contains(key)) {
                state.toggleCollapsed(key)
            }
            if !state.collapsedGroups.contains(key) {
                ForEach(items) { ItemRow(item: $0, ruleRisk: category.rule.risk).padding(.leading, 22) }
            }
        }
        ForEach(ungrouped) { ItemRow(item: $0, ruleRisk: category.rule.risk) }
    }
}

struct GroupHeader: View {
    @Environment(AppState.self) private var state
    let name: String
    let items: [CleanItem]
    let collapsed: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            CheckBox(state: state.checkState(of: items), label: "All of \(name)") { state.toggleAll(items) }
            Button(action: toggle) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(collapsed ? 0 : 90))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text(name).fontWeight(.medium)
                    Text(Format.items(items.count)).foregroundStyle(Theme.muted)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(name), \(Format.items(items.count))")
            .accessibilityValue(collapsed ? "collapsed" : "expanded")
            .accessibilityHint(collapsed ? "Shows the items" : "Hides the items")
            Text(Format.bytes(items.reduce(0) { $0 + $1.size }))
                .monospacedDigit()
                .foregroundStyle(Theme.muted)
        }
    }
}

struct ItemRow: View {
    @Environment(AppState.self) private var state
    let item: CleanItem
    let ruleRisk: Risk

    var body: some View {
        HStack(spacing: 8) {
            CheckBox(state: state.selection.contains(item.id) ? .all : .none,
                     label: "\(item.name), \(Format.bytes(item.size))") { state.toggle(item.id) }
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).lineLimit(1).truncationMode(.middle)
                HStack(spacing: 6) {
                    if let detail = item.detail { Text(detail) }
                    if let age = Format.age(item.modified) { Text("Modified \(age)") }
                }
                .font(.caption)
                .foregroundStyle(Theme.muted)
            }
            .help(item.url.path(percentEncoded: false))
            Spacer()
            if item.risk != ruleRisk { RiskBadge(risk: item.risk) }
            Text(Format.bytes(item.size))
                .monospacedDigit()
                .foregroundStyle(Theme.muted)
                .frame(minWidth: 70, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .contextMenu {
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
        }
    }
}

struct RiskBadge: View {
    let risk: Risk

    var body: some View {
        Text(risk.title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(risk.color)
            .background(risk.color.opacity(0.12), in: Capsule())
            .help(risk.explanation)
            .accessibilityLabel("Risk: \(risk.title)")
            .accessibilityHint(risk.explanation)
    }
}

/// Three-state checkbox (none / some / all) drawn with SF Symbols.
struct CheckBox: View {
    let state: AppState.CheckState
    var label = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(state == .none ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Theme.accent))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(state == .all ? "checked" : state == .some ? "partly checked" : "unchecked")
    }

    private var symbol: String {
        switch state {
        case .none: "circle"
        case .some: "minus.circle.fill"
        case .all: "checkmark.circle.fill"
        }
    }
}

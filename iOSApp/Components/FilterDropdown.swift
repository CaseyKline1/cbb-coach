import SwiftUI

struct FilterDropdown<Option: Hashable>: View {
    let title: String
    @Binding var selection: Option
    let options: [(label: String, value: Option)]
    var isSearchEnabled: Bool = true
    var isCompact: Bool = false

    init(
        title: String = "",
        selection: Binding<Option>,
        options: [(label: String, value: Option)],
        isSearchEnabled: Bool = true,
        isCompact: Bool = false
    ) {
        self.title = title
        self._selection = selection
        self.options = options
        self.isSearchEnabled = isSearchEnabled
        self.isCompact = isCompact
    }

    init(
        label: String,
        selection: Binding<Option>,
        options: [Option],
        optionLabel: @escaping (Option) -> String,
        isSearchEnabled: Bool = true,
        isCompact: Bool = false
    ) {
        self.init(
            title: label,
            selection: selection,
            options: options.map { (label: optionLabel($0), value: $0) },
            isSearchEnabled: isSearchEnabled,
            isCompact: isCompact
        )
    }

    init(
        label: String,
        selection: Binding<Option>,
        options: [Option],
        optionLabel: KeyPath<Option, String>,
        isSearchEnabled: Bool = true,
        isCompact: Bool = false
    ) {
        self.init(
            label: label,
            selection: selection,
            options: options,
            optionLabel: { $0[keyPath: optionLabel] },
            isSearchEnabled: isSearchEnabled,
            isCompact: isCompact
        )
    }

    @State private var isPresented = false
    @State private var searchText = ""

    private var selectedLabel: String {
        options.first { $0.value == selection }?.label ?? "Select"
    }

    private var isFiltered: Bool {
        options.first?.value != selection
    }

    private var visibleOptions: [(label: String, value: Option)] {
        guard isSearchEnabled, !searchText.isEmpty else { return options }
        return options.filter { $0.label.localizedCaseInsensitiveContains(searchText) }
    }

    private var shouldShowSearch: Bool {
        isSearchEnabled && options.count > 6
    }

    private var hasTitle: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Button { isPresented = true } label: {
            VStack(alignment: .leading, spacing: hasTitle ? (isCompact ? 3 : 5) : 0) {
                if hasTitle {
                    Text(title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isFiltered ? AppTheme.ink.opacity(0.85) : .secondary)
                        .lineLimit(1)
                }
                HStack(spacing: isCompact ? 6 : 8) {
                    Text(selectedLabel)
                        .font((isCompact ? Font.footnote : .callout).weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, isCompact ? 10 : 12)
            .padding(.vertical, isCompact ? 7 : 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: isCompact ? 10 : 12, style: .continuous)
                    .fill(Color(UIColor.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: isCompact ? 10 : 12, style: .continuous)
                    .strokeBorder(isFiltered ? AppTheme.ink.opacity(0.35) : Color.black.opacity(0.14),
                                  lineWidth: isFiltered ? 1.2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: isCompact ? 10 : 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(title): \(selectedLabel)"))
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(selectedLabel)
                            .font(.headline.weight(.semibold))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(UIColor.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.14), lineWidth: 1)
                    )

                    if shouldShowSearch {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("Search", text: $searchText)
                                .font(.callout)
                                .autocorrectionDisabled()
                            if !searchText.isEmpty {
                                Button { searchText = "" } label: {
                                    Text("Clear")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                        .background(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.black.opacity(0.14), lineWidth: 1)
                        )
                    }

                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(visibleOptions.indices, id: \.self) { index in
                                let option = visibleOptions[index]
                                let isSelected = option.value == selection
                                Button {
                                    selection = option.value
                                    isPresented = false
                                } label: {
                                    HStack(spacing: 10) {
                                        Text(option.label)
                                            .font(.callout.weight(.medium))
                                            .foregroundStyle(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(isSelected ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(isSelected ? AppTheme.ink.opacity(0.32) : Color.black.opacity(0.12), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            if visibleOptions.isEmpty {
                                Text("No results")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { isPresented = false }
                    }
                }
            }
            .presentationDetents(shouldShowSearch ? [.medium, .large] : [.medium])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: isPresented) { _, presented in
            if !presented { searchText = "" }
        }
    }
}

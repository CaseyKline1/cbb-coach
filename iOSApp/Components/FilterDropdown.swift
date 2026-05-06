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
        guard shouldShowSearch, !searchText.isEmpty else { return options }
        return options.filter { $0.label.localizedCaseInsensitiveContains(searchText) }
    }

    private var shouldShowSearch: Bool {
        isSearchEnabled && options.count >= 20
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
        .popover(
            isPresented: $isPresented,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .top
        ) {
            dropdownContent
                .presentationCompactAdaptation(.popover)
        }
        .onChange(of: isPresented) { _, presented in
            if !presented { searchText = "" }
        }
    }

    private var dropdownContent: some View {
        VStack(alignment: .leading, spacing: shouldShowSearch ? 8 : 4) {
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
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(visibleOptions.indices, id: \.self) { index in
                        let option = visibleOptions[index]
                        dropdownOptionButton(option)
                    }
                    if visibleOptions.isEmpty {
                        Text("No results")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                    }
                }
            }
            .frame(maxHeight: dropdownListMaxHeight)
        }
        .padding(6)
        .frame(width: isCompact ? 220 : 300)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.black.opacity(0.14), lineWidth: 1)
        )
    }

    private var dropdownListMaxHeight: CGFloat {
        let rowHeight: CGFloat = 40
        let visibleRowCount = min(max(visibleOptions.count, 1), shouldShowSearch ? 8 : 7)
        return CGFloat(visibleRowCount) * rowHeight
    }

    private func dropdownOptionButton(_ option: (label: String, value: Option)) -> some View {
        let isSelected = option.value == selection
        return Button {
            selection = option.value
            isPresented = false
        } label: {
            HStack(spacing: 9) {
                Text(option.label)
                    .font(.callout.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.ink.opacity(0.72))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color(UIColor.secondarySystemBackground) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

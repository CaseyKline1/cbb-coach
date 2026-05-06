import SwiftUI

struct AppTableColumn<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
    let width: CGFloat
    var alignment: Alignment = .center
}

struct AppTableSortState<ID: Hashable> {
    let column: ID
    let ascending: Bool
}

struct AppTableStyle {
    var headerVerticalPadding: CGFloat = 3
    var rowVerticalPadding: CGFloat = 2
    var horizontalPadding: CGFloat = 10
    var minimumRowHeight: CGFloat = 20
    var cornerRadius: CGFloat = 12
    var borderColor: Color = AppTheme.cardBorder

    static let compact = AppTableStyle()
}

struct AppTable<RowData, ColumnID: Hashable, RowContent: View>: View {
    private struct RowEntry: Identifiable {
        let id: AnyHashable
        let data: RowData
    }

    private let columns: [AppTableColumn<ColumnID>]
    private let rows: [RowEntry]
    private let sortState: AppTableSortState<ColumnID>?
    private let onSort: ((ColumnID) -> Void)?
    private let style: AppTableStyle
    private let maxBodyHeight: CGFloat?
    private let rowContent: (RowData) -> RowContent

    init(
        columns: [AppTableColumn<ColumnID>],
        rows: [(id: AnyHashable, data: RowData)],
        sortState: AppTableSortState<ColumnID>? = nil,
        onSort: ((ColumnID) -> Void)? = nil,
        style: AppTableStyle = .compact,
        maxBodyHeight: CGFloat? = nil,
        @ViewBuilder rowContent: @escaping (RowData) -> RowContent
    ) {
        self.columns = columns
        self.rows = rows.map { RowEntry(id: $0.id, data: $0.data) }
        self.sortState = sortState
        self.onSort = onSort
        self.style = style
        self.maxBodyHeight = maxBodyHeight
        self.rowContent = rowContent
    }

    var body: some View {
        tableContent
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .stroke(style.borderColor, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var tableContent: some View {
        if let maxBodyHeight {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            rowViews
                        }
                    }
                    .frame(maxHeight: maxBodyHeight)
                }
                .padding(.horizontal, style.horizontalPadding)
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow
                    rowViews
                }
                .padding(.horizontal, style.horizontalPadding)
            }
        }
    }

    private var rowViews: some View {
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
            rowContent(row.data)
                .frame(minHeight: style.minimumRowHeight)
                .padding(.vertical, style.rowVerticalPadding)
            if index < rows.count - 1 {
                Divider().opacity(0.4)
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                headerCell(column)
            }
        }
        .padding(.vertical, style.headerVerticalPadding)
        .background(AppTheme.cardBackground)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func headerCell(_ column: AppTableColumn<ColumnID>) -> some View {
        Group {
            if let onSort {
                Button {
                    onSort(column.id)
                } label: {
                    headerLabel(for: column)
                }
                .buttonStyle(.plain)
            } else {
                headerLabel(for: column)
            }
        }
    }

    private func headerLabel(for column: AppTableColumn<ColumnID>) -> some View {
        let isActive = sortState?.column == column.id
        return HStack(spacing: 2) {
            Text(column.title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(isActive ? AppTheme.accent : .secondary)
            if isActive, let sortState {
                Image(systemName: sortState.ascending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .frame(width: column.width, alignment: column.alignment)
    }
}

struct AppTableTextCell: View {
    let text: String
    let width: CGFloat
    var alignment: Alignment = .center
    var font: Font = .caption.monospacedDigit()
    var foreground: Color = .primary

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: width, alignment: alignment)
    }
}

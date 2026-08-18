import SwiftUI

/// Shared table column header used by every data-table tool: bold caption2,
/// secondary color, optional fixed width or flexible fill.
struct TableHeader: View {
    let title: String
    var width: CGFloat? = nil
    var flexible: Bool = false

    init(_ title: String, width: CGFloat? = nil, flexible: Bool = false) {
        self.title = title
        self.width = width
        self.flexible = flexible
    }

    var body: some View {
        Text(title)
            .font(.system(.caption2, design: .default).weight(.bold))
            .foregroundColor(.secondary)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }
}
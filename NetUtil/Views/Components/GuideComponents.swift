import SwiftUI

struct GuideSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundColor(.accentColor).font(.headline)
                Text(title).font(.headline)
            }
            content.font(.subheadline).foregroundColor(.secondary)
        }
    }
}

struct GuidePoint: View {
    let title: String
    let desc: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.callout.weight(.semibold)).foregroundColor(.primary)
            Text(desc).font(.callout).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

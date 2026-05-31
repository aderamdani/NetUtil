import SwiftUI

struct AboutToolGrid: View {
    let tools: [(String, String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Included Diagnostics")
                .font(.headline)
                .padding(.leading, 4)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(tools.enumerated()), id: \.element.1) { index, tool in
                    HStack(spacing: 12) {
                        Image(systemName: tool.0)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        
                        Text(tool.1)
                            .font(.subheadline)
                        
                        Spacer()
                    }
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(tool.1) tool included")
                }
            }
        }
    }
}

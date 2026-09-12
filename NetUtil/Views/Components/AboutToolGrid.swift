import SwiftUI

struct AboutToolGrid: View {
    let tools: [(String, String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Included Diagnostics")
                .font(.headline)
                .padding(.leading, Metrics.spacingXS)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Metrics.spacingMD) {
                ForEach(Array(tools.enumerated()), id: \.element.1) { index, tool in
                    HStack(spacing: Metrics.spacingMD) {
                        Image(systemName: tool.0)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        
                        Text(tool.1)
                            .font(.subheadline)
                        
                        Spacer()
                    }
                    .padding(Metrics.spacingMD)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusSM))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(tool.1) tool included")
                }
            }
        }
    }
}

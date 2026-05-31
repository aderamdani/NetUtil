import SwiftUI
import Network

struct BonjourBrowserView: View {
    @Environment(BonjourBrowserViewModel.self) private var viewModel
    
    var body: some View {
        VStack(spacing: 0) {
            controlBar
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.discoveredServices) { service in
                        ServiceRow(service: service)
                    }
                }
                .padding()
            }
        }
        .background(.regularMaterial)
    }
    
    private var controlBar: some View {
        HStack(spacing: 12) {
            Picker("Service Type", selection: Bindable(viewModel).selectedServiceType) {
                ForEach(viewModel.availableServiceTypes) { type in
                    Text(type.name).tag(type.id)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)

            TextField("Filter", text: Bindable(viewModel).searchFilter)
                .textFieldStyle(.roundedBorder)
            
            Spacer()
            
            Button(action: {
                if viewModel.isScanning {
                    viewModel.stopBrowsing()
                } else {
                    viewModel.startBrowsing()
                }
            }) {
                Image(systemName: viewModel.isScanning ? "stop.fill" : "play.fill")
            }
        }
        .padding(12)
        .background(.regularMaterial)
    }
}

struct ServiceRow: View {
    let service: BonjourService
    
    var body: some View {
        HStack {
            Image(systemName: "bonjour")
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading) {
                Text(service.name).font(.headline)
                Text(service.type)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(service.resolvedAddress)
                .font(.system(.caption, design: .monospaced))
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

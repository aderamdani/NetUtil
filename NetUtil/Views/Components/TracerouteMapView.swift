import SwiftUI
import MapKit

struct TracerouteMapView: View {
    let hops: [TracerouteHop]
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            ForEach(hops.compactMap { h in h.geo?.coordinate.map { (h, $0) } }, id: \.0.id) { hop, coord in
                Annotation("Hop \(hop.hop)", coordinate: coord) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 12, height: 12)
                            .shadow(radius: 2)
                        Text("\(hop.hop)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Connect points with line if multiple
            if hops.compactMap({ $0.geo?.coordinate }).count > 1 {
                MapPolyline(coordinates: hops.compactMap({ $0.geo?.coordinate }))
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
    }
}

import CoreLocationUI
import MapKit
import SwiftUI

struct LocationView: View {
    
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var viewModel: LocationViewModel
    
    init(entity: LocationMessageEntity) {
        _viewModel = StateObject(wrappedValue: LocationViewModel(objectID: entity.objectID))
    }
    
    var body: some View {
        NavigationView {
            Group {
                content
            }
            .environmentObject(viewModel)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if viewModel.canOpenGoogleMaps {
                            Button(viewModel.showInGoogleMapsButtonText) {
                                viewModel.showInGoogleMaps()
                            }
                        }

                        Button(viewModel.showInMapsButtonText) {
                            viewModel.showInMaps()
                        }

                        Button(viewModel.calculateRouteButtonText) {
                            viewModel.calculateRoute()
                        }
                    } label: {
                        Image(systemName: viewModel.shareImageName)
                    }
                }
            }
            .onAppear {
                viewModel.load()
                viewModel.checkPermission()
            }
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationViewStyle(.stack)
        }
    }
    
    @ViewBuilder
    var content: some View {
        MapView()
    }
}

struct MapView: View {
    @EnvironmentObject var viewModel: LocationViewModel
    @State private var position = MapCameraPosition.automatic
    @State private var mapStyle: MapStyle = .standard

    var body: some View {
        ZStack(alignment: .bottomTrailing,) {
            Map(position: $position) {
                if let pointOfInterest = viewModel.pointOfInterest {
                    Marker(pointOfInterest.name ?? "", coordinate: pointOfInterest.clLocationCoordinate)
                        .tint(Color.accentColor)
                    if let accuracy = pointOfInterest.accuracy {
                        MapCircle(center: pointOfInterest.clLocationCoordinate, radius: accuracy)
                            .foregroundStyle(UIColor.tintColor.color.opacity(0.5))
                            .stroke(UIColor.tintColor.color, lineWidth: 1)
                    }
                }
            }
            .mapStyle(mapStyle)
            .mapControls {
                if [.authorizedAlways, .authorizedWhenInUse].contains(viewModel.authorizationStatus) {
                    MapUserLocationButton()
                }
            }
            .onChange(of: viewModel.pointOfInterest) {
                if let coordinate = viewModel.pointOfInterest {
                    position = .camera(MapCamera(centerCoordinate: coordinate.clLocationCoordinate, distance: 1000))
                }
            }
            
            mapControlPanel
        }
        .overlay(alignment: .bottom) {
            if [.denied].contains(viewModel.authorizationStatus) {
                LocationButton(.currentLocation) { }
                    .labelStyle(.titleAndIcon)
                    .symbolVariant(.fill)
                    .tint(.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(.capsule)
                    .padding(.vertical, 5)
            }
        }
    }
    
    @ViewBuilder
    private var mapControlPanel: some View {
        VStack(spacing: 5) {
            if let coord = viewModel.pointOfInterest {
                MapControlButton(systemImage: viewModel.centerMapPinImageName) {
                    withAnimation {
                        position = .camera(MapCamera(centerCoordinate: coord.clLocationCoordinate, distance: 1000))
                    }
                }
                .accessibilityLabel(viewModel.centerMapPinAccessibilityLabel)
            }
            
            MapControlMenu(systemImage: viewModel.mapImageName) {
                Button(viewModel.mapStyleStandardText) { mapStyle = .standard }
                Button(viewModel.mapStyleHybridText) { mapStyle = .hybrid }
                Button(viewModel.mapStyleSatelliteText) { mapStyle = .imagery }
            }
        }
        .padding(5)
        .padding(.bottom, 8)
    }
}

import SwiftUI
import MapKit

struct HomeView: View {
    @EnvironmentObject var viewModel: BathroomViewModel

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        )
    )
    @State private var didCenterOnUser = false
    @State private var selectedBathroom: Bathroom?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    // MARK: Windowed Interactive Map
                    ZStack(alignment: .topTrailing) {
                        Map(position: $cameraPosition) {
                            UserAnnotation()

                            // Route polyline (mirrors full map)
                            if let route = viewModel.currentRoute {
                                MapPolyline(route.polyline)
                                    .stroke(
                                        .linearGradient(
                                            colors: [.blue, .teal],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 5
                                    )
                            }

                            ForEach(viewModel.filteredBathrooms.prefix(40)) { bathroom in
                                Annotation(bathroom.name,
                                           coordinate: bathroom.coordinate,
                                           anchor: .bottom) {
                                    BathroomMapPin(bathroom: bathroom) {
                                        selectedBathroom = bathroom
                                    }
                                }
                            }
                        }
                        .mapStyle(viewModel.mapStyleOption.mapStyle)
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                        .onAppear { viewModel.requestLocation() }
                        .onChange(of: viewModel.userLocation) { _, loc in
                            guard let loc, !didCenterOnUser else { return }
                            didCenterOnUser = true
                            withAnimation(.easeInOut(duration: 0.8)) {
                                cameraPosition = .region(MKCoordinateRegion(
                                    center: loc,
                                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                ))
                            }
                        }
                        .onChange(of: viewModel.currentRoute) { _, route in
                            guard let route else { return }
                            let rect = route.polyline.boundingMapRect
                            withAnimation(.easeInOut(duration: 0.7)) {
                                cameraPosition = .rect(
                                    rect.insetBy(dx: -rect.size.width * 0.35,
                                                 dy: -rect.size.height * 0.35)
                                )
                            }
                        }

                        // Locate-me button (top-right corner of window)
                        Button {
                            guard let loc = viewModel.userLocation else { return }
                            withAnimation {
                                cameraPosition = .region(MKCoordinateRegion(
                                    center: loc,
                                    span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                                ))
                            }
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.blue)
                                .frame(width: 36, height: 36)
                                .background(.white)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // MARK: Map Style Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Map Style")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(MapStyleOption.allCases, id: \.self) { option in
                                    MapStyleChip(
                                        option: option,
                                        isSelected: viewModel.mapStyleOption == option
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            viewModel.mapStyleOption = option
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 14)

                    // MARK: Filter Chips
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Filters")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)

                        FilterBarView()
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 12)

                    // MARK: Nearby Header
                    HStack {
                        Text("Nearby Restrooms")
                            .font(.title3.bold())
                        Spacer()
                        if viewModel.isFetchingExternal {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.75)
                                Text("Updating…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 6)

                    // MARK: Nearby List
                    if viewModel.sortedByDistance.isEmpty {
                        ContentUnavailableView(
                            "No Restrooms Found",
                            systemImage: "toilet",
                            description: Text("Try adjusting your filters or move to a different area.")
                        )
                        .padding(.top, 20)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.sortedByDistance.prefix(15)) { bathroom in
                                BathroomRowView(bathroom: bathroom)
                                    .padding(.horizontal, 16)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedBathroom = bathroom }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: viewModel.iCloudAvailable
                          ? "icloud.fill"
                          : "icloud.slash.fill")
                        .font(.subheadline)
                        .foregroundStyle(viewModel.iCloudAvailable ? .blue : .secondary)
                        .help(viewModel.iCloudAvailable
                              ? "iCloud backup active"
                              : "Sign in to iCloud to enable backup")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showAddBathroom = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                    }
                }
            }
            .sheet(item: $selectedBathroom) { bathroom in
                BathroomDetailView(bathroom: bathroom)
            }
            .sheet(isPresented: $viewModel.showAddBathroom) {
                AddBathroomView()
            }
            .task {
                if let loc = viewModel.userLocation {
                    await viewModel.fetchExternalBathrooms(near: loc)
                }
            }
            .onChange(of: viewModel.userLocation) { _, loc in
                guard let loc else { return }
                Task { await viewModel.fetchExternalBathrooms(near: loc) }
            }
        }
    }
}

// MARK: - Map Style Chip

struct MapStyleChip: View {
    let option: MapStyleOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(option.rawValue)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.green : Color(.secondarySystemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.clear : Color.secondary.opacity(0.25),
                        lineWidth: 1
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

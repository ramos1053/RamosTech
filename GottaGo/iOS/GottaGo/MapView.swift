import SwiftUI
import MapKit

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct MapView: View {
    @EnvironmentObject var viewModel: BathroomViewModel

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        )
    )
    @State private var didCenterOnUser = false
    @State private var selectedBathroom: Bathroom?
    @State private var showDetail = false
    @State private var longPressCoordinate: CLLocationCoordinate2D?
    @State private var showLongPressAdd = false

    var body: some View {
        ZStack(alignment: .bottom) {

            // MARK: Map + Long Press Gesture
            MapReader { proxy in
                Map(position: $cameraPosition) {
                    UserAnnotation()

                    // Route polyline
                    if let route = viewModel.currentRoute {
                        MapPolyline(route.polyline)
                            .stroke(
                                .linearGradient(
                                    colors: [.blue, .teal],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 6
                            )
                    }

                    // Bathroom pins
                    ForEach(viewModel.filteredBathrooms) { bathroom in
                        Annotation(bathroom.name, coordinate: bathroom.coordinate, anchor: .bottom) {
                            BathroomMapPin(bathroom: bathroom) {
                                selectedBathroom = bathroom
                                showDetail = true
                            }
                        }
                    }
                }
                .mapStyle(viewModel.mapStyleOption.mapStyle)
                .ignoresSafeArea(edges: .top)
                // Long press to add a bathroom at that location
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.55)
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .onEnded { value in
                            guard case .second(true, let drag) = value else { return }
                            let point = drag?.startLocation ?? .zero
                            guard let coord = proxy.convert(point, from: .local) else { return }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            longPressCoordinate = coord
                            showLongPressAdd = true
                        }
                )
                .onAppear { viewModel.requestLocation() }
                // Auto-center on first location fix
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
                // Zoom to fit the route when it loads
                .onChange(of: viewModel.currentRoute) { _, route in
                    guard let route else { return }
                    let rect = route.polyline.boundingMapRect
                    withAnimation(.easeInOut(duration: 0.7)) {
                        cameraPosition = .rect(
                            rect.insetBy(dx: -rect.size.width * 0.35, dy: -rect.size.height * 0.35)
                        )
                    }
                }
            }

            // MARK: Bottom Overlay
            VStack(spacing: 0) {

                // Route card (replaces filter bar when navigating)
                if viewModel.isCalculatingRoute {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Calculating route…")
                            .font(.subheadline)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)

                } else if let destination = viewModel.routeDestination {
                    RouteInfoCard(destination: destination)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)

                } else {
                    FilterBarView()
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }

                // Action buttons (locate + add)
                HStack {
                    if viewModel.currentRoute != nil {
                        // Clear route button
                        Button {
                            viewModel.clearRoute()
                        } label: {
                            Label("End Route", systemImage: "xmark.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(.red)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .shadow(color: .red.opacity(0.3), radius: 5, y: 2)
                        }
                        .padding(.leading, 16)
                        .padding(.bottom, 14)
                    }

                    Spacer()

                    VStack(spacing: 10) {
                        CircleButton(systemImage: "location.fill", tint: .blue, background: .white) {
                            guard let loc = viewModel.userLocation else { return }
                            withAnimation {
                                cameraPosition = .region(MKCoordinateRegion(
                                    center: loc,
                                    span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                                ))
                            }
                        }
                        CircleButton(systemImage: "plus", tint: .white, background: .green) {
                            viewModel.showAddBathroom = true
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 14)
                }
            }
        }
        // Long-press add sheet
        .sheet(isPresented: $showLongPressAdd, onDismiss: { longPressCoordinate = nil }) {
            if let coord = longPressCoordinate {
                AddBathroomView(prefilledCoordinate: coord)
            }
        }
        // Detail sheet from pin tap
        .sheet(isPresented: $showDetail, onDismiss: { selectedBathroom = nil }) {
            if let bathroom = selectedBathroom {
                BathroomDetailView(bathroom: bathroom)
            }
        }
        // Add sheet from + button
        .sheet(isPresented: $viewModel.showAddBathroom) {
            AddBathroomView()
        }
    }
}

// MARK: - Route Info Card

struct RouteInfoCard: View {
    @EnvironmentObject var viewModel: BathroomViewModel
    let destination: Bathroom

    var etaText: String {
        let minutes = Int(viewModel.routeETA / 60)
        guard minutes > 0 else { return "< 1 min" }
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60; let m = minutes % 60
        return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
    }

    var distanceText: String {
        if viewModel.routeDistance < 1000 {
            return "\(Int(viewModel.routeDistance)) m"
        }
        return String(format: "%.1f km", viewModel.routeDistance / 1000)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(destination.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text("Walking directions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    viewModel.clearRoute()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 0) {
                RouteStatView(icon: "clock.fill",   color: .blue,   label: "ETA",      value: etaText)
                Divider().frame(height: 36)
                RouteStatView(icon: "figure.walk",  color: .green,  label: "Distance", value: distanceText)
                Divider().frame(height: 36)
                RouteStatView(icon: "flame.fill",   color: .orange, label: "Calories", value: "~\(viewModel.routeCalories) kcal")
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
    }
}

struct RouteStatView: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Map Pin

struct BathroomMapPin: View {
    let bathroom: Bathroom
    let action: () -> Void

    var pinColor: Color {
        if bathroom.isFavorite { return .pink }
        switch bathroom.fee {
        case .free:    return .green
        case .paid:    return .orange
        case .unknown: return .blue
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(pinColor)
                        .frame(width: 38, height: 38)
                        .shadow(color: pinColor.opacity(0.4), radius: 4, y: 2)
                    Image(systemName: bathroom.isFavorite ? "heart.fill" : "toilet")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Image(systemName: "triangle.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(pinColor)
                    .rotationEffect(.degrees(180))
                    .offset(y: -2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter Bar

struct FilterBarView: View {
    @EnvironmentObject var viewModel: BathroomViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(title: "Free",          systemImage: "dollarsign.circle.fill", isActive: viewModel.filterFreeOnly)       { viewModel.filterFreeOnly.toggle() }
                FilterChip(title: "Accessible",    systemImage: "figure.roll",            isActive: viewModel.filterAccessibleOnly) { viewModel.filterAccessibleOnly.toggle() }
                FilterChip(title: "Gender Neutral",systemImage: "person.2.fill",          isActive: viewModel.filterGenderNeutral)  { viewModel.filterGenderNeutral.toggle() }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(.thinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }
}

struct FilterChip: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isActive ? Color.green : Color.clear)
                .foregroundStyle(isActive ? .white : .primary)
                .clipShape(Capsule())
                .animation(.easeInOut(duration: 0.15), value: isActive)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Circle Button

struct CircleButton: View {
    let systemImage: String
    let tint: Color
    let background: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(background)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }
}

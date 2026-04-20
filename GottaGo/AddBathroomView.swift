import SwiftUI
import MapKit
import CoreLocation

// MARK: - Location Picker

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var coordinate: CLLocationCoordinate2D

    @State private var cameraPosition: MapCameraPosition
    @State private var pickedCoordinate: CLLocationCoordinate2D

    init(coordinate: Binding<CLLocationCoordinate2D>) {
        _coordinate = coordinate
        let initial = coordinate.wrappedValue
        _pickedCoordinate = State(initialValue: initial)
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: initial,
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        )))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        Annotation("", coordinate: pickedCoordinate, anchor: .bottom) {
                            VStack(spacing: 0) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.red)
                                    .shadow(radius: 3)
                                Image(systemName: "triangle.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.red)
                                    .rotationEffect(.degrees(180))
                                    .offset(y: -3)
                            }
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)
                    // Tap anywhere on the map to move the pin
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                if let coord = proxy.convert(value.location, from: .local) {
                                    withAnimation(.spring(response: 0.3)) {
                                        pickedCoordinate = coord
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                    )
                }

                // Instruction banner
                VStack {
                    Text("Tap the map to place the pin")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.1), radius: 4)
                        .padding(.top, 12)
                    Spacer()

                    // Coordinate readout
                    Text(String(format: "%.5f,  %.5f", pickedCoordinate.latitude, pickedCoordinate.longitude))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 20)
                }
            }
            .navigationTitle("Pick Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        coordinate = pickedCoordinate
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
                }
            }
        }
    }
}

// MARK: - Add Bathroom

struct AddBathroomView: View {
    @EnvironmentObject var viewModel: BathroomViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var address = ""
    @State private var type: BathroomType = .publicFacility
    @State private var fee: FeeType = .free
    @State private var isAccessible = false
    @State private var isGenderNeutral = false
    @State private var requiresPurchase = false
    @State private var accessCode = ""
    @State private var notes = ""
    @State private var hours = ""
    @State private var useCurrentLocation: Bool
    @State private var pickedCoordinate: CLLocationCoordinate2D
    @State private var showLocationPicker = false
    @State private var showLocationError = false
    @State private var shareWithRefuge = false
    @State private var refugeStatus: RefugeSubmitStatus = .idle

    enum RefugeSubmitStatus { case idle, submitting, success, failed }

    init(prefilledCoordinate: CLLocationCoordinate2D? = nil) {
        if let coord = prefilledCoordinate {
            _useCurrentLocation = State(initialValue: false)
            _pickedCoordinate = State(initialValue: coord)
        } else {
            _useCurrentLocation = State(initialValue: true)
            _pickedCoordinate = State(initialValue: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060))
        }
    }

    var coordinatesReady: Bool {
        if useCurrentLocation { return viewModel.userLocation != nil }
        return true  // pickedCoordinate always holds a valid value
    }

    var formIsValid: Bool { !name.isEmpty && !address.isEmpty && coordinatesReady }

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Basic Info
                Section("Basic Info") {
                    TextField("Name *", text: $name)
                    TextField("Address / Landmark *", text: $address)
                    Picker("Category", selection: $type) {
                        ForEach(BathroomType.allCases, id: \.self) { t in
                            Label(t.displayName, systemImage: t.icon).tag(t)
                        }
                    }
                }

                // MARK: Location
                Section {
                    Toggle("Use my current location", isOn: $useCurrentLocation)

                    if !useCurrentLocation {
                        // Map preview showing current pin
                        Map(position: .constant(.region(MKCoordinateRegion(
                            center: pickedCoordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                        )))) {
                            Annotation("", coordinate: pickedCoordinate, anchor: .bottom) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.red)
                            }
                        }
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(true)
                        .allowsHitTesting(false)
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Selected pin")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.5f,  %.5f",
                                            pickedCoordinate.latitude,
                                            pickedCoordinate.longitude))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.primary)
                            }
                            Spacer()
                            Button("Move Pin") {
                                showLocationPicker = true
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                        }
                    } else if viewModel.userLocation == nil {
                        Label("Location unavailable — enable Location Services", systemImage: "location.slash.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Label("Will use your current GPS position", systemImage: "location.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                } header: {
                    HStack {
                        Text("Location")
                        if !useCurrentLocation {
                            Spacer()
                            Text("Long-press the map to change")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: Cost & Access
                Section {
                    Picker("Fee", selection: $fee) {
                        ForEach(FeeType.allCases, id: \.self) { f in
                            Text(f.displayName).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Wheelchair Accessible", isOn: $isAccessible)
                    Toggle("Gender Neutral / All-Gender", isOn: $isGenderNeutral)
                    Toggle("Purchase Required to Use", isOn: $requiresPurchase)

                    if requiresPurchase || fee == .paid {
                        TextField("Access Code (if known)", text: $accessCode)
                    }
                } header: { Text("Cost & Access") }

                // MARK: Hours & Notes
                Section("Hours") {
                    TextField("e.g. 8 AM – 10 PM  or  24 hours", text: $hours)
                }
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }

                // MARK: Community Contribution
                Section {
                    Toggle("Share with Refuge Restrooms", isOn: $shareWithRefuge)
                        .onChange(of: isGenderNeutral) { _, val in
                            if val { shareWithRefuge = true }
                        }
                    if shareWithRefuge {
                        Text("Submits to refugerestrooms.org — a worldwide community database of gender-neutral and accessible restrooms.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if refugeStatus == .submitting {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.8)
                            Text("Submitting to Refuge Restrooms…")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } else if refugeStatus == .success {
                        Label("Submitted to Refuge Restrooms!", systemImage: "checkmark.circle.fill")
                            .font(.caption).foregroundStyle(.green)
                    } else if refugeStatus == .failed {
                        Label("Submission failed — saved locally only.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                } header: { Text("Community") }
            }
            .navigationTitle("Add a Restroom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { submit() }
                        .fontWeight(.semibold)
                        .disabled(!formIsValid)
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView(coordinate: $pickedCoordinate)
            }
            .alert("Location Unavailable", isPresented: $showLocationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Enable Location Services in Settings, or toggle off 'Use my current location' and pin the spot on the map.")
            }
            .onAppear {
                // If opened without a prefilled coord and user toggled to manual,
                // seed the picked coord from user location if available
                if useCurrentLocation, let loc = viewModel.userLocation {
                    pickedCoordinate = loc
                }
            }
        }
    }

    private func submit() {
        let lat: Double
        let lon: Double

        if useCurrentLocation {
            guard let loc = viewModel.userLocation else {
                showLocationError = true
                return
            }
            lat = loc.latitude
            lon = loc.longitude
        } else {
            lat = pickedCoordinate.latitude
            lon = pickedCoordinate.longitude
        }

        let bathroom = Bathroom(
            name: name.trimmingCharacters(in: .whitespaces),
            address: address.trimmingCharacters(in: .whitespaces),
            latitude: lat,
            longitude: lon,
            type: type,
            fee: fee,
            isAccessible: isAccessible,
            isGenderNeutral: isGenderNeutral,
            requiresPurchase: requiresPurchase,
            accessCode: accessCode.isEmpty ? nil : accessCode,
            notes: notes,
            hours: hours,
            isVerified: false,
            dateAdded: Date(),
            reviews: []
        )
        viewModel.addBathroom(bathroom)

        guard shareWithRefuge else {
            dismiss()
            return
        }

        // Submit to Refuge Restrooms in the foreground so the user sees feedback
        refugeStatus = .submitting
        Task {
            let success = await ToiletDataService.submitToRefugeRestrooms(bathroom)
            refugeStatus = success ? .success : .failed
            // Auto-dismiss after a short pause so the status is visible
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        }
    }
}

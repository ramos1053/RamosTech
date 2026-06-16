import SwiftUI
import MapKit

// MARK: - Toilet Rating Views (shared across the app)

/// Displays 1–5 toilet icons. Color shifts red → orange → yellow → green with rating.
struct ToiletsView: View {
    let rating: Double
    var iconFont: Font = .caption

    private func activeColor() -> Color {
        switch rating.rounded() {
        case 1:  return .red
        case 2:  return .orange
        case 3:  return .yellow
        case 4:  return Color(hue: 0.28, saturation: 0.85, brightness: 0.75)
        default: return .green
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: "toilet")
                    .font(iconFont)
                    .foregroundStyle(Double(i) <= rating.rounded()
                                     ? activeColor()
                                     : Color.secondary.opacity(0.22))
            }
        }
    }
}

/// Interactive toilet picker for review forms.
struct ToiletRatingPicker: View {
    let label: String
    @Binding var rating: Double

    private func color(for r: Double) -> Color {
        switch r.rounded() {
        case 1:  return .red
        case 2:  return .orange
        case 3:  return .yellow
        case 4:  return Color(hue: 0.28, saturation: 0.85, brightness: 0.75)
        default: return .green
        }
    }

    private var ratingWord: String {
        switch Int(rating.rounded()) {
        case 1:  return "Avoid"
        case 2:  return "Poor"
        case 3:  return "OK"
        case 4:  return "Good"
        default: return "Excellent"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(ratingWord)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color(for: rating))
                    .animation(.easeInOut(duration: 0.15), value: rating)
            }

            HStack(spacing: 0) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            rating = Double(i)
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: "toilet")
                                .font(.system(size: 30))
                                .foregroundStyle(Double(i) <= rating.rounded()
                                                 ? color(for: rating)
                                                 : Color.secondary.opacity(0.2))
                                .scaleEffect(Double(i) <= rating.rounded() ? 1.08 : 0.88)
                                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: rating)
                            Text("\(i)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Bathroom Detail

struct BathroomDetailView: View {
    @EnvironmentObject var viewModel: BathroomViewModel
    @Environment(\.dismiss) private var dismiss
    let bathroom: Bathroom

    @State private var showAddReview = false
    @State private var showDeleteConfirm = false
    @State private var miniMapPosition: MapCameraPosition
    @State private var photos: [URL] = []
    @State private var isLoadingPhotos = false

    init(bathroom: Bathroom) {
        self.bathroom = bathroom
        _miniMapPosition = State(initialValue: .region(MKCoordinateRegion(
            center: bathroom.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
        )))
    }

    var isFavorite: Bool { viewModel.isFavorite(bathroom) }

    var feeColor: Color {
        switch bathroom.fee {
        case .free:    return .green
        case .paid:    return .orange
        case .unknown: return .blue
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: Mini Map
                    Map(position: .constant(miniMapPosition)) {
                        Annotation(bathroom.name, coordinate: bathroom.coordinate, anchor: .bottom) {
                            ZStack {
                                Circle()
                                    .fill(feeColor)
                                    .frame(width: 34, height: 34)
                                    .shadow(radius: 3)
                                Image(systemName: "toilet")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .frame(height: 190)
                    .disabled(true)
                    .allowsHitTesting(false)

                    // MARK: Photo Strip (Mapillary nearby imagery)
                    if !photos.isEmpty || isLoadingPhotos {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                if isLoadingPhotos && photos.isEmpty {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.secondarySystemBackground))
                                        .frame(width: 200, height: 130)
                                        .overlay(ProgressView())
                                }
                                ForEach(Array(photos.enumerated()), id: \.offset) { _, url in
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        case .empty:
                                            Color(.secondarySystemBackground)
                                                .overlay(ProgressView())
                                        case .failure:
                                            Color(.secondarySystemBackground)
                                                .overlay(Image(systemName: "photo.slash")
                                                    .foregroundStyle(.secondary))
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                    .frame(width: 200, height: 130)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(height: 130)
                        .padding(.vertical, 8)
                    }

                    VStack(alignment: .leading, spacing: 18) {

                        // MARK: Header
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(bathroom.name)
                                        .font(.title2.bold())
                                    Text(bathroom.address)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if bathroom.isVerified {
                                    Label("Verified", systemImage: "checkmark.seal.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.green)
                                        .padding(.top, 2)
                                }
                            }

                            if !bathroom.reviews.isEmpty {
                                HStack(spacing: 8) {
                                    ToiletsView(rating: bathroom.averageRating)
                                    Text(String(format: "%.1f", bathroom.averageRating))
                                        .font(.subheadline.bold())
                                    Text("(\(bathroom.reviews.count) review\(bathroom.reviews.count == 1 ? "" : "s"))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // MARK: Info Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            InfoTile(icon: "dollarsign.circle.fill", color: feeColor,
                                     title: "Cost", value: bathroom.fee.displayName)
                            InfoTile(icon: "clock.fill", color: .indigo,
                                     title: "Hours",
                                     value: bathroom.hours.isEmpty ? "Unknown" : bathroom.hours)
                            InfoTile(icon: "figure.roll",
                                     color: bathroom.isAccessible ? .blue : .gray,
                                     title: "Accessible",
                                     value: bathroom.isAccessible ? "Yes" : "No")
                            InfoTile(icon: "person.2.fill",
                                     color: bathroom.isGenderNeutral ? .purple : .gray,
                                     title: "Gender Neutral",
                                     value: bathroom.isGenderNeutral ? "Yes" : "No")
                        }

                        // MARK: Badges
                        if bathroom.requiresPurchase {
                            BannerRow(icon: "bag.fill", color: .orange,
                                      text: "Purchase required to use restroom")
                        }
                        if let code = bathroom.accessCode, !code.isEmpty {
                            BannerRow(icon: "lock.fill", color: .yellow,
                                      text: "Access code: \(code)")
                        }

                        // Avg cleanliness
                        if !bathroom.reviews.isEmpty {
                            HStack {
                                Label("Avg. Cleanliness", systemImage: "sparkles")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                ToiletsView(rating: bathroom.averageCleanliness)
                                Text(String(format: "%.1f", bathroom.averageCleanliness))
                                    .font(.subheadline.bold())
                            }
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Notes
                        if !bathroom.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Notes", systemImage: "note.text")
                                    .font(.headline)
                                Text(bathroom.notes)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider()

                        // MARK: Reviews
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Reviews")
                                    .font(.headline)
                                Spacer()
                                Button {
                                    showAddReview = true
                                } label: {
                                    Label("Write a Review", systemImage: "square.and.pencil")
                                        .font(.subheadline)
                                        .foregroundStyle(.green)
                                }
                            }

                            if bathroom.reviews.isEmpty {
                                Text("No reviews yet — be the first!")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 4)
                            } else {
                                ForEach(bathroom.reviews) { review in
                                    ReviewRowView(review: review)
                                }
                            }
                        }

                        // MARK: Action Buttons
                        HStack(spacing: 12) {
                            Button {
                                openInMaps()
                            } label: {
                                Label("Directions", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(14)
                                    .background(Color.green)
                                    .foregroundStyle(.white)
                                    .font(.headline)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)

                            Button {
                                dismiss()
                                Task { await viewModel.calculateRoute(to: bathroom) }
                            } label: {
                                Label("Route", systemImage: "map.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(14)
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .font(.headline)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Restroom Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if viewModel.isLocalBathroom(bathroom) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.title3)
                                .foregroundStyle(.red)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.toggleFavorite(bathroom)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.title3)
                            .foregroundStyle(.red)
                            .symbolEffect(.bounce, value: isFavorite)
                    }
                }
            }
            .confirmationDialog(
                "Delete \"\(bathroom.name)\"?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Entry", role: .destructive) {
                    viewModel.deleteBathroom(bathroom)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove this restroom from your list.")
            }
            .sheet(isPresented: $showAddReview) {
                AddReviewView(bathroom: bathroom)
            }
            .task {
                isLoadingPhotos = true
                photos = await viewModel.loadPhotos(for: bathroom)
                isLoadingPhotos = false
            }
        }
    }

    func openInMaps() {
        let placemark = MKPlacemark(coordinate: bathroom.coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = bathroom.name
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
}

// MARK: - Supporting Views

struct InfoTile: View {
    let icon: String
    let color: Color
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: icon).foregroundStyle(color).font(.footnote)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Text(value).font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct BannerRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(color)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ReviewRowView: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(review.authorName).font(.subheadline.bold())
                Spacer()
                ToiletsView(rating: review.rating)
            }
            HStack {
                Label("Cleanliness  \(String(format: "%.1f", review.cleanliness))/5",
                      systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(review.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if !review.comment.isEmpty {
                Text(review.comment)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Add Review

struct AddReviewView: View {
    @EnvironmentObject var viewModel: BathroomViewModel
    @Environment(\.dismiss) private var dismiss
    let bathroom: Bathroom

    @State private var authorName  = ""
    @State private var rating      = 3.0
    @State private var cleanliness = 3.0
    @State private var comment     = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Name") {
                    TextField("Anonymous", text: $authorName)
                }

                Section {
                    ToiletRatingPicker(label: "Overall rating", rating: $rating)
                        .padding(.vertical, 4)
                } header: { Text("Overall Rating") }

                Section {
                    ToiletRatingPicker(label: "How clean was it?", rating: $cleanliness)
                        .padding(.vertical, 4)
                } header: { Text("Cleanliness") }

                Section("Comments") {
                    TextEditor(text: $comment)
                        .frame(minHeight: 90)
                }
            }
            .navigationTitle("Write a Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        let review = Review(
                            authorName: authorName.isEmpty ? "Anonymous" : authorName,
                            rating: rating,
                            cleanliness: cleanliness,
                            comment: comment,
                            date: Date()
                        )
                        viewModel.addReviewToAnyBathroom(review, to: bathroom)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

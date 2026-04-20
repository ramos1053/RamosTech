import SwiftUI

// MARK: - Grab Handle

/// A 2 × 3 dot-grid texture that signals "this row is draggable."
/// Only rendered when there are favorites in the list.
struct GrabHandle: View {
    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 4) {
                    ForEach(0..<2, id: \.self) { _ in
                        Circle()
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 4.5, height: 4.5)
                    }
                }
            }
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - Favorites View

struct FavoritesView: View {
    @EnvironmentObject var viewModel: BathroomViewModel
    @State private var selectedBathroom: Bathroom?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.favorites.isEmpty {
                    ContentUnavailableView {
                        Label("No Favorites Yet", systemImage: "heart.slash")
                    } description: {
                        Text("Tap the ♥ button on any restroom to save it here for quick access and one-tap routing.")
                    }
                } else {
                    List {
                        ForEach(viewModel.favorites) { bathroom in
                            FavoriteRowView(bathroom: bathroom, showHandle: true)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 8))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedBathroom = bathroom }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        viewModel.toggleFavorite(bathroom)
                                    } label: {
                                        Label("Remove", systemImage: "heart.slash.fill")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    if viewModel.isLocalBathroom(bathroom) {
                                        Button(role: .destructive) {
                                            viewModel.deleteBathroom(bathroom)
                                        } label: {
                                            Label("Delete", systemImage: "trash.fill")
                                        }
                                    }
                                }
                        }
                        .onMove(perform: viewModel.moveFavorites)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    // Keep edit mode always active so reorder handles are always visible
                    .environment(\.editMode, .constant(.active))
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !viewModel.favorites.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Label("Drag to reorder", systemImage: "arrow.up.arrow.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(item: $selectedBathroom) { bathroom in
                BathroomDetailView(bathroom: bathroom)
            }
        }
    }
}

// MARK: - Favorite Row

struct FavoriteRowView: View {
    @EnvironmentObject var viewModel: BathroomViewModel
    let bathroom: Bathroom
    var showHandle: Bool = false

    var body: some View {
        HStack(spacing: 0) {

            // Drag-texture handle (leading edge, only when list has entries)
            if showHandle {
                GrabHandle()
                    .padding(.trailing, 6)
            }

            // Heart icon tile
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "heart.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.red)
            }
            .padding(.trailing, 12)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(bathroom.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(bathroom.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(bathroom.fee.displayName, systemImage: "dollarsign.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(bathroom.fee == .free ? .green : .orange)

                    if bathroom.averageRating > 0 {
                        ToiletsView(rating: bathroom.averageRating,
                                    iconFont: .system(size: 9))
                        Text(String(format: "%.1f", bathroom.averageRating))
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }
                }

                if let dist = viewModel.distance(to: bathroom) {
                    Text(dist)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Route button
            Button {
                viewModel.startRouteFromFavorites(to: bathroom)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.green)
                    Text("Route")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                }
                .frame(width: 48)
            }
            .buttonStyle(.plain)
            // Prevent row tap from firing when Route is tapped
            .simultaneousGesture(TapGesture().onEnded {})
        }
        .padding(.vertical, 10)
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

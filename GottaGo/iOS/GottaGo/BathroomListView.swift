import SwiftUI

struct BathroomListView: View {
    @EnvironmentObject var viewModel: BathroomViewModel
    @State private var selectedBathroom: Bathroom?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.sortedByDistance.isEmpty {
                    ContentUnavailableView(
                        "No Bathrooms Found",
                        systemImage: "toilet",
                        description: Text("Try adjusting your filters or tap + to add one.")
                    )
                } else {
                    List {
                        ForEach(viewModel.sortedByDistance) { bathroom in
                            BathroomRowView(bathroom: bathroom)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedBathroom = bathroom }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if viewModel.isLocalBathroom(bathroom) {
                                        Button(role: .destructive) {
                                            viewModel.deleteBathroom(bathroom)
                                        } label: {
                                            Label("Delete", systemImage: "trash.fill")
                                        }
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Nearby Bathrooms")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchText, prompt: "Search by name or address…")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showAddBathroom = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    FilterMenuButton()
                }
            }
            .sheet(item: $selectedBathroom) { bathroom in
                BathroomDetailView(bathroom: bathroom)
            }
            .sheet(isPresented: $viewModel.showAddBathroom) {
                AddBathroomView()
            }
        }
    }
}

// MARK: - Filter Menu

struct FilterMenuButton: View {
    @EnvironmentObject var viewModel: BathroomViewModel

    var activeCount: Int {
        [viewModel.filterFreeOnly,
         viewModel.filterAccessibleOnly,
         viewModel.filterGenderNeutral].filter { $0 }.count
    }

    var body: some View {
        Menu {
            Toggle("Free Only",          isOn: $viewModel.filterFreeOnly)
            Toggle("Accessible Only",    isOn: $viewModel.filterAccessibleOnly)
            Toggle("Gender Neutral Only",isOn: $viewModel.filterGenderNeutral)
        } label: {
            Label("Filter",
                  systemImage: activeCount > 0
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
                .foregroundStyle(activeCount > 0 ? .green : .primary)
        }
    }
}

// MARK: - Bathroom Row

struct BathroomRowView: View {
    @EnvironmentObject var viewModel: BathroomViewModel
    let bathroom: Bathroom

    var feeColor: Color {
        switch bathroom.fee {
        case .free:    return .green
        case .paid:    return .orange
        case .unknown: return .blue
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon tile
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(feeColor.opacity(0.14))
                    .frame(width: 54, height: 54)
                Image(systemName: "toilet")
                    .font(.system(size: 24))
                    .foregroundStyle(feeColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(bathroom.name).font(.headline).lineLimit(1)
                    if bathroom.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    if bathroom.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Text(bathroom.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(bathroom.fee.displayName, systemImage: "dollarsign.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(feeColor)
                    if bathroom.isAccessible {
                        Image(systemName: "figure.roll").font(.caption2).foregroundStyle(.blue)
                    }
                    if bathroom.isGenderNeutral {
                        Image(systemName: "person.2.fill").font(.caption2).foregroundStyle(.purple)
                    }
                    if bathroom.requiresPurchase {
                        Image(systemName: "bag.fill").font(.caption2).foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if bathroom.averageRating > 0 {
                    ToiletsView(rating: bathroom.averageRating, iconFont: .system(size: 9))
                    Text(String(format: "%.1f", bathroom.averageRating))
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                if let dist = viewModel.distance(to: bathroom) {
                    Text(dist).font(.caption2).foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

import SwiftUI

struct OpenEventView: View {
    @Environment(ProfileStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.profiles.isEmpty {
                    ContentUnavailableView(
                        "No Events",
                        systemImage: "calendar.badge.plus",
                        description: Text("Create a new event from the menu.")
                    )
                } else {
                    List {
                        ForEach(store.profiles) { profile in
                            Button {
                                store.openEvent(profile)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(profile.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(profile.sport)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if store.selectedProfile?.id == profile.id && !store.isEventClosed {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { store.delete(profile: store.profiles[$0]) }
                        }
                    }
                }
            }
            .navigationTitle("Open Event")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }
                #endif
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

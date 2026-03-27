import SwiftUI

struct ProfilePickerView: View {
    @Environment(ProfileStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showNewProfile = false
    @State private var newName = ""
    @State private var newSport = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.profiles) { profile in
                    Button {
                        store.selectedProfile = profile
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name).font(.headline).foregroundStyle(.primary)
                                Text(profile.sport).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.selectedProfile?.id == profile.id {
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

                Button {
                    showNewProfile = true
                } label: {
                    Label("New Profile", systemImage: "plus")
                }
            }
            .navigationTitle("Sport Profiles")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }
                #endif
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .alert("New Profile", isPresented: $showNewProfile) {
            TextField("Profile name", text: $newName)
            TextField("Sport", text: $newSport)
            Button("Create") {
                guard !newName.isEmpty else { return }
                _ = store.createNew(name: newName, sport: newSport.isEmpty ? newName : newSport)
                newName = ""; newSport = ""
                dismiss()
            }
            Button("Cancel", role: .cancel) { newName = ""; newSport = "" }
        }
    }
}

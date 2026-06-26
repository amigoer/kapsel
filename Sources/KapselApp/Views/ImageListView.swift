import SwiftUI
import AppKit
import KapselKit

/// Image management view supporting pulling, building, deleting, tagging, pushing, and pruning OCI images
struct ImageListView: View {
    @Environment(ImagesStore.self) private var store
    @State private var isRefreshing = false
    @State private var successMessage: String?

    @State private var selectedImageId: String?
    @State private var imageNamePull = ""
    @State private var isPulling = false

    @State private var isShowingBuildSheet = false
    @State private var buildTagName = ""
    @State private var buildContextPath = ""
    @State private var buildArch = ""
    @State private var buildDockerfilePath = ""
    @State private var buildArgs: [BuildArg] = []
    @State private var isBuilding = false

    @State private var imageToTag: ContainerImage?
    @State private var newTagName = ""
    @State private var showTagAlert = false
    @State private var imageToDelete: ContainerImage?
    @State private var showDeleteConfirmation = false
    @State private var showPruneConfirmation = false

    struct BuildArg: Identifiable {
        let id = UUID()
        var key = ""
        var value = ""
    }

    var body: some View {
        Group {
            if !store.hasLoaded {
                ProgressView("Loading image list...")
            } else if store.images.isEmpty {
                ContentUnavailableView {
                    Label("No Local Images", systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text("Enter an image name above to Pull, or click 'Build Image' to compile locally.")
                } actions: {
                    Button("Build Image") { isShowingBuildSheet = true }
                }
            } else {
                imagesTable
            }
        }
        .navigationTitle("Images")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                TextField("Enter image name to pull, e.g. nginx:latest", text: $imageNamePull)
                    .frame(minWidth: 220, maxWidth: 320)
                    .disabled(isPulling)
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await pullImage() }
                } label: {
                    if isPulling {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Pull Image", systemImage: "arrow.down.circle")
                    }
                }
                .disabled(imageNamePull.isEmpty || isPulling)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingBuildSheet = true
                } label: {
                    Label("Build Image", systemImage: "hammer")
                }
                .disabled(isBuilding)
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    showPruneConfirmation = true
                } label: {
                    Label("Prune Unused", systemImage: "paintbrush")
                }
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await loadImages() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .alert("Success", isPresented: Binding(
            get: { successMessage != nil },
            set: { if !$0 { successMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(successMessage ?? "")
        }
        .confirmationDialog(String(localized: "Confirm Deletion"), isPresented: $showDeleteConfirmation) {
            Button(String(localized: "Delete"), role: .destructive) {
                if let image = imageToDelete {
                    Task { await deleteImage(image) }
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) { imageToDelete = nil }
        } message: {
            Text(String(localized: "Are you sure you want to delete image \"\(imageToDelete?.fullName ?? "")\"? This action cannot be undone."))
        }
        .confirmationDialog(String(localized: "Confirm Pruning"), isPresented: $showPruneConfirmation) {
            Button(String(localized: "Prune"), role: .destructive) {
                Task { await pruneImages() }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "This action will remove all local images not currently used by any containers. Do you want to proceed?"))
        }
        .alert(String(localized: "Tag Image"), isPresented: $showTagAlert) {
            TextField(String(localized: "New tag (e.g. myapp:v2)"), text: $newTagName)
            Button(String(localized: "OK")) {
                if let image = imageToTag, !newTagName.isEmpty {
                    Task { await tagImage(image, newTag: newTagName) }
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "Enter a new tag name for \(imageToTag?.fullName ?? "")"))
        }
        .sheet(isPresented: $isShowingBuildSheet) {
            buildSheet
        }
        .onAppear {
            Task { await loadImages() }
        }
    }

    private var imagesTable: some View {
        Table(store.images, selection: $selectedImageId) {
            TableColumn("Repository") { image in
                Label(image.repository, systemImage: "photo.stack")
            }
            TableColumn("Tag") { image in
                Text(image.tag)
            }
            TableColumn("Platform") { image in
                Text([image.os, image.arch].compactMap { $0 }.joined(separator: "/"))
            }
            TableColumn("Size") { image in
                Text(image.size ?? "--")
            }
            TableColumn("Digest") { image in
                Text(image.digest)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            TableColumn("Actions") { image in
                HStack {
                    Button { imageToTag = image; newTagName = ""; showTagAlert = true } label: {
                        Image(systemName: "tag")
                    }
                    Button { Task { await pushImage(image) } } label: {
                        Image(systemName: "arrow.up.circle")
                    }
                    Button { imageToDelete = image; showDeleteConfirmation = true } label: {
                        Image(systemName: "trash")
                    }
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var buildSheet: some View {
        NavigationStack {
            Form {
                Section("Build Configurations") {
                    TextField("Image Tag", text: $buildTagName, prompt: Text("e.g. my-custom-app:1.0"))
                    HStack {
                        TextField("Dockerfile Context Path", text: $buildContextPath)
                        Button("Browse...") { selectBuildContextFolder() }
                    }
                }
                Section("Advanced Options") {
                    TextField("Target Architecture", text: $buildArch, prompt: Text("e.g. arm64 (empty for default)"))
                    HStack {
                        TextField("Dockerfile Path", text: $buildDockerfilePath, prompt: Text("empty for default Dockerfile"))
                        Button("Browse...") { selectDockerfile() }
                    }
                }
                Section("Build Arguments (Build Args)") {
                    ForEach($buildArgs) { $arg in
                        HStack {
                            TextField("Name", text: $arg.key)
                            TextField("Value", text: $arg.value)
                            Button { buildArgs.removeAll { $0.id == arg.id } } label: {
                                Image(systemName: "minus.circle")
                            }
                        }
                    }
                    Button("Add Build Argument") { buildArgs.append(BuildArg()) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Build Local OCI Image")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isShowingBuildSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Build") { Task { await buildImage() } }
                        .disabled(buildTagName.isEmpty || buildContextPath.isEmpty || isBuilding)
                }
            }
            .frame(width: 550, height: 450)
        }
    }

    private func loadImages() async {
        isRefreshing = true
        await store.load()
        isRefreshing = false
    }

    private func pullImage() async {
        isPulling = true
        store.errorMessage = nil
        do {
            try await ImageService.shared.pullImage(name: imageNamePull)
            imageNamePull = ""
            await loadImages()
        } catch {
            store.errorMessage = error.localizedDescription
        }
        isPulling = false
    }

    private func deleteImage(_ image: ContainerImage) async {
        do {
            try await ImageService.shared.deleteImage(digest: image.digest)
            imageToDelete = nil
            await loadImages()
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private func tagImage(_ image: ContainerImage, newTag: String) async {
        do {
            try await ImageService.shared.tagImage(source: image.fullName, target: newTag)
            successMessage = String(localized: "Tag \(newTag) successfully created.")
            await loadImages()
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private func pushImage(_ image: ContainerImage) async {
        do {
            try await ImageService.shared.pushImage(name: image.fullName)
            successMessage = String(localized: "Image \(image.fullName) successfully pushed.")
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private func pruneImages() async {
        do {
            try await ImageService.shared.pruneImages()
            successMessage = String(localized: "Unused images successfully pruned.")
            await loadImages()
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private func selectBuildContextFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = String(localized: "Select directory containing Dockerfile")
        if panel.runModal() == .OK {
            buildContextPath = panel.url?.path ?? ""
        }
    }

    private func selectDockerfile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = String(localized: "Select Dockerfile")
        panel.allowedContentTypes = [.data]
        if panel.runModal() == .OK {
            buildDockerfilePath = panel.url?.path ?? ""
        }
    }

    private func buildImage() async {
        isShowingBuildSheet = false
        isBuilding = true
        let args: [String]? = buildArgs.isEmpty ? nil : buildArgs.compactMap { arg in
            guard !arg.key.isEmpty else { return nil }
            return "\(arg.key)=\(arg.value)"
        }
        do {
            try await ImageService.shared.buildImage(
                tag: buildTagName,
                buildContextPath: buildContextPath,
                arch: buildArch.isEmpty ? nil : buildArch,
                platform: nil,
                buildArgs: args,
                dockerfile: buildDockerfilePath.isEmpty ? nil : buildDockerfilePath
            )
            buildTagName = ""
            buildContextPath = ""
            buildArch = ""
            buildDockerfilePath = ""
            buildArgs = []
            await loadImages()
        } catch {
            store.errorMessage = error.localizedDescription
        }
        isBuilding = false
    }
}

#Preview {
    ImageListView()
        .environment(ImagesStore())
}

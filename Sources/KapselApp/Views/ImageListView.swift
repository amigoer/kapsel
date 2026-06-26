import SwiftUI
import KapselKit

/// Image management view supporting pulling, building, deleting, tagging, pushing, and pruning OCI images
struct ImageListView: View {
    @State private var images: [ContainerImage] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    
    // Selected image ID supporting selection and right-click context menu
    @State private var selectedImageId: String? = nil
    
    // Pull image form state
    @State private var imageNamePull: String = ""
    @State private var isPulling: Bool = false
    
    // Build image sheet state
    @State private var isShowingBuildSheet: Bool = false
    @State private var buildTagName: String = ""
    @State private var buildContextPath: String = ""
    @State private var buildArch: String = ""
    @State private var buildDockerfilePath: String = ""
    @State private var buildArgs: [BuildArg] = []
    @State private var isBuilding: Bool = false
    
    // Tag image state
    @State private var imageToTag: ContainerImage? = nil
    @State private var newTagName: String = ""
    @State private var showTagAlert: Bool = false
    
    // Delete image confirmation
    @State private var imageToDelete: ContainerImage? = nil
    @State private var showDeleteConfirmation: Bool = false
    
    // Prune images confirmation
    @State private var showPruneConfirmation: Bool = false
    
    /// Structure for custom build arguments
    struct BuildArg: Identifiable {
        let id = UUID()
        var key: String = ""
        var value: String = ""
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Action toolbar
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Images")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                // Pull forms
                HStack(spacing: 8) {
                    TextField("Enter image name to pull, e.g. nginx:latest", text: $imageNamePull)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 250)
                        .disabled(isPulling)
                    
                    Button(action: { Task { await pullImage() } }) {
                        if isPulling {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Pull Image")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(imageNamePull.isEmpty || isPulling)
                }
                
                Button(action: { isShowingBuildSheet = true }) {
                    Label("Build Image", systemImage: "hammer.fill")
                }
                .buttonStyle(.bordered)
                .disabled(isBuilding)
                
                // Prune unused local images
                Button(action: { showPruneConfirmation = true }) {
                    Label("Prune Unused", systemImage: "paintbrush")
                }
                .buttonStyle(.bordered)
                
                Button(action: { Task { await loadImages() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Image listing table
            if isLoading && images.isEmpty {
                Spacer()
                ProgressView("Loading image list...")
                Spacer()
            } else if images.isEmpty {
                ContentUnavailableView(
                    "No Local Images",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Enter an image name above to Pull, or click 'Build Image' to compile locally.")
                )
            } else {
                Table(images, selection: $selectedImageId) {
                    TableColumn("Repository") { image in
                        HStack(spacing: 8) {
                            Image(systemName: "photo.stack.fill")
                                .foregroundColor(.purple)
                            Text(image.repository)
                                .fontWeight(.medium)
                        }
                    }
                    .width(min: 150, ideal: 200, max: 250)
                    
                    TableColumn("Tag") { image in
                        Text(image.tag)
                            .foregroundColor(.secondary)
                    }
                    .width(min: 80, ideal: 100, max: 120)
                    
                    TableColumn("Platform") { image in
                        HStack(spacing: 2) {
                            if let os = image.os {
                                Text(os)
                            }
                            if let arch = image.arch {
                                Text("/\(arch)")
                            }
                            if image.os == nil && image.arch == nil {
                                Text("--")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .width(min: 80, ideal: 100, max: 120)
                    
                    TableColumn("Size") { image in
                        Text(image.size ?? "--")
                            .foregroundColor(.secondary)
                    }
                    .width(min: 60, ideal: 80, max: 100)
                    
                    TableColumn("Digest") { image in
                        Text(image.digest)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .width(min: 150, ideal: 200, max: 300)
                    
                    TableColumn("Actions") { image in
                        HStack(spacing: 8) {
                            Button(action: {
                                imageToTag = image
                                newTagName = ""
                                showTagAlert = true
                            }) {
                                Image(systemName: "tag")
                                    .foregroundColor(.blue)
                                    .help("Tag Image")
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: { Task { await pushImage(image) } }) {
                                Image(systemName: "arrow.up.circle")
                                    .foregroundColor(.green)
                                    .help("Push to Registry")
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                imageToDelete = image
                                showDeleteConfirmation = true
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .help("Delete Image")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .width(min: 100, ideal: 120, max: 140)
                }
                .contextMenu {
                    if let selectedId = selectedImageId, let image = images.first(where: { $0.id == selectedId }) {
                        Button("Tag Image...") {
                            imageToTag = image
                            newTagName = ""
                            showTagAlert = true
                        }
                        
                        Button("Push Image") {
                            Task { await pushImage(image) }
                        }
                        
                        Divider()
                        
                        Button("Delete Image") {
                            imageToDelete = image
                            showDeleteConfirmation = true
                        }
                    } else {
                        Text("No image selected")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Success", isPresented: Binding(
            get: { successMessage != nil },
            set: { if !$0 { successMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(successMessage ?? "")
        }
        .confirmationDialog("Confirm Deletion", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let image = imageToDelete {
                    Task { await deleteImage(image) }
                }
            }
            Button("Cancel", role: .cancel) { imageToDelete = nil }
        } message: {
            Text("Are you sure you want to delete image \"\(imageToDelete?.fullName ?? "")\"? This action cannot be undone.")
        }
        .confirmationDialog("Confirm Pruning", isPresented: $showPruneConfirmation) {
            Button("Prune", role: .destructive) {
                Task { await pruneImages() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action will remove all local images not currently used by any containers. Do you want to proceed?")
        }
        .alert("Tag Image", isPresented: $showTagAlert) {
            TextField("New tag (e.g. myapp:v2)", text: $newTagName)
            Button("OK") {
                if let image = imageToTag, !newTagName.isEmpty {
                    Task { await tagImage(image, newTag: newTagName) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a new tag name for \(imageToTag?.fullName ?? "")")
        }
        .sheet(isPresented: $isShowingBuildSheet) {
            NavigationStack {
                Form {
                    Section("Build Configurations") {
                        TextField("Image Tag", text: $buildTagName, prompt: Text("e.g. my-custom-app:1.0"))
                        
                        HStack {
                            TextField("Dockerfile Context Path", text: $buildContextPath)
                            Button("Browse...") {
                                selectBuildContextFolder()
                            }
                        }
                    }
                    
                    Section("Advanced Options") {
                        TextField("Target Architecture", text: $buildArch, prompt: Text("e.g. arm64 (empty for default)"))
                        
                        HStack {
                            TextField("Dockerfile Path", text: $buildDockerfilePath, prompt: Text("empty for default Dockerfile"))
                            Button("Browse...") {
                                selectDockerfile()
                            }
                        }
                    }
                    
                    Section("Build Arguments (Build Args)") {
                        ForEach($buildArgs) { $arg in
                            HStack(spacing: 8) {
                                TextField("Name", text: $arg.key)
                                    .textFieldStyle(.roundedBorder)
                                Text("=")
                                    .foregroundColor(.secondary)
                                TextField("Value", text: $arg.value)
                                    .textFieldStyle(.roundedBorder)
                                Button(action: {
                                    buildArgs.removeAll { $0.id == arg.id }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        Button(action: { buildArgs.append(BuildArg()) }) {
                            Label("Add Build Argument", systemImage: "plus.circle")
                        }
                    }
                }
                .formStyle(.grouped)
                .navigationTitle("Build Local OCI Image")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isShowingBuildSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Build") {
                            Task { await buildImage() }
                        }
                        .disabled(buildTagName.isEmpty || buildContextPath.isEmpty || isBuilding)
                    }
                }
                .frame(width: 550, height: 450)
            }
        }
        .onAppear {
            Task { await loadImages() }
        }
    }
    
    private func loadImages() async {
        isLoading = true
        errorMessage = nil
        do {
            images = try await ImageService.shared.fetchImages()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func pullImage() async {
        isPulling = true
        errorMessage = nil
        do {
            try await ImageService.shared.pullImage(name: imageNamePull)
            imageNamePull = ""
            await loadImages()
        } catch {
            errorMessage = error.localizedDescription
        }
        isPulling = false
    }
    
    private func deleteImage(_ image: ContainerImage) async {
        do {
            try await ImageService.shared.deleteImage(digest: image.digest)
            imageToDelete = nil
            await loadImages()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func tagImage(_ image: ContainerImage, newTag: String) async {
        do {
            try await ImageService.shared.tagImage(source: image.fullName, target: newTag)
            successMessage = "Tag \(newTag) successfully created."
            await loadImages()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func pushImage(_ image: ContainerImage) async {
        do {
            try await ImageService.shared.pushImage(name: image.fullName)
            successMessage = "Image \(image.fullName) successfully pushed."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func pruneImages() async {
        do {
            try await ImageService.shared.pruneImages()
            successMessage = "Unused images successfully pruned."
            await loadImages()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func selectBuildContextFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Select directory containing Dockerfile"
        
        if panel.runModal() == .OK {
            buildContextPath = panel.url?.path ?? ""
        }
    }
    
    private func selectDockerfile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Select Dockerfile"
        panel.allowedContentTypes = [.data]
        
        if panel.runModal() == .OK {
            buildDockerfilePath = panel.url?.path ?? ""
        }
    }
    
    private func buildImage() async {
        isShowingBuildSheet = false
        isLoading = true
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
            errorMessage = error.localizedDescription
        }
        isBuilding = false
        isLoading = false
    }
}

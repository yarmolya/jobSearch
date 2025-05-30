import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage
import UniformTypeIdentifiers
import QuickLook

struct CVUploadView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var isFilePickerPresenting = false
    @State private var selectedFileURL: URL?
    @State private var fileName: String = ""
    @State private var uploadedFileName: String?
    @State private var uploadProgress: Double = 0
    @State private var isUploading = false
    @State private var showingPreview = false
    @State private var uploadedCVURL: String?
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    
                    if let selectedFileURL = selectedFileURL {
                        filePreviewSection(fileURL: selectedFileURL)
                    } else if let uploadedURL = uploadedCVURL {
                        currentCVSection(fileURL: uploadedURL)
                    } else {
                        noFileSection
                    }
                    
                    uploadButtonSection
                    
                    informationSection
                }
                .padding()
            }
            .navigationTitle("CV Management".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done".localized()) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                fetchCurrentCV()
            }
            .sheet(isPresented: $isFilePickerPresenting) {
                DocumentPicker(fileURL: $selectedFileURL, fileName: $fileName)
            }
            .sheet(isPresented: $showingPreview) {
                if let selectedFileURL = selectedFileURL {
                    NavigationStack {
                        QuickLookPreview(url: selectedFileURL)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Done".localized()) {
                                        showingPreview = false
                                    }
                                }
                            }
                    }
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // MARK: - View Components
    
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Upload Your CV".localized())
                .font(.title2)
                .fontWeight(.bold)
                
            Text("Upload your CV to make applying for jobs faster and easier. Supported formats: PDF, DOC, DOCX.".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 10)
    }
    
    var noFileSection: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(height: 180)
                
                VStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    
                    Text("No file selected".localized())
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Button {
                        isFilePickerPresenting = true
                    } label: {
                        Text("Select File".localized())
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }
    
    func filePreviewSection(fileURL: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected File".localized())
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    fileTypeIcon(for: fileURL)
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(fileName)
                            .font(.headline)
                            .lineLimit(1)
                        
                        if let fileSize = getFileSize(for: fileURL) {
                            Text(fileSize)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        showingPreview = true
                    } label: {
                        Image(systemName: "eye.fill")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Button {
                    isFilePickerPresenting = true
                } label: {
                    Text("Choose Another File".localized())
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    func currentCVSection(fileURL: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current CV".localized())
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(uploadedFileName ?? getFileNameFromURL(fileURL) ?? "Your CV".localized())
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text("Uploaded CV".localized())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Link(destination: URL(string: fileURL)!) {
                        Image(systemName: "arrow.down.doc.fill")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Button {
                    isFilePickerPresenting = true
                } label: {
                    Text("Replace CV".localized())
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    var uploadButtonSection: some View {
        VStack {
            if isUploading {
                VStack(spacing: 12) {
                    ProgressView(value: uploadProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    Text("\(Int(uploadProgress * 100))% Uploaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if selectedFileURL != nil {
                Button {
                    uploadCV()
                } label: {
                    Text("Upload CV".localized())
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
        }
        .padding(.vertical, 10)
    }
    
    var informationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Information".localized())
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 6) {
                bulletPoint(text: "Maximum file size: 5MB".localized())
                bulletPoint(text: "Supported formats: PDF, DOC, DOCX".localized())
                bulletPoint(text: "Having an updated CV improves your chances".localized())
            }
        }
        .padding(.top, 10)
    }
    
    func bulletPoint(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.blue)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    
    func fileTypeIcon(for url: URL) -> Image {
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "pdf":
            return Image(systemName: "doc.fill.badge.plus")
        case "doc", "docx":
            return Image(systemName: "doc.fill")
        default:
            return Image(systemName: "doc")
        }
    }
    
    func getFileSize(for url: URL) -> String? {
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = resources.fileSize {
                return formatFileSize(fileSize)
            }
        } catch {
            print("Error getting file size: \(error)")
        }
        return nil
    }
    
    func formatFileSize(_ size: Int) -> String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB]
        byteCountFormatter.countStyle = .file
        return byteCountFormatter.string(fromByteCount: Int64(size))
    }
    
    func getFileNameFromURL(_ urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        
        // Try to extract filename from URL path
        let filename = url.lastPathComponent
        
        // Check if there's a query that might contain the original filename
        if let urlComponents = URLComponents(string: urlString),
           let queryItems = urlComponents.queryItems {
            for item in queryItems {
                if item.name.lowercased() == "filename" || item.name.lowercased() == "name" {
                    return item.value
                }
            }
        }
        
        return filename
    }
    
    // MARK: - Backend Logic
    
    func fetchCurrentCV() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("job_seekers").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching profile: \(error.localizedDescription)")
                return
            }
            
            if let data = snapshot?.data() {
                if let resumeURL = data["resumeURL"] as? String, !resumeURL.isEmpty {
                    self.uploadedCVURL = resumeURL
                    self.uploadedFileName = data["resumeFileName"] as? String
                }
            }
        }
    }
    
    func uploadCV() {
        guard let fileURL = selectedFileURL else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        isUploading = true
        uploadProgress = 0.01 // Start with non-zero progress for UI feedback
        
        let fileExtension = fileURL.pathExtension.lowercased()
        let storageRef = Storage.storage().reference().child("resumes/\(uid)_\(UUID().uuidString).\(fileExtension)")
        
        let metadata = StorageMetadata()
        switch fileExtension {
        case "pdf":
            metadata.contentType = "application/pdf"
        case "doc":
            metadata.contentType = "application/msword"
        case "docx":
            metadata.contentType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        default:
            metadata.contentType = "application/octet-stream"
        }
        
        let uploadTask = storageRef.putFile(from: fileURL, metadata: metadata)
        
        // Monitor progress
        uploadTask.observe(.progress) { snapshot in
            let percentComplete = Double(snapshot.progress!.completedUnitCount) / Double(snapshot.progress!.totalUnitCount)
            self.uploadProgress = percentComplete
        }
        
        // Handle completion
        uploadTask.observe(.success) { snapshot in
            storageRef.downloadURL { url, error in
                if let error = error {
                    self.isUploading = false
                    self.alertTitle = "Upload Error"
                    self.alertMessage = "Failed to get download URL: \(error.localizedDescription)"
                    self.showingAlert = true
                    return
                }
                
                guard let downloadURL = url else {
                    self.isUploading = false
                    self.alertTitle = "Upload Error"
                    self.alertMessage = "Failed to get download URL"
                    self.showingAlert = true
                    return
                }
                
                // Update Firestore with the new CV URL
                let db = Firestore.firestore()
                db.collection("job_seekers").document(uid).updateData([
                    "resumeURL": downloadURL.absoluteString,
                    "resumeFileName": fileName
                ]) { error in
                    self.isUploading = false
                    
                    if let error = error {
                        self.alertTitle = "Update Error"
                        self.alertMessage = "Failed to update profile: \(error.localizedDescription)"
                        self.showingAlert = true
                    } else {
                        self.uploadedCVURL = downloadURL.absoluteString
                        self.uploadedFileName = fileName
                        self.selectedFileURL = nil
                        self.alertTitle = "Success"
                        self.alertMessage = "Your CV has been uploaded successfully!"
                        self.showingAlert = true
                    }
                }
            }
        }
        
        uploadTask.observe(.failure) { snapshot in
            self.isUploading = false
            if let error = snapshot.error {
                self.alertTitle = "Upload Error"
                self.alertMessage = "Failed to upload file: \(error.localizedDescription)"
                self.showingAlert = true
            }
        }
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var fileURL: URL?
    @Binding var fileName: String
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [.pdf, UTType(filenameExtension: "doc")!, UTType(filenameExtension: "docx")!]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Create a local copy in the app's temporary directory
            let temporaryDirectoryURL = FileManager.default.temporaryDirectory
            let destinationURL = temporaryDirectoryURL.appendingPathComponent(url.lastPathComponent)
            
            do {
                // Remove any existing file at the destination
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // Copy the file to the temporary directory
                try FileManager.default.copyItem(at: url, to: destinationURL)
                
                // Start accessing the security-scoped resource
                let didStartAccessing = url.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                // Update parent bindings
                parent.fileURL = destinationURL
                parent.fileName = url.lastPathComponent
            } catch {
                print("Error copying file: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - QuickLook Preview
// This is a separate component that doesn't affect the main state
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: QuickLookPreview
        
        init(_ parent: QuickLookPreview) {
            self.parent = parent
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.url as NSURL
        }
    }
}

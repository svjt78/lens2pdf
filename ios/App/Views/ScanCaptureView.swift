import SwiftUI

struct ScanCaptureView: View {
    @StateObject private var viewModel = ScanViewModel()
    @State private var showingScanner = false
    @State private var showShareSheet = false
    @State private var alertMessage: AlertMessage?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    captureActions
                    capturedPreview
                    processingSection
                    shareSection
                }
                .padding()
            }
            .navigationTitle("Scan")
            .alert(item: $alertMessage) { message in
                Alert(title: Text("Capture"), message: Text(message.text), dismissButton: .default(Text("OK")))
            }
            .sheet(isPresented: $showingScanner) {
                VisionScannerView { result in
                    showingScanner = false
                    switch result {
                    case .success(let capture):
                        viewModel.applyCapture(result: capture)
                    case .failure(let error):
                        if case CaptureError.cancelled = error {
                            break
                        } else {
                            alertMessage = AlertMessage(text: error.localizedDescription)
                        }
                    }
                }
            }
        }
    }

    private var captureActions: some View {
        VStack(spacing: 12) {
            Button {
                showingScanner = true
            } label: {
                Label("Scan with Camera", systemImage: "doc.viewfinder")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor.opacity(0.15))
                    .cornerRadius(10)
            }

            if !viewModel.capturedPages.isEmpty {
                Button(role: .destructive) {
                    viewModel.reset()
                } label: {
                    Label("Clear Capture", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                }
            }
        }
    }

    private var capturedPreview: some View {
        Group {
            if viewModel.capturedPages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Capture pages with VisionKit to begin.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Document title", text: $viewModel.documentTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    ForEach(viewModel.capturedPages) { page in
                        HStack(alignment: .top, spacing: 12) {
                            Image(uiImage: page.image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 120)
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Page \(page.index + 1)")
                                    .font(.headline)
                                if let warnings = viewModel.warningsByPage[page.id], !warnings.isEmpty {
                                    ForEach(warnings) { warning in
                                        Label(warning.message, systemImage: "exclamationmark.triangle.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                } else {
                                    Text("Looks good")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Button(role: .destructive) {
                                    viewModel.removePage(page)
                                } label: {
                                    Label("Remove page", systemImage: "trash")
                                        .font(.caption)
                                }
                            }
                            Spacer()
                        }
                        Divider()
                    }
                }
            }
        }
    }

    private var processingSection: some View {
        VStack(spacing: 12) {
            switch viewModel.processingState {
            case .idle, .completed:
                EmptyView()
            case .processing(let message):
                HStack {
                    ProgressView()
                    Text(message)
                        .font(.callout)
                    Spacer()
                }
            case .error(let message):
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(message)
                        .font(.callout)
                    Spacer()
                }
            }

            if !viewModel.capturedPages.isEmpty {
                Button {
                    viewModel.processAndSave()
                } label: {
                    Label("Process & Save", systemImage: "gearshape.2")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(10)
                }
                .disabled({ if case .processing = viewModel.processingState { return true } else { return false } }())
            }
        }
    }

    private var shareSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let document = viewModel.savedDocument, let data = viewModel.pdfData {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Saved as \(document.title)")
                        .font(.headline)
                    Text("Pages: \(document.pageCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Button {
                    showShareSheet = true
                } label: {
                    Label("Share PDF", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(10)
                }
                .sheet(isPresented: $showShareSheet) {
                    ActivityView(activityItems: [TemporaryFileData(data: data, suggestedName: document.title + ".pdf")])
                }
            }
        }
    }
}

struct AlertMessage: Identifiable {
    let id = UUID()
    let text: String
}

struct ScanCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        ScanCaptureView()
    }
}


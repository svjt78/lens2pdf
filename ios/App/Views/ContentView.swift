import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var vm = ScanViewModel()
    @State private var showShare = false
    @State private var pickerItems: [PhotosPickerItem] = []

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                    Label("Select Photos (Receipts)", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .onChange(of: pickerItems) { _ in
                    Task { await loadPickerItems() }
                }

                HStack {
                    Text("Selected: \(vm.selectedImages.count)")
                    Spacer()
                    Button(role: .destructive) { vm.reset() } label: {
                        Label("Clear", systemImage: "trash")
                    }.disabled(vm.isProcessing)
                }

                Button {
                    Task { await vm.runPipeline() }
                } label: {
                    Label("Process → PDF", systemImage: "doc.richtext")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(vm.selectedImages.isEmpty ? Color.gray.opacity(0.2) : Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
                .disabled(vm.selectedImages.isEmpty || vm.isProcessing)

                if vm.isProcessing {
                    ProgressView(vm.progressText.isEmpty ? "Processing…" : vm.progressText)
                        .progressViewStyle(.circular)
                }

                if let _ = vm.pdfData {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Vendor: \(vm.extractedVendor)")
                        Text("Date: \(vm.extractedDate)")
                        Text("Total: \(vm.extractedTotal)")
                        Text("Filename: \(vm.suggestedFileName)")
                    }
                    Button {
                        showShare = true
                    } label: {
                        Label("Share PDF", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .sheet(isPresented: $showShare) {
                        if let data = vm.pdfData {
                            ActivityView(activityItems: [TemporaryFileData(data: data, suggestedName: vm.suggestedFileName)])
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Scan → PDF (MVP)")
        }
    }

    private func loadPickerItems() async {
        vm.selectedImages.removeAll()
        for item in pickerItems {
            if let data = try? await item.loadTransferable(type: Data.self) {
                vm.selectedImages.append(data)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView() }
}


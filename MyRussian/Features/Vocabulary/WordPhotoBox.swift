import PhotosUI
import SwiftData
import SwiftUI
import MyRussianCore

/// A small, non-interactive picture to help remember the word. Deliberately no full-screen view:
/// the only controls are add, replace and remove.
struct WordPhotoBox: View {
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var app
    let word: VocabularyWord

    @State private var pickerItem: PhotosPickerItem?
    @State private var showingPicker = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    private var service: VocabularyService { VocabularyService(context: context, audioStore: app.audioStore) }

    var body: some View {
        Group {
            if let data = word.photoData, let image = UIImage(data: data) {
                photo(image)
            } else {
                placeholder
            }
        }
        .photosPicker(isPresented: $showingPicker, selection: $pickerItem, matching: .images,
                      preferredItemEncoding: .compatible)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
        .alert("Photo", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func photo(_ image: UIImage) -> some View {
        Color.clear
            .frame(height: 210)
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .allowsHitTesting(false)
            }
            .clipShape(.rect(cornerRadius: 22))
            .overlay {
                if isProcessing { ProgressView().controlSize(.large) }
            }
            .overlay(alignment: .topTrailing) {
                Menu {
                    Button("Replace Photo", systemImage: "photo.on.rectangle") { showingPicker = true }
                    Button("Remove Photo", systemImage: "trash", role: .destructive) {
                        withAnimation { service.setPhoto(nil, for: word) }
                    }
                    .accessibilityIdentifier("photo.remove")
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .padding(10)
                .accessibilityLabel("Photo options")
                .accessibilityIdentifier("photo.options")
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Your photo for \(word.russian)")
            .accessibilityIdentifier("detail.photo")
    }

    private var placeholder: some View {
        Button {
            showingPicker = true
        } label: {
            HStack(spacing: 12) {
                if isProcessing {
                    ProgressView()
                } else {
                    Image(systemName: "photo.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add a photo").font(.body.weight(.medium))
                    Text("A picture to help you remember").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
        .accessibilityIdentifier("detail.addPhoto")
    }

    private func load(_ item: PhotosPickerItem) async {
        isProcessing = true
        defer {
            isProcessing = false
            pickerItem = nil
        }
        do {
            guard let original = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "That photo couldn’t be loaded."
                return
            }
            let compressed = await Task.detached(priority: .userInitiated) {
                PhotoEncoder.compressedJPEG(fromImageData: original)
            }.value
            guard let compressed else {
                errorMessage = "That photo couldn’t be used. Try a different one."
                return
            }
            withAnimation { service.setPhoto(compressed, for: word) }
        } catch {
            errorMessage = "That photo couldn’t be loaded."
        }
    }
}

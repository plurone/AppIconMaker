import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var state = AppIconMakerState()

    var body: some View {
        @Bindable var bindableState = state

        ZStack {
            VStack(spacing: 0) {
                ToolbarView(
                    selectedPreset: $bindableState.selectedPreset,
                    canExport: state.canExport,
                    chooseImage: { ExportWorkflow.chooseImage(load: state.loadImage) },
                    exportIconSet: { ExportWorkflow.exportIconSet(using: state) }
                )

                HStack(spacing: 0) {
                    DropPreviewView(state: state)
                        .frame(minWidth: 360)

                    Divider()

                    InspectorPanel(
                        state: state,
                        revealExport: ExportWorkflow.revealExport,
                        copyExportPath: ExportWorkflow.copyExportPath
                    )
                    .frame(width: 300)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(nsColor: .windowBackgroundColor))

            if let selectedExportPreview = state.selectedExportPreview {
                ExportPreviewOverlay(
                    preview: selectedExportPreview,
                    selectedPreview: $bindableState.selectedExportPreview
                )
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $bindableState.isTargeted, perform: handleDrop)
        .onChange(of: state.preparationOptions) {
            state.prepareSelectedImage()
        }
        .onChange(of: state.selectedPreset) {
            state.clearExportSummary()
            state.prepareSelectedImage()
        }
        .onChange(of: state.opaqueBackgroundColor) {
            guard state.selectedPreset == .iosUniversal else {
                return
            }
            state.prepareSelectedImage()
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = item as? URL
            }

            guard let url else {
                return
            }

            DispatchQueue.main.async {
                state.loadImage(at: url)
            }
        }

        return true
    }
}

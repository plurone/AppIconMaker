import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedPreset: IconPlatformPreset = .iosUniversal
    @State private var preparationMode: ImagePreparationMode = .centerCrop
    @State private var selectedImage: ValidatedImage?
    @State private var preparedImage: PreparedImage?
    @State private var status: ValidationStatus = .idle
    @State private var exportSummary: ExportSummary?
    @State private var exportPreviews: [ExportIconPreview] = []
    @State private var selectedExportPreview: ExportIconPreview?
    @State private var opaqueBackgroundColor = Color.black
    @State private var isTargeted = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                toolbar

                HStack(spacing: 0) {
                    dropZone
                        .frame(minWidth: 360)

                    Divider()

                    detailsPanel
                        .frame(width: 300)
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))

            if let selectedExportPreview {
                expandedPreviewOverlay(selectedExportPreview)
                    .transition(.opacity)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
        .onChange(of: preparationMode) {
            prepareSelectedImage()
        }
        .onChange(of: selectedPreset) {
            clearExportSummary()
            prepareSelectedImage()
        }
        .onChange(of: opaqueBackgroundColor) {
            guard selectedPreset == .iosUniversal else {
                return
            }
            prepareSelectedImage()
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("AppIconMaker")
                .font(.title2.weight(.semibold))

            Spacer()

            Picker("平台", selection: $selectedPreset) {
                ForEach(IconPlatformPreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)

            Button {
                chooseImage()
            } label: {
                Label("选择图片", systemImage: "photo")
            }

            Button {
                exportIconSet()
            } label: {
                Label("导出", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .disabled(preparedImage == nil)
        }
        .padding(16)
    }

    private var dropZone: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 18) {
                if let image = preparedImage?.previewImage {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(maxWidth: 320, maxHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 12, y: 6)
                } else {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 88, weight: .light))
                        .foregroundStyle(.secondary)
                }

                Text(selectedImage?.url.lastPathComponent ?? "拖入任意尺寸 PNG，或点击选择图片")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                statusView
            }

            Spacer(minLength: 24)

            if !exportPreviews.isEmpty {
                exportPreviewPanel
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
        .background(isTargeted ? Color.accentColor.opacity(0.12) : Color.clear)
    }

    private var detailsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("图片适配")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Picker("适配方式", selection: $preparationMode) {
                    ForEach(ImagePreparationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(preparationMode.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let selectedImage, let preparedImage {
                    Text("源图 \(selectedImage.width)x\(selectedImage.height) -> \(preparedImage.width)x\(preparedImage.height)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("请选择 PNG 后预览 1024x1024 母版图。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Text("色彩与透明")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                if let info = selectedImage?.normalizationInfo {
                    Text("色彩：\(info.colorDescription)")
                    Text("透明：\(info.alphaDescription)")

                    if selectedPreset == .iosUniversal {
                        ColorPicker("iOS 背景", selection: $opaqueBackgroundColor, supportsOpacity: false)
                        Text("导出和尺寸预览会合成不透明背景。")
                            .foregroundStyle(.secondary)
                    } else if info.hasTransparentPixels {
                        Text("macOS 导出会保留透明像素。")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("选择 PNG 后显示色彩空间和 Alpha 状态。")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)

            Divider()

            Text("导出内容")
                .font(.headline)

            Text("\(selectedPreset.slots.count) 个 PNG + Contents.json")
                .foregroundStyle(.secondary)

            if let exportSummary {
                Divider()

                exportSummaryPanel(exportSummary)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(selectedPreset.slots, id: \.filename) { slot in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(slot.filename)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                Text("\(slot.idiom) · \(slot.size) · \(slot.scale)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(slot.pixelSize)px")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .idle:
            Text("支持任意尺寸 PNG，可裁剪或透明填充为 1024x1024。")
                .foregroundStyle(.secondary)
        case let .ready(width, height, mode):
            Label("已准备：源图 \(width)x\(height)，\(mode.displayName)为 1024x1024", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case let .failed(message):
            Label(message, systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        case let .exported(summary):
            Label("已导出：\(summary.generatedFileCount) 个文件到 \(summary.outputURL.path)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }

    private func exportSummaryPanel(_ summary: ExportSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("导出摘要")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("平台：\(summary.platformName)")
                Text("适配：\(summary.preparationName)")
                Text("文件：\(summary.generatedPNGCount) 个 PNG + Contents.json")
                Text(summary.outputURL.path)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    revealExport(summary)
                } label: {
                    Label("Finder 中显示", systemImage: "folder")
                }

                Button {
                    copyExportPath(summary)
                } label: {
                    Label("复制路径", systemImage: "doc.on.doc")
                }
            }
            .labelStyle(.titleAndIcon)
            .controlSize(.small)
        }
    }

    private var exportPreviewPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("尺寸预览")
                .font(.headline)

            if exportPreviews.isEmpty {
                Text("尚未选择图片")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(exportPreviews) { preview in
                            Button {
                                withAnimation(.easeInOut(duration: 0.16)) {
                                    selectedExportPreview = preview
                                }
                            } label: {
                                exportPreviewTile(preview)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func exportPreviewTile(_ preview: ExportIconPreview) -> some View {
        VStack(spacing: 6) {
            Image(nsImage: preview.previewImage)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 48, height: 48)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }

            Text(preview.sizeLabel)
                .font(.caption.monospacedDigit().weight(.medium))
                .lineLimit(1)

            Text(preview.detailLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 76)
    }

    private func expandedPreviewOverlay(_ preview: ExportIconPreview) -> some View {
        GeometryReader { geometry in
            let previewSize = min(geometry.size.width * 0.52, geometry.size.height * 0.68)

            VStack(spacing: 14) {
                Image(nsImage: preview.previewImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: previewSize, height: previewSize)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 18, y: 8)

                Text(preview.sizeLabel)
                    .font(.title2.monospacedDigit().weight(.semibold))

                Text(preview.detailLabel)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.72))
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.16)) {
                    selectedExportPreview = nil
                }
            }
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            loadImage(at: url)
        }
    }

    private func loadImage(at url: URL) {
        do {
            let image = try ImageValidator.loadPNG(at: url)
            selectedImage = image
            prepareSelectedImage()
        } catch {
            selectedImage = nil
            preparedImage = nil
            exportSummary = nil
            exportPreviews = []
            selectedExportPreview = nil
            status = .failed(message: error.localizedDescription)
        }
    }

    private func exportIconSet() {
        guard let selectedImage, let preparedImage else {
            return
        }

        let panel = NSOpenPanel()
        panel.prompt = "选择导出目录"
        panel.message = "将在所选目录中生成 AppIcon.appiconset。"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let outputDirectory = panel.url else {
            return
        }

        let preflight = ExportPreflight.inspect(
            source: selectedImage,
            preparedImage: preparedImage,
            preset: selectedPreset,
            outputDirectory: outputDirectory,
            willCompositeOpaqueBackground: exportOpaqueBackgroundColor != nil
        )
        guard confirmPreflight(preflight) else {
            return
        }

        do {
            let outputURL = try IconSetGenerator().generate(
                from: selectedImage.normalizedCGImage,
                mode: preparationMode,
                preset: selectedPreset,
                outputDirectory: outputDirectory,
                opaqueBackgroundColor: exportOpaqueBackgroundColor
            )
            let summary = ExportPreflight.summary(
                outputURL: outputURL,
                preset: selectedPreset,
                preparationMode: preparationMode
            )
            exportSummary = summary
            status = .exported(summary)
        } catch {
            exportSummary = nil
            status = .failed(message: error.localizedDescription)
        }
    }

    private func confirmPreflight(_ result: ExportPreflightResult) -> Bool {
        if !result.canExport {
            showPreflightAlert(
                title: "无法导出",
                message: result.blockingIssues.map(issueText).joined(separator: "\n\n"),
                style: .critical,
                confirmTitle: "好"
            )
            return false
        }

        guard !result.warnings.isEmpty else {
            return true
        }

        return showPreflightAlert(
            title: "导出前检查",
            message: result.warnings.map(issueText).joined(separator: "\n\n"),
            style: .warning,
            confirmTitle: "继续导出",
            cancelTitle: "取消"
        )
    }

    @discardableResult
    private func showPreflightAlert(
        title: String,
        message: String,
        style: NSAlert.Style,
        confirmTitle: String,
        cancelTitle: String? = nil
    ) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: confirmTitle)
        if let cancelTitle {
            alert.addButton(withTitle: cancelTitle)
        }
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func issueText(_ issue: ExportPreflightIssue) -> String {
        "\(issue.title)：\(issue.message)"
    }

    private func revealExport(_ summary: ExportSummary) {
        NSWorkspace.shared.activateFileViewerSelecting([summary.outputURL])
    }

    private func copyExportPath(_ summary: ExportSummary) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(summary.outputURL.path, forType: .string)
    }

    private func clearExportSummary() {
        exportSummary = nil
        if let selectedImage, let preparedImage {
            status = .ready(width: selectedImage.width, height: selectedImage.height, mode: preparedImage.mode)
        }
    }

    private func refreshExportPreviews() {
        guard let selectedImage else {
            exportPreviews = []
            selectedExportPreview = nil
            return
        }

        do {
            exportPreviews = try ExportPreviewGenerator.previews(
                from: selectedImage.normalizedCGImage,
                mode: preparationMode,
                preset: selectedPreset,
                opaqueBackgroundColor: exportOpaqueBackgroundColor
            )
            selectedExportPreview = nil
        } catch {
            exportPreviews = []
            selectedExportPreview = nil
            status = .failed(message: error.localizedDescription)
        }
    }

    private func prepareSelectedImage() {
        guard let selectedImage else {
            preparedImage = nil
            exportSummary = nil
            exportPreviews = []
            selectedExportPreview = nil
            status = .idle
            return
        }

        do {
            var image = try ImagePreparer.prepare(selectedImage.normalizedCGImage, mode: preparationMode)
            if let exportOpaqueBackgroundColor {
                let opaqueImage = try ImageNormalizer.makeOpaque(image.cgImage, backgroundColor: exportOpaqueBackgroundColor)
                image = PreparedImage(
                    cgImage: opaqueImage,
                    previewImage: NSImage(cgImage: opaqueImage, size: NSSize(width: image.width, height: image.height)),
                    width: image.width,
                    height: image.height,
                    mode: image.mode
                )
            }
            let previews = try ExportPreviewGenerator.previews(
                from: selectedImage.normalizedCGImage,
                mode: preparationMode,
                preset: selectedPreset,
                opaqueBackgroundColor: exportOpaqueBackgroundColor
            )
            preparedImage = image
            exportPreviews = previews
            exportSummary = nil
            selectedExportPreview = nil
            status = .ready(width: selectedImage.width, height: selectedImage.height, mode: preparationMode)
        } catch {
            preparedImage = nil
            exportSummary = nil
            exportPreviews = []
            selectedExportPreview = nil
            status = .failed(message: error.localizedDescription)
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
                loadImage(at: url)
            }
        }

        return true
    }

    private var exportOpaqueBackgroundColor: CGColor? {
        guard selectedPreset == .iosUniversal else {
            return nil
        }

        return NSColor(opaqueBackgroundColor).usingColorSpace(.sRGB)?.cgColor ?? NSColor.black.cgColor
    }
}

private enum ValidationStatus: Equatable {
    case idle
    case ready(width: Int, height: Int, mode: ImagePreparationMode)
    case failed(message: String)
    case exported(ExportSummary)
}

import AppKit
import SwiftUI

struct DropPreviewView: View {
    @Bindable var state: AppIconMakerState

    var body: some View {
        GeometryReader { geometry in
            let contentMinHeight = max(0, geometry.size.height - 56)

            ScrollView(.vertical) {
                VStack(spacing: 28) {
                    VStack(spacing: 18) {
                        if let image = state.preparedImage?.previewImage {
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

                        Text(state.selectedFileName ?? "拖入任意尺寸 PNG，或点击选择图片")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)

                        StatusView(status: state.status)
                    }

                    if !state.exportPreviews.isEmpty {
                        ExportPreviewPanel(
                            previews: state.exportPreviews,
                            selectedPreview: $state.selectedExportPreview
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: contentMinHeight)
                .padding(28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(state.isTargeted ? Color.accentColor.opacity(0.12) : Color.clear)
    }
}

private struct StatusView: View {
    let status: ValidationStatus

    var body: some View {
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
}

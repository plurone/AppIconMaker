import AppKit
import SwiftUI

struct ExportPreviewPanel: View {
    let previews: [ExportIconPreview]
    @Binding var selectedPreview: ExportIconPreview?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("尺寸预览")
                .font(.headline)

            if previews.isEmpty {
                Text("尚未选择图片")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(previews) { preview in
                            Button {
                                withAnimation(.easeInOut(duration: 0.16)) {
                                    selectedPreview = preview
                                }
                            } label: {
                                ExportPreviewTile(preview: preview)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

struct ExportPreviewOverlay: View {
    let preview: ExportIconPreview
    @Binding var selectedPreview: ExportIconPreview?

    var body: some View {
        GeometryReader { geometry in
            let previewSize = min(geometry.size.width * 0.52, geometry.size.height * 0.68)
            let detailWidth = min(geometry.size.width * 0.72, 520)

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

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(preview.usageLabels, id: \.self) { label in
                        Text(label)
                    }
                }
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: detailWidth, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.72))
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.16)) {
                    selectedPreview = nil
                }
            }
        }
    }
}

private struct ExportPreviewTile: View {
    let preview: ExportIconPreview

    var body: some View {
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

            VStack(alignment: .leading, spacing: 2) {
                ForEach(preview.usageLabels, id: \.self) { label in
                    Text(label)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 132)
    }
}

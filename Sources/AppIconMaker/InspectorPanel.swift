import SwiftUI

struct InspectorPanel: View {
    @Bindable var state: AppIconMakerState
    let revealExport: (ExportSummary) -> Void
    let copyExportPath: (ExportSummary) -> Void

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                imagePreparationSection

                Divider()

                colorAndTransparencySection

                Divider()

                QualityCheckPanel(result: state.qualityCheckResult, selectedPreset: state.selectedPreset)

                Divider()

                exportContentsSection
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var imagePreparationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("图片适配")
                .font(.headline)

            Picker("适配方式", selection: $state.preparationOptions.mode) {
                ForEach(ImagePreparationMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(state.preparationOptions.mode.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            compositionControls

            if let selectedImage = state.selectedImage, let preparedImage = state.preparedImage {
                Text("源图 \(selectedImage.width)x\(selectedImage.height) -> \(preparedImage.width)x\(preparedImage.height)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text("请选择 PNG 后预览 1024x1024 母版图。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var compositionControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            sliderRow(
                title: "图形大小",
                value: $state.preparationOptions.contentScale,
                range: ImagePreparationOptions.contentScaleRange,
                formattedValue: "\(Int((state.preparationOptions.contentScale * 100).rounded()))%"
            )

            sliderRow(
                title: "水平偏移",
                value: $state.preparationOptions.horizontalOffset,
                range: ImagePreparationOptions.offsetRange,
                formattedValue: signedPercentage(state.preparationOptions.horizontalOffset)
            )

            sliderRow(
                title: "垂直偏移",
                value: $state.preparationOptions.verticalOffset,
                range: ImagePreparationOptions.offsetRange,
                formattedValue: signedPercentage(state.preparationOptions.verticalOffset)
            )

            HStack {
                Text("缩小图形可增加内边距。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("重置") {
                    state.resetComposition()
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(state.isDefaultComposition)
            }
        }
    }

    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        formattedValue: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                Spacer()
                Text(formattedValue)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Slider(value: value, in: range)
        }
    }

    private var colorAndTransparencySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("色彩与透明")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                if let info = state.selectedImage?.normalizationInfo {
                    Text("色彩：\(info.colorDescription)")
                    Text("透明：\(info.alphaDescription)")

                    if state.selectedPreset == .iosUniversal {
                        ColorPicker("iOS 背景", selection: $state.opaqueBackgroundColor, supportsOpacity: false)
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
        }
    }

    private var exportContentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("导出内容")
                    .font(.headline)

                Text("\(state.selectedPreset.slots.count) 个 PNG + Contents.json")
                    .foregroundStyle(.secondary)
            }

            Divider()

            if let exportSummary = state.exportSummary {
                ExportSummaryPanel(
                    summary: exportSummary,
                    revealExport: revealExport,
                    copyExportPath: copyExportPath
                )

                Divider()
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(state.selectedPreset.slots, id: \.filename) { slot in
                    HStack {
                        SlotRow(slot: slot)

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

    private func signedPercentage(_ value: Double) -> String {
        String(format: "%+.0f%%", value * 100)
    }
}

private struct QualityCheckPanel: View {
    let result: ExportQualityCheckResult?
    let selectedPreset: IconPlatformPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("实时质量检查")
                .font(.headline)

            if let result {
                if result.issues.isEmpty {
                    Label("当前设置未发现质量风险", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    ForEach(Array(result.issues.enumerated()), id: \.offset) { _, issue in
                        QualityIssueRow(issue: issue)
                    }
                }

                if selectedPreset == .iosUniversal {
                    Label("iOS 导出会将透明区域合成到当前背景色。", systemImage: "info.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("选择 PNG 后立即显示质量风险。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct QualityIssueRow: View {
    let issue: ExportPreflightIssue

    var body: some View {
        let isBlocking = issue.severity == .blocking

        VStack(alignment: .leading, spacing: 3) {
            Label(issue.title, systemImage: isBlocking ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isBlocking ? .red : .orange)
                .font(.caption.weight(.medium))

            Text(issue.message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ExportSummaryPanel: View {
    let summary: ExportSummary
    let revealExport: (ExportSummary) -> Void
    let copyExportPath: (ExportSummary) -> Void

    var body: some View {
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
}

private struct SlotRow: View {
    let slot: IconSlot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(slot.filename)
                .font(.caption.weight(.medium))
                .lineLimit(1)

            Text("\(slot.idiom) · \(slot.size) · \(slot.scale)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

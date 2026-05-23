import AppKit

@MainActor
enum ExportWorkflow {
    static func chooseImage(load: (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            load(url)
        }
    }

    static func exportIconSet(using state: AppIconMakerState) {
        guard let selectedImage = state.selectedImage,
              let preparedImage = state.preparedImage
        else {
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
            preset: state.selectedPreset,
            outputDirectory: outputDirectory,
            willCompositeOpaqueBackground: state.exportOpaqueBackgroundColor != nil
        )
        guard confirmPreflight(preflight) else {
            return
        }

        do {
            let outputURL = try IconSetGenerator().generate(
                from: selectedImage.normalizedCGImage,
                options: state.preparationOptions,
                preset: state.selectedPreset,
                outputDirectory: outputDirectory,
                opaqueBackgroundColor: state.exportOpaqueBackgroundColor
            )
            let summary = ExportPreflight.summary(
                outputURL: outputURL,
                preset: state.selectedPreset,
                preparationOptions: state.preparationOptions
            )
            state.exportSummary = summary
            state.status = .exported(summary)
        } catch {
            state.exportSummary = nil
            state.status = .failed(message: error.localizedDescription)
        }
    }

    static func revealExport(_ summary: ExportSummary) {
        NSWorkspace.shared.activateFileViewerSelecting([summary.outputURL])
    }

    static func copyExportPath(_ summary: ExportSummary) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(summary.outputURL.path, forType: .string)
    }

    private static func confirmPreflight(_ result: ExportPreflightResult) -> Bool {
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
    private static func showPreflightAlert(
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

    private static func issueText(_ issue: ExportPreflightIssue) -> String {
        "\(issue.title)：\(issue.message)"
    }
}

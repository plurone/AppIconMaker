import SwiftUI

struct ToolbarView: View {
    @Binding var selectedPreset: IconPlatformPreset
    let canExport: Bool
    let chooseImage: () -> Void
    let exportIconSet: () -> Void

    var body: some View {
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
            .disabled(!canExport)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .shadow(color: Color.black.opacity(0.14), radius: 14, y: 6)
    }
}

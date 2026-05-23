# AppIconMaker

AppIconMaker 是一个 macOS 图形化工具，用来把 PNG 图片导出为 Xcode 可直接使用的 `AppIcon.appiconset`。

它适合快速生成 iOS/iPadOS 或 macOS App Icon 资源：拖入图片、选择平台和适配方式，确认预览后导出即可。

## 功能

- 支持拖放或文件选择导入 PNG。
- 支持任意尺寸 PNG，并在导出前准备为 1024x1024 母版图。
- 提供两种图片适配方式：
  - 居中裁剪：铺满 1024x1024，居中裁掉多余区域。
  - 透明填充：完整保留原图比例，空白区域透明。
- 支持调节图形大小和水平/垂直偏移，便于添加内边距或进行光学居中。
- 支持导出 iOS/iPadOS `AppIcon.appiconset`。
- 支持导出 macOS `AppIcon.appiconset`。
- 自动生成每个平台需要的 PNG 尺寸和 `Contents.json`。
- 在右侧实时显示图片质量检查结果，包括放大风险、透明填充占比和 iOS 不透明背景处理状态。
- 导出前检查常见问题，例如目录不可写、即将覆盖已有图标集、iOS App Store 图标含透明像素等。
- 提供目标尺寸预览，便于在导出前检查小尺寸效果。

## 系统要求

- macOS 14 或更新版本。
- Xcode 16 或包含 Swift 6 工具链的开发环境。

## 使用方式

1. 启动 AppIconMaker。
2. 将 PNG 拖入窗口，或点击“选择图片”导入文件。
3. 选择导出平台：
   - `iOS/iPadOS`
   - `macOS`
4. 选择图片适配方式：
   - `居中裁剪`
   - `透明填充`
5. 通过“图形大小”“水平偏移”“垂直偏移”调整构图；缩小图形会产生内边距。
6. 如果选择 iOS/iPadOS，并且图片包含透明区域，选择要合成的不透明背景色。
7. 检查右侧实时质量检查、尺寸预览和提示信息。
8. 点击“导出”，选择目标文件夹。

导出完成后，目标目录中会生成：

```text
AppIcon.appiconset/
├── Contents.json
└── *.png
```

将整个 `AppIcon.appiconset` 放入 Xcode 项目的 `Assets.xcassets` 中即可使用。

## 导出内容

### iOS/iPadOS

iOS/iPadOS 预设会生成 iPhone、iPad 和 App Store marketing icon 需要的图标文件。

导出数量：

- 18 个 PNG
- 1 个 `Contents.json`

iOS/iPadOS 导出会把透明区域合成到不透明背景上，避免 App Store 1024x1024 图标包含透明像素。

### macOS

macOS 预设会生成 Xcode macOS App Icon 所需的常见尺寸。

导出数量：

- 10 个 PNG
- 1 个 `Contents.json`

macOS 导出会保留透明像素。

## 开发

本项目使用 Swift Package Manager，主程序代码位于 `Sources/AppIconMaker`，测试位于 `Tests/AppIconMakerTests`。

运行测试：

```bash
swift test
```

构建：

```bash
swift build
```

也可以通过 Xcode 打开 `AppIconMaker.xcodeproj` 进行构建和运行。

## 项目结构

```text
.
├── AppIconMaker.xcodeproj
├── Package.swift
├── Resources
├── Sources
│   └── AppIconMaker
└── Tests
    └── AppIconMakerTests
```

核心文件：

- `ContentView.swift`：主窗口 UI、导入、预览和导出流程。
- `ImageValidator.swift`：PNG 读取、尺寸和色彩信息验证。
- `ImagePreparer.swift`：1024x1024 母版图准备。
- `IconModels.swift`：iOS/iPadOS 和 macOS 图标槽位定义。
- `IconSetGenerator.swift`：目标 PNG 和 `Contents.json` 生成。
- `ExportPreflight.swift`：导出前检查和导出摘要。

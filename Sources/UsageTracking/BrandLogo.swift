// Author: Zeno Ren (integration). Original vector assets: LobeHub, MIT.
import SwiftUI
import UsageCore

@MainActor private enum BrandImages {
    static let images: [Tool:NSImage] = Dictionary(uniqueKeysWithValues:Tool.allCases.compactMap { tool in
        let url: URL?
        if Bundle.main.bundleURL.pathExtension == "app" {
            url = Bundle.main.url(forResource:tool.rawValue,withExtension:"svg",subdirectory:"Brands")
        } else {
            url = Bundle.module.url(forResource:tool.rawValue,withExtension:"svg",subdirectory:"Assets/Brands")
        }
        guard let url, let image = NSImage(contentsOf:url) else { return nil }
        image.isTemplate = true; image.size = NSSize(width:32,height:32)
        return (tool,image)
    })
}

struct BrandLogo: View {
    var tool: Tool
    var size: CGFloat = 18
    var body: some View {
        Group {
            if let image = BrandImages.images[tool] {
                Image(nsImage:image).resizable().renderingMode(.template).scaledToFit()
            } else {
                Text(Display.shortName(tool).prefix(1)).font(.system(size:size*0.7,weight:.bold))
            }
        }.foregroundStyle(Display.color(tool)).frame(width:size,height:size).accessibilityLabel("\(tool.title) logo")
    }
}

struct BrandLabel: View {
    var tool: Tool
    var compact = false
    var size: CGFloat = 16
    var body: some View {
        HStack(spacing:7) { BrandLogo(tool:tool,size:size); Text(compact ? Display.shortName(tool) : tool.title) }
    }
}

struct ProjectBrands: View {
    var tools: [Tool]
    var body: some View {
        HStack(spacing:4) {
            ForEach(tools) { tool in
                BrandLogo(tool:tool,size:19)
                    .frame(width:31,height:34)
                    .background(Display.color(tool).opacity(0.08),in:RoundedRectangle(cornerRadius:8))
                    .help(tool.title)
            }
        }.frame(width:101,alignment:.leading)
        .accessibilityElement(children:.ignore)
        .accessibilityLabel("参与工具：" + tools.map(\.title).joined(separator:"、"))
    }
}

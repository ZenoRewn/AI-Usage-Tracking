// Author: Zeno Ren
import AppKit
import Foundation

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
func image(size: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
    let transform = NSAffineTransform(); transform.scale(by:CGFloat(size)/1024); transform.concat()
    NSColor.clear.setFill(); NSRect(x:0,y:0,width:1024,height:1024).fill()
    let outer = NSBezierPath(roundedRect:NSRect(x:72,y:72,width:880,height:880),xRadius:196,yRadius:196)
    NSGradient(starting:NSColor(red:134/255,green:97/255,blue:197/255,alpha:1),ending:NSColor(red:0,green:120/255,blue:212/255,alpha:1))!.draw(in:outer,angle:75)
    NSColor.white.withAlphaComponent(0.10).setStroke(); outer.lineWidth = 3; outer.stroke()
    for (x,h,color) in [(240,210,NSColor(red:197/255,green:180/255,blue:227/255,alpha:1)),(415,340,NSColor(red:141/255,green:200/255,blue:232/255,alpha:1)),(590,470,NSColor(red:197/255,green:180/255,blue:227/255,alpha:1))] {
        color.setFill()
        NSBezierPath(roundedRect:NSRect(x:x,y:255,width:115,height:h),xRadius:34,yRadius:34).fill()
    }
    let dot = NSBezierPath(ovalIn:NSRect(x:697,y:663,width:108,height:108)); NSColor(red:141/255,green:200/255,blue:232/255,alpha:1).setFill(); dot.fill()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using:.png,properties:[:])!
}
for points in [16,32,128,256,512] {
    try image(size:points).write(to:directory.appendingPathComponent("icon_\(points)x\(points).png"))
    try image(size:points*2).write(to:directory.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

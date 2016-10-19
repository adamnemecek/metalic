import MetalPerformanceShaders
import CoreImage
import UIKit

class MetalFilterBasicSelfer:MetalFilter
{
    private var bokehSize:Int
    private var sizeRatio:Int
    private var dilate:MPSImageDilate?
    private let kFunctionName:String = "filter_basicSelfer"
    private let kFacesTextureIndex:Int = 2
    private let kBokehTextureIndex:Int = 3
    private let kMinImageSize:Int = 320
    private let kMinBokehSize:Int = 15
    private let kRepeatingElement:Float = 1
    
    required init(device:MTLDevice)
    {
        bokehSize = 0
        sizeRatio = 0
        
        super.init(device:device, functionName:kFunctionName)
    }
    
    override func encode(commandBuffer:MTLCommandBuffer, sourceTexture:MTLTexture, destinationTexture: MTLTexture)
    {
        generateDilate(sourceTexture:sourceTexture)
        
        dilate?.encode(commandBuffer:commandBuffer,
                      sourceTexture:sourceTexture,
                      destinationTexture:destinationTexture)
        
        super.encode(
            commandBuffer:commandBuffer,
            sourceTexture:sourceTexture,
            destinationTexture:destinationTexture)
        
    }
    
    override func specialConfig(commandEncoder:MTLComputeCommandEncoder)
    {
        let context:CIContext = CIContext()
        let options:[String:Any] = [
            CIDetectorAccuracy:CIDetectorAccuracyHigh
        ]
        
        guard
        
            let detector:CIDetector = CIDetector(
                ofType:CIDetectorTypeFace,
                context:context,
                options:options),
            let sourceTexture:MTLTexture = sourceTexture,
            let uiImage:UIImage = sourceTexture.exportImage(),
            let image:CIImage = CIImage(image:uiImage)
        
        else
        {
            return
        }
        
        let sourceWidth:Int = sourceTexture.width
        let sourceHeight:Int = sourceTexture.height
        let maxWidth:Int = sourceWidth - 1
        let maxHeight:Int = sourceHeight - 1
        let sourceSize:Int = sourceWidth * sourceHeight
        let sizeOfFloat:Int = MemoryLayout.size(ofValue:kRepeatingElement)
        var textureArray:[Float] = Array(
            repeating:kRepeatingElement,
            count:sourceSize)
        let bytesPerRow:Int = sizeOfFloat * sourceWidth
        let region:MTLRegion = MTLRegionMake2D(
            0,
            0,
            sourceWidth,
            sourceHeight)
        
        let textureDescriptor:MTLTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat:MTLPixelFormat.r32Float,
            width:sourceWidth,
            height:sourceHeight,
            mipmapped:false)
        
        let facesTexture:MTLTexture = device.makeTexture(descriptor:textureDescriptor)
        let features:[CIFeature] = detector.features(in:image)
        let faceRadius:Int = bokehSize * sizeRatio
        let faceRadiusFloat:Float = Float(faceRadius)
        
        for feature:CIFeature in features
        {
            if let faceFeature:CIFaceFeature = feature as? CIFaceFeature
            {   
                let faceFeatureX:Int = Int(faceFeature.bounds.origin.x)
                let faceFeatureW:Int = Int(faceFeature.bounds.size.width)
                let faceFeatureH:Int = Int(faceFeature.bounds.size.height)
                let faceFeatureY:Int = sourceHeight - (Int(faceFeature.bounds.origin.y) + faceFeatureH)
                let faceFeatureMaxX:Int = faceFeatureX + faceFeatureW
                let faceFeatureMaxY:Int = faceFeatureY + faceFeatureH
                
                for faceHr:Int in faceFeatureX ..< faceFeatureMaxX
                {
                    for faceVr:Int in faceFeatureY ..< faceFeatureMaxY
                    {
                        let facePosition:Int = (sourceWidth * faceVr) + faceHr
                        textureArray[facePosition] = 0
                    }
                }
                
                for radius:Int in 0 ..< faceRadius
                {
                    let radiusFloat:Float = Float(radius)
                    let thisPixel:Float = radiusFloat / faceRadiusFloat
                    var minX:Int = faceFeatureX - radius
                    var maxX:Int = faceFeatureMaxX + radius
                    var minY:Int = faceFeatureY - radius
                    var maxY:Int = faceFeatureMaxY + radius
                    
                    if minX < 0
                    {
                        minX = 0
                    }
                    
                    if maxX > maxWidth
                    {
                        maxX = maxWidth
                    }
                    
                    if minY < 0
                    {
                        minY = 0
                    }
                    
                    if maxY > maxHeight
                    {
                        maxY = maxHeight
                    }
                    
                    for indexHr:Int in minX ..< maxX
                    {
                        let topIndex:Int = (sourceWidth * minY) + indexHr
                        let bottomIndex:Int = (sourceWidth * maxY) + indexHr
                        let currentTop:Float = textureArray[topIndex]
                        let currentBottom:Float = textureArray[bottomIndex]
                        
                        if currentTop > thisPixel
                        {
                            textureArray[topIndex] = thisPixel
                        }
                        
                        if currentBottom > thisPixel
                        {
                            textureArray[bottomIndex] = thisPixel
                        }
                    }
                    
                    for indexVr:Int in minY ..< maxY
                    {
                        let leftIndex:Int = (sourceWidth * indexVr) + minX
                        let rightIndex:Int = (sourceWidth * indexVr) + maxX
                        let currentLeft:Float = textureArray[leftIndex]
                        let currentRight:Float = textureArray[rightIndex]
                        
                        if currentLeft > thisPixel
                        {
                            textureArray[leftIndex] = thisPixel
                        }
                        
                        if currentRight > thisPixel
                        {
                            textureArray[rightIndex] = thisPixel
                        }
                    }
                }
            }
        }
        
        let bytes:UnsafeRawPointer = UnsafeRawPointer(textureArray)
        facesTexture.replace(
            region:region,
            mipmapLevel:0,
            withBytes:bytes,
            bytesPerRow:bytesPerRow)
        
        commandEncoder.setTexture(facesTexture, at:kFacesTextureIndex)
        commandEncoder.setTexture(destinationTexture, at:kBokehTextureIndex)
    }
    
    //MARK: private
    
    private func generateDilate(sourceTexture:MTLTexture)
    {
        let sourceWidth:Int = sourceTexture.width
        let sourceHeight:Int = sourceTexture.height
        let minSize:Int = min(sourceWidth, sourceHeight)
        
        if minSize <= kMinImageSize
        {
            bokehSize = kMinBokehSize
            sizeRatio = 1
        }
        else
        {
            sizeRatio = minSize / kMinImageSize
            bokehSize = kMinBokehSize * sizeRatio
        }
        
        if bokehSize % 2 == 0
        {
            bokehSize += 1
        }
        
        var probe:[Float] = []
        let bokehSizeFloat:Float = Float(bokehSize)
        let midSize:Float = bokehSizeFloat / 2.0
        
        for indexHr:Int in 0 ..< bokehSize
        {
            let indexHrFloat:Float = Float(indexHr)
            let xPos:Float = abs(indexHrFloat - midSize)
            
            for indexVr:Int in 0 ..< bokehSize
            {
                let indexVrFloat:Float = Float(indexVr)
                let yPos:Float = abs(indexVrFloat - midSize)
                let hypotPos:Float = hypot(xPos, yPos)
                let probeElement:Float
                
                if hypotPos < midSize
                {
                    probeElement = 0
                }
                else
                {
                    probeElement = 1
                }
                
                probe.append(probeElement)
            }
        }
        
        dilate = MPSImageDilate(
            device:device,
            kernelWidth:bokehSize,
            kernelHeight:bokehSize,
            values:probe)
    }
}

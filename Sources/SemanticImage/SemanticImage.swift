import Foundation
import Vision
import UIKit

public class SemanticImage {
    public private(set) var text = "Hello, World!"

    public init() {
    }
    
    lazy var personSegmentationRequest = VNGeneratePersonSegmentationRequest()
    lazy var faceRectangleRequest = VNDetectFaceRectanglesRequest()
    let ciContext = CIContext()
    
    public func personMaskImage(uiImage:UIImage) -> UIImage? {
        let newImage = getCorrectOrientationUIImage(uiImage:uiImage)
        guard let ciImage = CIImage(image: newImage) else { print("Image processing failed.Please try with another image."); return nil }
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([personSegmentationRequest])
            guard let result = personSegmentationRequest.results?.first
                   else { print("Image processing failed.Please try with another image.") ; return nil }
            let maskCIImage = CIImage(cvPixelBuffer: result.pixelBuffer)
            let scaledMask = maskCIImage.resize(as: CGSize(width: ciImage.extent.width, height: ciImage.extent.height))

            guard let safeCGImage = ciContext.createCGImage(scaledMask, from: scaledMask.extent) else { print("Image processing failed.Please try with another image.") ; return nil }
            let maskUIImage = UIImage(cgImage: safeCGImage)
            return maskUIImage

        } catch let error {
            print("Vision error \(error)")
            return nil
        }
    }
    
    
    public func swapBackgroundOfPerson(personUIImage: UIImage, backgroundUIImage: UIImage) -> UIImage? {
        let newPersonUIImage = getCorrectOrientationUIImage(uiImage:personUIImage)
        let newBackgroundUIImage = getCorrectOrientationUIImage(uiImage:backgroundUIImage)
        
        guard let personCIImage = CIImage(image: newPersonUIImage),
              let backgroundCIImage = CIImage(image: newBackgroundUIImage),
              let maskUIImage = personMaskImage(uiImage: newPersonUIImage),
              let maskCIImage = CIImage(image: maskUIImage) else {
                  return nil }
        
        let backgroundImageSize = backgroundCIImage.extent
        let originalSize = personCIImage.extent
        var scale:CGFloat = 1
        let widthScale =  originalSize.width / backgroundImageSize.width
        let heightScale = originalSize.height / backgroundImageSize.height
        if widthScale > heightScale {
            scale = personCIImage.extent.width / backgroundImageSize.width
        } else {
            scale = personCIImage.extent.height / backgroundImageSize.height
        }
        
        let scaledBG = backgroundCIImage.resize(as: CGSize(width: backgroundCIImage.extent.width*scale, height: backgroundCIImage.extent.height*scale))
        let BGCenter = CGPoint(x: scaledBG.extent.width/2, y: scaledBG.extent.height/2)
        let originalExtent = personCIImage.extent
        let cropRect = CGRect(x: BGCenter.x-(originalExtent.width/2), y: BGCenter.y-(originalExtent.height/2), width: originalExtent.width, height: originalExtent.height)
        let croppedBG = scaledBG.cropped(to: cropRect)
        let translate = CGAffineTransform(translationX: -croppedBG.extent.minX, y: -croppedBG.extent.minY)
        let traslatedBG = croppedBG.transformed(by: translate)
        guard let blended = CIFilter(name: "CIBlendWithMask", parameters: [
            kCIInputImageKey: personCIImage,
            kCIInputBackgroundImageKey:traslatedBG,
            kCIInputMaskImageKey:maskCIImage])?.outputImage else { return nil }
        guard let safeCGImage = ciContext.createCGImage(blended, from: blended.extent) else { print("Image processing failed.Please try with another image.") ; return nil }
        let blendedUIImage = UIImage(cgImage: safeCGImage)
        return blendedUIImage
    }
    
    public func faceRectangle(uiImage:UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: uiImage) else { print("Image processing failed.Please try with another image."); return nil }
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([faceRectangleRequest])
            guard let result = faceRectangleRequest.results?.first else { print("Image processing failed.Please try with another image."); return nil }
            let roll = CGFloat(truncating: (result.roll)!)
            if roll != 0 {
                let rotatedOriginalImage:CIImage = ciImage.transformed(by: CGAffineTransform(rotationAngle: -roll))
                let imageData = ciContext.pngRepresentation(of: rotatedOriginalImage, format: CIFormat.ARGB8, colorSpace: CGColorSpace(name: "kCGColorSpaceDisplayP3" as CFString)!)
                let cropHandler = VNImageRequestHandler(data: imageData!, options: [:])
                try cropHandler.perform([faceRectangleRequest])
                guard let cropResult = faceRectangleRequest.results?.first else { print("Image processing failed.Please try with another image."); return nil }
                let faceBoundingBox = cropResult.boundingBox
                let faceRect = VNImageRectForNormalizedRect(faceBoundingBox,Int(rotatedOriginalImage.extent.size.width), Int(rotatedOriginalImage.extent.size.height))
                let faceImage = rotatedOriginalImage.cropped(to: faceRect)
                guard let final = ciContext.createCGImage(faceImage, from: faceImage.extent) else { print("Image processing failed.Please try with another image."); return nil }
                let uiimage =  UIImage(cgImage: final)
            } else {
                let boundingBox = result.boundingBox
                let faceRect = VNImageRectForNormalizedRect((boundingBox),Int(ciImage.extent.size.width), Int(ciImage.extent.size.height))
                let faceImage = ciImage.cropped(to: faceRect)
                guard let final = ciContext.createCGImage(faceImage, from: faceImage.extent) else { print("Image processing failed.Please try with another image."); return nil }
                let uiimage =  UIImage(cgImage: final)
                return uiImage
            }
        } catch let error {
            print("Vision error \(error)")
            return nil
        }
    }
    
    func scaleMaskImage(maskCIImage:CIImage, originalCIImage:CIImage) -> CIImage {
        let scaledMaskCIImage = maskCIImage.resize(as: originalCIImage.extent.size)
        return scaledMaskCIImage
    }
    
    public func getCorrectOrientationUIImage(uiImage:UIImage) -> UIImage {
            var newImage = UIImage()
            switch uiImage.imageOrientation.rawValue {
            case 1:
                guard let orientedCIImage = CIImage(image: uiImage)?.oriented(CGImagePropertyOrientation.down),
                      let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { return uiImage}
                
                newImage = UIImage(cgImage: cgImage)
            case 3:
                guard let orientedCIImage = CIImage(image: uiImage)?.oriented(CGImagePropertyOrientation.right),
                        let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { return uiImage}
                newImage = UIImage(cgImage: cgImage)
            default:
                newImage = uiImage
            }
        return newImage
    }
}
    
extension CIImage {
    func resize(as size: CGSize) -> CIImage {
        let selfSize = extent.size
        let transform = CGAffineTransform(scaleX: size.width / selfSize.width, y: size.height / selfSize.height)
        return transformed(by: transform)
    }
}


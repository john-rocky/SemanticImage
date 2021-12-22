import Foundation
import Vision
import UIKit

public class SemanticImage {
    public private(set) var text = "Hello, World!"

    public init() {
    }
    
    lazy var personSegmentationRequest = VNGeneratePersonSegmentationRequest()
    lazy var faceRectangleRequest = VNDetectFaceRectanglesRequest()
    lazy var humanRectanglesRequest:VNDetectHumanRectanglesRequest = {
       let request = VNDetectHumanRectanglesRequest()
        request.upperBodyOnly = false
        return request
    }()
    lazy var animalRequest = VNRecognizeAnimalsRequest()

    let ciContext = CIContext()
    
    // MARK: Segmentation
    
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
    
    public func personBlur(uiImage:UIImage, intensity:Float) -> UIImage?{
        let newUIImage = getCorrectOrientationUIImage(uiImage:uiImage)
        guard let originalCIImage = CIImage(image: newUIImage),
              let maskUIImage = personMaskImage(uiImage: newUIImage),
              let maskCIImage = CIImage(image: maskUIImage) else { print("Image processing failed.Please try with another image."); return nil }
        let safeCropSize = CGRect(x: 0, y: 0, width: originalCIImage.extent.width * 0.999, height: originalCIImage.extent.height * 0.999)
        guard let blurBGCIImage = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputImageKey:originalCIImage,
                                                                         kCIInputRadiusKey:intensity])?.outputImage?.cropped(to: safeCropSize).resize(as: originalCIImage.extent.size) else { return nil }
        guard let blendedCIImage = CIFilter(name: "CIBlendWithMask", parameters: [
            kCIInputImageKey: originalCIImage,
            kCIInputBackgroundImageKey:blurBGCIImage,
            kCIInputMaskImageKey:maskCIImage])?.outputImage,
              let safeCGImage = ciContext.createCGImage(blendedCIImage, from: blendedCIImage.extent)else {  print("Image processing failed.Please try with another image."); return nil }
        
        let final = UIImage(cgImage: safeCGImage)
        return final
    }
    
    public func faceRectangle(uiImage:UIImage) -> UIImage? {
        let newImage = getCorrectOrientationUIImage(uiImage:uiImage)
        guard let ciImage = CIImage(image: newImage) else { print("Image processing failed.Please try with another image."); return nil }
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([faceRectangleRequest])
            guard let result = faceRectangleRequest.results?.first else { print("Image processing failed.Please try with another image."); return nil }
                let boundingBox = result.boundingBox
                let faceRect = VNImageRectForNormalizedRect((boundingBox),Int(ciImage.extent.size.width), Int(ciImage.extent.size.height))
            var doubleScaleRect = CGRect(x: faceRect.minX - faceRect.width * 0.5, y: faceRect.minY - faceRect.height * 0.5, width: faceRect.width * 2, height: faceRect.height * 2)
            if doubleScaleRect.minX < 0 {
                doubleScaleRect.origin.x = 0
            }

            if doubleScaleRect.minY < 0 {
                doubleScaleRect.origin.y = 0
            }
            if doubleScaleRect.maxX > ciImage.extent.maxX  {
                doubleScaleRect = CGRect(x: doubleScaleRect.origin.x, y: doubleScaleRect.origin.y, width: ciImage.extent.width - doubleScaleRect.origin.x, height: doubleScaleRect.height)
            }
            if doubleScaleRect.maxY > ciImage.extent.maxY  {
                doubleScaleRect = CGRect(x: doubleScaleRect.origin.x, y: doubleScaleRect.origin.y, width: doubleScaleRect.width, height: ciImage.extent.height - doubleScaleRect.origin.y)
            }
            
                let faceImage = ciImage.cropped(to: doubleScaleRect)
                guard let final = ciContext.createCGImage(faceImage, from: faceImage.extent) else { print("Image processing failed.Please try with another image."); return nil }
                let finalUiimage =  UIImage(cgImage: final)
                return finalUiimage
        } catch let error {
            print("Vision error \(error)")
            return nil
        }
    }
    
    // MARK: Rectangle
    
    public func faceRectangles(uiImage:UIImage) -> [UIImage] {
        var faceUIImages:[UIImage] = []
        let semaphore = DispatchSemaphore(value: 0)
        let newImage = getCorrectOrientationUIImage(uiImage:uiImage)
        guard let ciImage = CIImage(image: newImage) else { print("Image processing failed.Please try with another image."); return [] }
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([faceRectangleRequest])
            guard let results = faceRectangleRequest.results else { print("Image processing failed.Please try with another image."); return [] }
            guard !results.isEmpty else { print("Image processing failed.Please try with another image."); return [] }
            for result in results {
                let boundingBox = result.boundingBox
                let faceRect = VNImageRectForNormalizedRect((boundingBox),Int(ciImage.extent.size.width), Int(ciImage.extent.size.height))
            var doubleScaleRect = CGRect(x: faceRect.minX - faceRect.width * 0.5, y: faceRect.minY - faceRect.height * 0.5, width: faceRect.width * 2, height: faceRect.height * 2)
            if doubleScaleRect.minX < 0 {
                doubleScaleRect.origin.x = 0
            }

            if doubleScaleRect.minY < 0 {
                doubleScaleRect.origin.y = 0
            }
            if doubleScaleRect.maxX > ciImage.extent.maxX  {
                doubleScaleRect = CGRect(x: doubleScaleRect.origin.x, y: doubleScaleRect.origin.y, width: ciImage.extent.width - doubleScaleRect.origin.x, height: doubleScaleRect.height)
            }
            if doubleScaleRect.maxY > ciImage.extent.maxY  {
                doubleScaleRect = CGRect(x: doubleScaleRect.origin.x, y: doubleScaleRect.origin.y, width: doubleScaleRect.width, height: ciImage.extent.height - doubleScaleRect.origin.y)
            }
            
                let faceImage = ciImage.cropped(to: doubleScaleRect)
                guard let final = ciContext.createCGImage(faceImage, from: faceImage.extent) else { print("Image processing failed.Please try with another image."); return [] }
                let finalUiimage =  UIImage(cgImage: final)
                faceUIImages.append(finalUiimage)
                if faceUIImages.count == results.count {
                    semaphore.signal()
                }
            }
            semaphore.wait()
            return faceUIImages
        } catch let error {
            print("Vision error \(error)")
            return []
        }
    }
    
    public func humanRectangle(uiImage:UIImage) -> UIImage? {
        let newImage = getCorrectOrientationUIImage(uiImage:uiImage)
        guard let ciImage = CIImage(image: newImage) else { print("Image processing failed.Please try with another image."); return nil }
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([humanRectanglesRequest])
            guard let result = humanRectanglesRequest.results?.first else { print("Image processing failed.Please try with another image."); return nil }
            let boundingBox = result.boundingBox
            let humanRect = VNImageRectForNormalizedRect((boundingBox),Int(ciImage.extent.size.width), Int(ciImage.extent.size.height))
            let humanImage = ciImage.cropped(to: humanRect)
            guard let final = ciContext.createCGImage(humanImage, from: humanImage.extent) else { print("Image processing failed.Please try with another image."); return nil }
            let finalUiimage =  UIImage(cgImage: final)
            return finalUiimage
        } catch let error {
            print("Vision error \(error)")
            return nil
        }
    }
    
    public func humanRectangles(uiImage:UIImage) -> [UIImage] {
        var bodyUIImages:[UIImage] = []
        let semaphore = DispatchSemaphore(value: 0)
        let newImage = getCorrectOrientationUIImage(uiImage:uiImage)
        guard let ciImage = CIImage(image: newImage) else { print("Image processing failed.Please try with another image."); return [] }
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([humanRectanglesRequest])
            guard let results = humanRectanglesRequest.results else { print("Image processing failed.Please try with another image."); return [] }
            guard !results.isEmpty else { print("Image processing failed.Please try with another image."); return [] }
            
            for result in results {
                let boundingBox = result.boundingBox
                let humanRect = VNImageRectForNormalizedRect((boundingBox),Int(ciImage.extent.size.width), Int(ciImage.extent.size.height))
                let humanImage = ciImage.cropped(to: humanRect)
                guard let final = ciContext.createCGImage(humanImage, from: humanImage.extent) else { print("Image processing failed.Please try with another image."); return [] }
                let finalUiimage =  UIImage(cgImage: final)
                bodyUIImages.append(finalUiimage)
                if bodyUIImages.count == results.count {
                    semaphore.signal()
                }
            }
            semaphore.wait()
            return bodyUIImages
        } catch let error {
            print("Vision error \(error)")
            return []
        }
    }
    
    public func animalRectangle(uiImage:UIImage) -> UIImage?{
        
        let newImage = getCorrectOrientationUIImage(uiImage:uiImage)
        guard let ciImage = CIImage(image: newImage) else { print("Image processing failed.Please try with another image."); return nil }
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([animalRequest])
            guard let result = animalRequest.results?.first else { print("Image processing failed.Please try with another image."); return nil }
            let boundingBox = result.boundingBox
            let rect = VNImageRectForNormalizedRect((boundingBox),Int(ciImage.extent.size.width), Int(ciImage.extent.size.height))
            let croppedImage = ciImage.cropped(to: rect)
            guard let final = ciContext.createCGImage(croppedImage, from: croppedImage.extent) else { print("Image processing failed.Please try with another image."); return nil }
            let finalUiimage =  UIImage(cgImage: final)
            return finalUiimage
        } catch let error {
            print("Vision error \(error)")
            return nil
        }
    }
    
    public func animalRectangles(uiImage:UIImage) -> [UIImage] {
        var animalUIImages:[UIImage] = []
        let semaphore = DispatchSemaphore(value: 0)
        let newImage = getCorrectOrientationUIImage(uiImage:uiImage)
        guard let ciImage = CIImage(image: newImage) else { print("Image processing failed.Please try with another image."); return [] }
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([animalRequest])
            guard let results = animalRequest.results else { print("Image processing failed.Please try with another image."); return [] }
            guard !results.isEmpty else { print("Image processing failed.Please try with another image."); return [] }
            
            for result in results {
                let boundingBox = result.boundingBox
                let rect = VNImageRectForNormalizedRect((boundingBox),Int(ciImage.extent.size.width), Int(ciImage.extent.size.height))
                let croppedImage = ciImage.cropped(to: rect)
                guard let final = ciContext.createCGImage(croppedImage, from: croppedImage.extent) else { print("Image processing failed.Please try with another image."); return [] }
                let finalUiimage =  UIImage(cgImage: final)
                animalUIImages.append(finalUiimage)
                if animalUIImages.count == results.count {
                    semaphore.signal()
                }
            }
            semaphore.wait()
            return animalUIImages
        } catch let error {
            print("Vision error \(error)")
            return []
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


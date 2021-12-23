import Foundation
import Vision
import UIKit
import AVKit

public class SemanticImage {
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

    lazy var segmentationRequest:VNCoreMLRequest? =  {
        let url = try? Bundle.main.url(forResource: "segmentation", withExtension: "mlmodelc")
        let mlModel = try! MLModel(contentsOf: url!, configuration: MLModelConfiguration())
        guard let model = try? VNCoreMLModel(for: mlModel) else { return nil }
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFill
        return request
    }()
    
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
    
    // MARK: Saliency
    
    public func saliencyMask(uiImage:UIImage) -> UIImage? {
        let newImage = getCorrectOrientationUIImage(uiImage:uiImage)
        guard let ciImage = CIImage(image: newImage),
              let request = segmentationRequest else { print("Image processing failed.Please try with another image."); return nil }
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([request])
            guard let result = request.results?.first as? VNPixelBufferObservation
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
    
    public func saliencyBlend(objectUIImage:UIImage, backgroundUIImage: UIImage) -> UIImage? {
        let newSaliencyUIImage = getCorrectOrientationUIImage(uiImage:objectUIImage)
        let newBackgroundUIImage = getCorrectOrientationUIImage(uiImage:backgroundUIImage)
        
        guard let personCIImage = CIImage(image: newSaliencyUIImage),
              let backgroundCIImage = CIImage(image: newBackgroundUIImage),
              let maskUIImage = saliencyMask(uiImage: newSaliencyUIImage),
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
        print(traslatedBG.extent)
        guard let blended = CIFilter(name: "CIBlendWithMask", parameters: [
            kCIInputImageKey: personCIImage,
            kCIInputBackgroundImageKey:traslatedBG,
            kCIInputMaskImageKey:maskCIImage])?.outputImage,
              let safeCGImage = ciContext.createCGImage(blended, from: blended.extent) else { print("Image processing failed.Please try with another image."); return nil }
        let blendedUIImage = UIImage(cgImage: safeCGImage)
        return blendedUIImage
    }
    
    // MARK: Rectangle
    
    
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
    
    public func ciFilterVideo(videoURL:URL, _ ciFilter: CIFilter, _ completion: ((_ err: NSError?, _ filteredVideoURL: URL?) -> Void)?) {
        applyProcessingOnVideo(videoURL: videoURL, { ciImage in
            ciFilter.setValue(ciImage, forKey: kCIInputImageKey)
            let outCIImage = ciFilter.outputImage
            return outCIImage
        } , { err, processedVideoURL in
            guard err == nil else { print(err?.localizedDescription as Any); return }
            completion?(err,processedVideoURL)
        })
    }
    
    func applyProcessingOnVideo(videoURL:URL, _ processingFunction: @escaping ((CIImage) -> CIImage?), _ completion: ((_ err: NSError?, _ processedVideoURL: URL?) -> Void)?) {
        var frame:Int = 0
        var isFrameRotated = false
        let asset = AVURLAsset(url: videoURL)
        let duration = asset.duration.value
        let frameRate = asset.preferredRate
        let totalFrame = frameRate * Float(duration)
        let err: NSError = NSError.init(domain: "SemanticImage", code: 999, userInfo: [NSLocalizedDescriptionKey: "Video Processing Failed"])
        guard let writingDestinationUrl: URL  = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("\(Date())" + ".mp4") else { print("nil"); return}

        // setup

        guard let reader: AVAssetReader = try? AVAssetReader.init(asset: asset) else {
            completion?(err, nil)
            return
        }
        guard let writer: AVAssetWriter = try? AVAssetWriter(outputURL: writingDestinationUrl, fileType: AVFileType.mov) else {
            completion?(err, nil)
            return
        }
        
        // setup finish closure

        var audioFinished: Bool = false
        var videoFinished: Bool = false
        let writtingFinished: (() -> Void) = {
            if audioFinished == true && videoFinished == true {
                writer.finishWriting {
                    completion?(nil, writingDestinationUrl)
                }
                reader.cancelReading()
            }
        }
        
        // prepare video reader
        
        let readerVideoOutput: AVAssetReaderTrackOutput = AVAssetReaderTrackOutput(
            track: asset.tracks(withMediaType: AVMediaType.video)[0],
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
            ]
        )
        
        reader.add(readerVideoOutput)
        
        // prepare audio reader
        
        var readerAudioOutput: AVAssetReaderTrackOutput!
        if asset.tracks(withMediaType: AVMediaType.audio).count <= 0 {
            audioFinished = true
        } else {
            readerAudioOutput = AVAssetReaderTrackOutput.init(
                track: asset.tracks(withMediaType: AVMediaType.audio)[0],
                outputSettings: [
                    AVSampleRateKey: 44100,
                    AVFormatIDKey:   kAudioFormatLinearPCM,
                ]
            )
            if reader.canAdd(readerAudioOutput) {
                reader.add(readerAudioOutput)
            } else {
                print("Cannot add audio output reader")
                audioFinished = true
            }
        }
        
        // prepare video input
        
        let transform = asset.tracks(withMediaType: AVMediaType.video)[0].preferredTransform
        let radians = atan2(transform.b, transform.a)
        let degrees = (radians * 180.0) / .pi
        
        var writerVideoInput: AVAssetWriterInput
        switch degrees {
        case 90:
            let rotateTransform = CGAffineTransform(rotationAngle: 0)
            writerVideoInput = AVAssetWriterInput.init(
                mediaType: AVMediaType.video,
                outputSettings: [
                    AVVideoCodecKey:                 AVVideoCodecType.h264,
                    AVVideoWidthKey:                 asset.tracks(withMediaType: AVMediaType.video)[0].naturalSize.height,
                    AVVideoHeightKey:                asset.tracks(withMediaType: AVMediaType.video)[0].naturalSize.width,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: asset.tracks(withMediaType: AVMediaType.video)[0].estimatedDataRate,
                    ],
                ]
            )
            writerVideoInput.expectsMediaDataInRealTime = false
            
            isFrameRotated = true
            writerVideoInput.transform = rotateTransform
        default:
            writerVideoInput = AVAssetWriterInput.init(
                mediaType: AVMediaType.video,
                outputSettings: [
                    AVVideoCodecKey:                 AVVideoCodecType.h264,
                    AVVideoWidthKey:                 asset.tracks(withMediaType: AVMediaType.video)[0].naturalSize.width,
                    AVVideoHeightKey:                asset.tracks(withMediaType: AVMediaType.video)[0].naturalSize.height,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: asset.tracks(withMediaType: AVMediaType.video)[0].estimatedDataRate,
                    ],
                ]
            )
            writerVideoInput.expectsMediaDataInRealTime = false
            isFrameRotated = false
            writerVideoInput.transform = asset.tracks(withMediaType: AVMediaType.video)[0].preferredTransform
        }
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerVideoInput, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)])
        
        writer.add(writerVideoInput)
        
        
        // prepare writer input for audio
        
        var writerAudioInput: AVAssetWriterInput! = nil
        if asset.tracks(withMediaType: AVMediaType.audio).count > 0 {
            let formatDesc: [Any] = asset.tracks(withMediaType: AVMediaType.audio)[0].formatDescriptions
            var channels: UInt32 = 1
            var sampleRate: Float64 = 44100.000000
            for i in 0 ..< formatDesc.count {
                guard let bobTheDesc: UnsafePointer<AudioStreamBasicDescription> = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc[i] as! CMAudioFormatDescription) else {
                    continue
                }
                channels = bobTheDesc.pointee.mChannelsPerFrame
                sampleRate = bobTheDesc.pointee.mSampleRate
                break
            }
            writerAudioInput = AVAssetWriterInput.init(
                mediaType: AVMediaType.audio,
                outputSettings: [
                    AVFormatIDKey:         kAudioFormatMPEG4AAC,
                    AVNumberOfChannelsKey: channels,
                    AVSampleRateKey:       sampleRate,
                    AVEncoderBitRateKey:   128000,
                ]
            )
            writerAudioInput.expectsMediaDataInRealTime = true
            writer.add(writerAudioInput)
        }
        

        // write
        
        let videoQueue = DispatchQueue.init(label: "videoQueue")
        let audioQueue = DispatchQueue.init(label: "audioQueue")
        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: CMTime.zero)

        // write video
        
        writerVideoInput.requestMediaDataWhenReady(on: videoQueue) {
            while writerVideoInput.isReadyForMoreMediaData {
                autoreleasepool {
                    if let buffer = readerVideoOutput.copyNextSampleBuffer(),let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) {
                        frame += 1
                        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                        if isFrameRotated {
                            ciImage = ciImage.oriented(CGImagePropertyOrientation.right)
                        }
                        guard let outCIImage = processingFunction(ciImage) else { print("Video Processing Failed") ; return }
                        
                        let presentationTime = CMSampleBufferGetOutputPresentationTimeStamp(buffer)
                        var pixelBufferOut: CVPixelBuffer?
                        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferAdaptor.pixelBufferPool!, &pixelBufferOut)
                        self.ciContext.render(outCIImage, to: pixelBufferOut!)
                        pixelBufferAdaptor.append(pixelBufferOut!, withPresentationTime: presentationTime)
                        
//                        if frame % 100 == 0 {
//                            print("\(frame) / \(totalFrame) frames were processed..")
//                        }
                    } else {
                        writerVideoInput.markAsFinished()
                        DispatchQueue.main.async {
                            videoFinished = true
                            writtingFinished()
                        }
                    }
                }
            }
        }
        if writerAudioInput != nil {
            writerAudioInput.requestMediaDataWhenReady(on: audioQueue) {
                while writerAudioInput.isReadyForMoreMediaData {
                    autoreleasepool {
                        let buffer = readerAudioOutput.copyNextSampleBuffer()
                        if buffer != nil {
                            writerAudioInput.append(buffer!)
                        } else {
                            writerAudioInput.markAsFinished()
                            DispatchQueue.main.async {
                                audioFinished = true
                                writtingFinished()
                            }
                        }
                    }
                }
            }
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


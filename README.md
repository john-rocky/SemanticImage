# SemanticImage

The collection of image filters.

# How to use

### Setting Up

1, Add SemanticImage to your project as Swift Package with Swift Package Manager. 
   Or just drag SemanticImage.swift to your project.

2, Import and initialize SemanticImage

```swift
import SemanticImage
```

```swift
let semanticImage = SemanticImage()
```

Requires iOS 15 or above

# Filter Collection

### Original

<img width="300" src="https://user-images.githubusercontent.com/23278992/146860733-acf875a5-043c-4ebb-ab3c-f98e124f6a93.jpg">

### Person Mask

<img width="300" src="https://user-images.githubusercontent.com/23278992/146860762-01faf109-019f-4644-9e02-65c04adc1b79.JPG">


```swift
let maskImage:UIImage? = semanticImage.personMaskImage(uiImage: yourUIImage)
```

### Swap the background of a person

<img width="300" src="https://user-images.githubusercontent.com/23278992/146862832-14c0f002-b4e7-43c6-92e4-8595e99e15fd.JPG">

```swift
let swappedImage:UIImage? = sematicImage.swapBackgroundOfPerson(personUIImage: yourUIImage, backgroundUIImage: yourBackgroundUIImage)
```

### Crop a face rectangle

<img width="300" src="https://user-images.githubusercontent.com/23278992/147011663-326292e3-982b-4214-bbb5-ebb1ceb06e02.JPG">

```swift
let faceImage:UIImage? = sematicImage.faceRectangle(uiImage: image)
```

### Crop a body rectangle

<img width="300" src="https://user-images.githubusercontent.com/23278992/147012402-f3866730-4996-4036-b7c5-1358bad547b1.JPG">

```swift
let bodyImage:UIImage? = sematicImage.humanRectangle(uiImage: image)
```

### Crop face rectangles

<img width="300" src="https://user-images.githubusercontent.com/23278992/147014241-fca3ceb0-c042-4a64-96a5-ad54c3dde96e.JPEG"> <img width="100" src="https://user-images.githubusercontent.com/23278992/147014227-3a4aa167-3cd4-492f-a515-48ec7a7e2489.JPG"><img width="100" src="https://user-images.githubusercontent.com/23278992/147014232-559a7373-2288-4ee1-ac88-5b2cd7a9e65d.JPG"><img width="100" src="https://user-images.githubusercontent.com/23278992/147014233-819fd97a-138f-4de8-8c44-3f59742e68a0.JPG"><img width="100" src="https://user-images.githubusercontent.com/23278992/147014234-eddccca5-a2ae-46a9-9fec-1b7b1831ce22.JPG"><img width="100" src="https://user-images.githubusercontent.com/23278992/147014235-08347066-d97f-46aa-8810-9349f6481917.JPG"><img width="100" src="https://user-images.githubusercontent.com/23278992/147014237-8bb38476-3073-4dd7-9a72-b836e029dc9e.JPG"><img width="100" src="https://user-images.githubusercontent.com/23278992/147014238-8e9b5727-2821-4798-b66b-ae2fa8673c57.JPG">

```swift
let faceImages:[UIImage] = sematicImage.sematicImage.faceRectangles(uiImage: image)
```




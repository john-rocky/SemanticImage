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

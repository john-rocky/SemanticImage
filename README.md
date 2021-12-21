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

<img width="200" alt="スクリーンショット 2021-06-22 6 25 04" src="https://user-images.githubusercontent.com/23278992/146860733-acf875a5-043c-4ebb-ab3c-f98e124f6a93.jpg">

### Person Mask


<img src="https://user-images.githubusercontent.com/23278992/146860762-01faf109-019f-4644-9e02-65c04adc1b79.JPG", width=300>


```swift
let maskImage = semanticImage.personMaskImage(uiImage: yourUIImage)
```

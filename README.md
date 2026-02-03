# 📦 Eraser

A small iOS library that provides a mask-based erase/draw view over one or two images. Use your finger or a stylus to **erase** (reveal the bottom image) or **draw** (restore the top image) with undo/redo support.

## Requirements

- iOS 13+
- Swift 5.9+
- Xcode 15+

## Installation

### Swift Package Manager

Add the Eraser package to your project:

1. In Xcode: **File → Add Package Dependencies…**
2. Enter the repository URL (or add a local path to this package).
3. Add the **Eraser** library to your app target.

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/serhatakalin/Eraser.git", from: "1.0.0")
]
```

## Usage

### Two-layer (before / after)

Typical use: put **after** on top of **before**; **erase** reveals the bottom image, **draw** restores the top image on the same paths.

1. Create an `EraserView` and add it to your view hierarchy.
2. Set `lineWidth` (brush size) and `mode`: `.erase` or `.draw`.
3. Call `configure(foreground:afterImage, background:beforeImage)`.
4. Optionally set `onUndoRedoStateChanged` to enable/disable undo/redo buttons.

```swift
import Eraser

let eraserView = EraserView(frame: view.bounds)
view.addSubview(eraserView)

eraserView.lineWidth = 24
eraserView.mode = .erase
eraserView.onUndoRedoStateChanged = { canUndo, canRedo in
    undoButton.isEnabled = canUndo
    redoButton.isEnabled = canRedo
}
eraserView.configure(foreground: afterImage, background: beforeImage)
```

- **Mode `.erase`** — strokes reveal the **before** (bottom) image.
- **Mode `.draw`** — strokes bring back the **after** (top) image on those paths.

### Single image

Use `configure(with: image)` for a single image; erase/draw then affect that image with the view’s background showing where erased.

```swift
eraserView.configure(with: myImage)
```

### Undo / Redo / Reset

- `eraserView.undo()` — undo last stroke
- `eraserView.redo()` — redo last undone stroke  
- `eraserView.resetToMask()` — clear all strokes and reset

### Change image

- `eraserView.changeSource(for: anotherImage)` — replace the foreground (and optional background) and reinitialize.

## Demo

<img src="files/demo.gif" width="250" alt="Demo">

This repository includes an **EraserDemo** iOS app in the `Demo/` folder. Open `Demo/EraserDemo.xcodeproj` in Xcode (the Eraser package is linked as a local dependency), then run the EraserDemo scheme on a simulator or device. The demo uses **before** and **after** assets: the toolbar has mode (Erase / Draw), brush size, Undo, Redo, and Reset.

## License

See the repository license file.

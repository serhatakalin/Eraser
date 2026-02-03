//
//  ViewController.swift
//  EraserDemo
//
//  Created by Serhat Akalin
//

import UIKit
import Eraser

final class ViewController: UIViewController {

    private var eraserView: EraserView!
    private var toolbar: UIView!
    private var undoButton: UIButton!
    private var redoButton: UIButton!
    private var resetButton: UIButton!
    private var modeSegment: UISegmentedControl!
    private var lineWidthSlider: UISlider!
    private var lineWidthLabel: UILabel!
    private var didLoadInitialImage = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupEraserView()
        setupToolbar()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let toolbarHeight: CGFloat = 56
        let bottomInset = view.safeAreaInsets.bottom
        toolbar.frame = CGRect(x: 0, y: view.bounds.height - toolbarHeight - bottomInset, width: view.bounds.width, height: toolbarHeight)
        eraserView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: toolbar.frame.minY)
        layoutToolbarItems()
        if !didLoadInitialImage, eraserView.bounds.width > 0, eraserView.bounds.height > 0 {
            didLoadInitialImage = true
            loadSampleImage()
        }
    }

    private func setupEraserView() {
        eraserView = EraserView(frame: .zero)
        eraserView.backgroundColor = .secondarySystemBackground
        eraserView.lineWidth = 24
        eraserView.mode = .erase
        eraserView.onUndoRedoStateChanged = { [weak self] canUndo, canRedo in
            self?.undoButton.isEnabled = canUndo
            self?.redoButton.isEnabled = canRedo
        }
        view.addSubview(eraserView)
    }

    private func setupToolbar() {
        toolbar = UIView()
        toolbar.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        view.addSubview(toolbar)

        modeSegment = UISegmentedControl(items: ["Erase", "Draw"])
        modeSegment.selectedSegmentIndex = 0
        modeSegment.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        toolbar.addSubview(modeSegment)

        lineWidthLabel = UILabel()
        lineWidthLabel.text = "Brush size"
        lineWidthLabel.font = .systemFont(ofSize: 12)
        toolbar.addSubview(lineWidthLabel)

        lineWidthSlider = UISlider()
        lineWidthSlider.minimumValue = 8
        lineWidthSlider.maximumValue = 64
        lineWidthSlider.value = 24
        lineWidthSlider.addTarget(self, action: #selector(lineWidthChanged), for: .valueChanged)
        toolbar.addSubview(lineWidthSlider)

        undoButton = UIButton(type: .system)
        undoButton.setTitle("Undo", for: .normal)
        undoButton.isEnabled = false
        undoButton.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
        toolbar.addSubview(undoButton)

        redoButton = UIButton(type: .system)
        redoButton.setTitle("Redo", for: .normal)
        redoButton.isEnabled = false
        redoButton.addTarget(self, action: #selector(redoTapped), for: .touchUpInside)
        toolbar.addSubview(redoButton)

        resetButton = UIButton(type: .system)
        resetButton.setTitle("Reset", for: .normal)
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        toolbar.addSubview(resetButton)
    }

    private func layoutToolbarItems() {
        let margin: CGFloat = 16
        let spacing: CGFloat = 12
        var x = margin
        let y: CGFloat = 10
        let rowHeight: CGFloat = 36

        modeSegment.sizeToFit()
        modeSegment.frame.origin = CGPoint(x: x, y: y)
        x += modeSegment.bounds.width + spacing

        lineWidthLabel.sizeToFit()
        lineWidthLabel.frame.origin = CGPoint(x: x, y: y + (rowHeight - lineWidthLabel.bounds.height) / 2)
        x += lineWidthLabel.bounds.width + 8

        let brushSliderWidth: CGFloat = 100
        lineWidthSlider.frame = CGRect(x: x, y: y, width: brushSliderWidth, height: rowHeight)
        x += brushSliderWidth + spacing

        undoButton.sizeToFit()
        undoButton.frame = CGRect(x: x, y: y, width: undoButton.bounds.width, height: rowHeight)
        x += undoButton.bounds.width + spacing

        redoButton.sizeToFit()
        redoButton.frame = CGRect(x: x, y: y, width: redoButton.bounds.width, height: rowHeight)
        x += redoButton.bounds.width + spacing

        resetButton.sizeToFit()
        resetButton.frame = CGRect(x: x, y: y, width: resetButton.bounds.width, height: rowHeight)
    }

    private func loadSampleImage() {
        guard let beforeImage = UIImage(named: "before", in: nil, compatibleWith: nil),
              let afterImage = UIImage(named: "after", in: nil, compatibleWith: nil) else {
            fallbackSampleImage()
            return
        }
        eraserView.configure(foreground: afterImage, background: beforeImage)
    }

    private func fallbackSampleImage() {
        let size = CGSize(width: 400, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.systemPurple.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 80, y: 80, width: 240, height: 240))
            UIColor.systemOrange.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 140, y: 140, width: 120, height: 120))
        }
        eraserView.configure(with: image)
    }

    @objc private func modeChanged() {
        eraserView.mode = modeSegment.selectedSegmentIndex == 0 ? .erase : .draw
    }

    @objc private func undoTapped() {
        eraserView.undo()
    }

    @objc private func redoTapped() {
        eraserView.redo()
    }

    @objc private func resetTapped() {
        eraserView.resetToMask()
    }

    @objc private func lineWidthChanged() {
        eraserView.lineWidth = CGFloat(lineWidthSlider.value)
    }
}

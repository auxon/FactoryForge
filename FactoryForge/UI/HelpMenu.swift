import Foundation
import UIKit

/// Help menu that displays a list of documentation files
final class HelpMenu: UIPanel_Base {
    private var screenSize: Vector2 // Store screen size for coordinate conversion

    // Document list - dynamically loaded
    private var documents: [String] = []

    // UIKit scrolling for documents (like LoadingMenu)
    private var scrollView: UIScrollView?
    private var documentLabels: [UILabel] = [] // Clickable labels for documents

    private var closeButton: CloseButton!

    var onDocumentSelected: ((String) -> Void)? // Called when a document is selected
    var onCloseTapped: (() -> Void)? // Called when close button is tapped

    init(screenSize: Vector2) {
        self.screenSize = screenSize

        // Use full screen size for background
        let panelFrame = Rect(
            center: Vector2(screenSize.x / 2, screenSize.y / 2),
            size: Vector2(screenSize.x, screenSize.y)
        )

        super.init(frame: panelFrame)

        loadDocumentList()
        setupCloseButton()
        // Document buttons are created in setupLabels() when parent view is available
    }

    private func loadDocumentList() {
        // Try to load documents from the app bundle root (files are copied individually)
        if let resourcePath = Bundle.main.resourcePath,
           let fileManager = Optional(FileManager.default) {
            do {
                let files = try fileManager.contentsOfDirectory(atPath: resourcePath)
                documents = files.filter { $0.hasSuffix(".md") }.sorted()
                if !documents.isEmpty {
                    print("Successfully loaded \(documents.count) documents from bundle: \(documents)")
                }
            } catch {
                print("Could not load documents from bundle: \(error)")
            }
        }

        // If no documents found in bundle, try from source directory (for development)
        if documents.isEmpty {
            let fileManager = FileManager.default
            if let currentDir = fileManager.currentDirectoryPath as NSString? {
                let sourceDocsPath = currentDir.appendingPathComponent("FactoryForge/Docs")
                do {
                    let files = try fileManager.contentsOfDirectory(atPath: sourceDocsPath)
                    documents = files.filter { $0.hasSuffix(".md") }.sorted()
                    print("Loaded documents from source directory: \(documents)")
                } catch {
                    print("Could not load documents from source: \(error)")
                }
            }
        }

        // Fallback to hardcoded list if nothing found
        if documents.isEmpty {
            documents = [
                "INSTRUCTIONS.md",
                "Belt Mechanics.md",
                "Research.md",
                "How to Use a Furnace.md",
                "autoplay_plan.md"
            ]
        }

        print("HelpMenu: Loaded \(documents.count) documents: \(documents)")
    }

    private func setupCloseButton() {
        let buttonSize: Float = 30 * UIScale
        let buttonX = frame.maxX - 25 * UIScale
        let buttonY = frame.minY + 25 * UIScale

        closeButton = CloseButton(frame: Rect(center: Vector2(buttonX, buttonY), size: Vector2(buttonSize, buttonSize)))
        closeButton.onTap = { [weak self] in
            AudioManager.shared.playClickSound()
            self?.onCloseTapped?()
        }
    }

    // Document buttons are now created in setupLabels() as UIKit components

    private weak var parentView: UIView?

    private func setupScrollView(in parentView: UIView) {
        // Remove existing scroll view if any
        scrollView?.removeFromSuperview()

        let screenScale = CGFloat(UIScreen.main.scale)

        // Scroll view covers most of the screen, leaving space for close button and margins
        let scrollViewFrame = CGRect(
            x: 20 / screenScale, // Small margin
            y: 60 / screenScale, // Leave space at top for close button
            width: (CGFloat(screenSize.x) - 40) / screenScale, // Leave margins
            height: (CGFloat(screenSize.y) - 120) / screenScale // Leave space at top and bottom
        )

        scrollView = UIScrollView(frame: scrollViewFrame)
        scrollView?.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 0.9)
        scrollView?.layer.borderColor = UIColor.white.cgColor
        scrollView?.layer.borderWidth = 1.0
        scrollView?.layer.cornerRadius = 8.0
        scrollView?.showsVerticalScrollIndicator = true
        scrollView?.showsHorizontalScrollIndicator = false
        scrollView?.alwaysBounceVertical = true

        if let scrollView = scrollView {
            parentView.addSubview(scrollView)
            parentView.bringSubviewToFront(scrollView)
        }
    }

    /// Sets up UIScrollView with clickable UILabels for documents (like LoadingMenu)
    func setupLabels(in parentView: UIView) {
        self.parentView = parentView
        removeDocumentLabels()

        if documents.isEmpty {
            return
        }

        // Create scroll view for documents (similar to LoadingMenu)
        let scrollViewHeight: CGFloat = 400 // Taller scroll area for documents
        let scrollViewY = (parentView.bounds.height - scrollViewHeight) / 2 - 50 // Position above center
        let scrollViewFrame = CGRect(
            x: parentView.bounds.width * 0.1, // 10% margin on sides
            y: scrollViewY,
            width: parentView.bounds.width * 0.8, // 80% width
            height: scrollViewHeight
        )

        let scrollView = UIScrollView(frame: scrollViewFrame)
        scrollView.backgroundColor = UIColor(white: 0.1, alpha: 0.8)
        scrollView.layer.borderColor = UIColor(white: 0.3, alpha: 1).cgColor
        scrollView.layer.borderWidth = 2
        scrollView.layer.cornerRadius = 8
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true

        parentView.addSubview(scrollView)
        self.scrollView = scrollView

        // Calculate content size and create labels
        let labelHeight: CGFloat = 50
        let labelSpacing: CGFloat = 8
        let totalHeight = CGFloat(documents.count) * (labelHeight + labelSpacing) - labelSpacing

        scrollView.contentSize = CGSize(width: scrollViewFrame.width, height: max(totalHeight, scrollViewHeight))

        for (index, documentName) in documents.enumerated() {
            let labelY = CGFloat(index) * (labelHeight + labelSpacing)
            let labelFrame = CGRect(x: 8, y: labelY, width: scrollViewFrame.width - 16, height: labelHeight)

            let label = UILabel(frame: labelFrame)
            label.text = documentName.replacingOccurrences(of: ".md", with: "").replacingOccurrences(of: "_", with: " ")
            label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            label.textColor = .white
            label.backgroundColor = UIColor(white: 0.2, alpha: 0.8)
            label.textAlignment = .center
            label.layer.borderColor = UIColor(white: 0.4, alpha: 1).cgColor
            label.layer.borderWidth = 1
            label.layer.cornerRadius = 4
            label.isUserInteractionEnabled = true

            // Add tap gesture recognizer
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(documentLabelTapped(_:)))
            label.addGestureRecognizer(tapGesture)

            // Store document name for identification
            label.accessibilityIdentifier = documentName

            scrollView.addSubview(label)
            documentLabels.append(label)
        }

        scrollView.isHidden = !isOpen
    }

    @objc private func documentLabelTapped(_ gesture: UITapGestureRecognizer) {
        guard let label = gesture.view as? UILabel,
              let documentName = label.accessibilityIdentifier else { return }

        AudioManager.shared.playClickSound()
        print("HelpMenu: Document label tapped: \(documentName)")
        onDocumentSelected?(documentName)
    }

    // Labels are now created in setupLabels() and don't need separate updating

    private func removeDocumentLabels() {
        for label in documentLabels {
            label.removeFromSuperview()
        }
        documentLabels.removeAll()
    }

    private func removeScrollView() {
        scrollView?.removeFromSuperview()
        scrollView = nil
    }

    override func open() {
        super.open()
        // Show scroll view when menu opens
        scrollView?.isHidden = false
        // Scroll to top when opening
        scrollView?.setContentOffset(.zero, animated: false)
    }

    override func close() {
        super.close()
        // Hide scroll view when menu closes
        scrollView?.isHidden = true
    }

    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }

        super.render(renderer: renderer)

        // Render close button
        closeButton.render(renderer: renderer)

        // Render title
        renderTitle(renderer: renderer)

        // Document buttons are now UIKit labels in the scroll view
    }

    private func renderTitle(renderer: MetalRenderer) {
        // Title rendered as text (could use UILabel overlay if needed)
        // For now, just leave space for title
    }

    // Document rendering is now handled by UIKit scroll view

    override func handleTap(at position: Vector2) -> Bool {
        guard frame.contains(position) else { return false }

        // Check close button first
        if closeButton.handleTap(at: position) {
            return true
        }

        // Document taps are handled by UIKit gesture recognizers on the labels
        // Consume tap within panel bounds to prevent it from going to game world
        return true
    }
}

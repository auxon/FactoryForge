import Foundation
import UIKit

/// Document viewer that displays markdown content
@available(iOS 17.0, *)
final class DocumentViewer: UIPanel_Base {
    private var screenSize: Vector2 // Store screen size for coordinate conversion
    private var documentName: String
    private var documentContent: String = ""

    private var contentLabel: UILabel?
    private var scrollView: UIScrollView?
    private var closeButton: CloseButton!

    var onCloseTapped: (() -> Void)? // Called when close button is tapped

    init(screenSize: Vector2, documentName: String) {
        self.screenSize = screenSize
        self.documentName = documentName

        // Use full screen size for background
        let panelFrame = Rect(
            center: Vector2(screenSize.x / 2, screenSize.y / 2),
            size: Vector2(screenSize.x, screenSize.y)
        )

        super.init(frame: panelFrame)

        loadDocumentContent()
        setupCloseButton()
    }

    private func loadDocumentContent() {
        // Try multiple approaches to load the markdown file

        // First, try from the app bundle root (files are copied individually)
        if let bundlePath = Bundle.main.path(forResource: documentName, ofType: nil),
           let content = try? String(contentsOfFile: bundlePath, encoding: .utf8) {
            documentContent = content
            return
        }

        // Try from the source directory (for development)
        let fileManager = FileManager.default
        if let currentDir = fileManager.currentDirectoryPath as NSString? {
            let sourcePath = currentDir.appendingPathComponent("FactoryForge/Docs/\(documentName)")
            if let content = try? String(contentsOfFile: sourcePath, encoding: .utf8) {
                documentContent = content
                return
            }
        }

        // Fallback: provide some sample content based on document name
        documentContent = getFallbackContent(for: documentName)
    }

    private func getFallbackContent(for documentName: String) -> String {
        switch documentName {
        case "INSTRUCTIONS.md":
            return """
            # FactoryForge Instructions

            Welcome to FactoryForge! This is a factory automation game where you build and manage production lines.

            ## Getting Started
            1. Click "New Game" to start a new factory
            2. Use the build menu to place machines and belts
            3. Connect machines with transport belts
            4. Research new technologies to unlock advanced buildings

            ## Controls
            - Left click to select and place buildings
            - Right click to cancel placement
            - Use the menu button to access save/load options
            """
        case "Belt Mechanics.md":
            return """
            # Belt Mechanics

            Transport belts move items between buildings automatically.

            ## Belt Types
            - Transport Belt: Basic belt, moves items at normal speed
            - Fast Transport Belt: Moves items 2x faster
            - Express Transport Belt: Moves items 3x faster

            ## Belt Rules
            - Items move in the direction the belt is facing
            - Belts can merge and split automatically
            - Underground belts can cross under other belts
            """
        case "Research.md":
            return """
            # Research System

            Research new technologies to unlock advanced buildings and recipes.

            ## How to Research
            1. Build a Lab
            2. Supply science packs to the lab
            3. Wait for research to complete
            4. New technologies become available

            ## Science Packs
            - Automation Science Pack: Unlocks basic automation
            - Logistic Science Pack: Unlocks logistics improvements
            - Chemical Science Pack: Unlocks chemical processing
            - Production Science Pack: Unlocks advanced production
            """
        case "How to Use a Furnace.md":
            return """
            # How to Use a Furnace

            Furnaces smelt ore into plates and other materials.

            ## Basic Usage
            1. Place a furnace near your ore source
            2. Connect input with inserters or belts
            3. Connect output with belts
            4. Provide fuel (coal) to the furnace

            ## Furnace Types
            - Stone Furnace: Basic furnace, slow but cheap
            - Steel Furnace: Faster than stone furnace
            - Electric Furnace: Fastest furnace, requires electricity
            """
        case "autoplay_plan.md":
            return """
            # Autoplay System

            The autoplay system can automatically manage your factory.

            ## Features
            - Automatic resource gathering
            - Smart building placement
            - Production optimization
            - Research automation

            ## Usage
            1. Set up your basic factory
            2. Enable autoplay from the menu
            3. Watch as the system expands your factory
            """
        default:
            return "Document '\(documentName)' not found. Please check that the Docs folder is properly included in the app bundle."
        }
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

    private weak var parentView: UIView?

    /// Sets up UIScrollView overlay for document content
    func setupLabels(in parentView: UIView) {
        self.parentView = parentView
        setupScrollView(in: parentView)
        updateContentLabel()
    }

    private func setupScrollView(in parentView: UIView) {
        // Remove existing scroll view if any
        scrollView?.removeFromSuperview()

        let screenScale = CGFloat(UIScreen.main.scale)

        // Scroll view covers most of the screen, leaving space for close button
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

    private func updateContentLabel() {
        guard let scrollView = scrollView else { return }

        // Remove existing label
        removeContentLabel()

        // Create new label
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .white
        label.backgroundColor = .clear
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping

        // Format the markdown content (basic formatting)
        label.text = formatMarkdown(documentContent)

        scrollView.addSubview(label)
        contentLabel = label

        updateContentLabelPosition()
    }

    private func formatMarkdown(_ markdown: String) -> String {
        var formatted = markdown

        // Basic markdown formatting
        // Headers (# ## ###)
        formatted = formatted.replacingOccurrences(of: "^### (.+)$", with: "$1", options: .regularExpression, range: nil)
        formatted = formatted.replacingOccurrences(of: "^## (.+)$", with: "$1", options: .regularExpression, range: nil)
        formatted = formatted.replacingOccurrences(of: "^# (.+)$", with: "$1", options: .regularExpression, range: nil)

        // Bold (**text**)
        formatted = formatted.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "$1", options: .regularExpression, range: nil)

        // Italic (*text*)
        formatted = formatted.replacingOccurrences(of: "\\*([^*]+)\\*", with: "$1", options: .regularExpression, range: nil)

        // Code blocks (```) - just remove the markers
        formatted = formatted.replacingOccurrences(of: "```[^\n]*\n", with: "", options: .regularExpression, range: nil)
        formatted = formatted.replacingOccurrences(of: "```\n?", with: "", options: .regularExpression, range: nil)

        // Inline code (`) - just remove the backticks
        formatted = formatted.replacingOccurrences(of: "`([^`]+)`", with: "$1", options: .regularExpression, range: nil)

        return formatted
    }

    private func updateContentLabelPosition() {
        guard let label = contentLabel, let scrollView = scrollView else { return }

        let margin: CGFloat = 20 // Margin within scroll view

        // Content area within scroll view
        let contentWidth = scrollView.frame.width - 2 * margin

        // Calculate required height for the content
        let requiredHeight = label.sizeThatFits(CGSize(width: contentWidth, height: .greatestFiniteMagnitude)).height

        // Set label frame within scroll view
        label.frame = CGRect(
            x: margin,
            y: margin,
            width: contentWidth,
            height: requiredHeight
        )

        // Set scroll view content size
        scrollView.contentSize = CGSize(
            width: scrollView.frame.width,
            height: requiredHeight + 2 * margin
        )

        label.isHidden = !isOpen
    }

    private func removeContentLabel() {
        contentLabel?.removeFromSuperview()
        contentLabel = nil
    }

    private func removeScrollView() {
        scrollView?.removeFromSuperview()
        scrollView = nil
    }


    override func open() {
        super.open()
        scrollView?.isHidden = false
        contentLabel?.isHidden = false
        // Scroll to top when opening
        scrollView?.setContentOffset(.zero, animated: false)
    }

    override func close() {
        super.close()
        scrollView?.isHidden = true
        contentLabel?.isHidden = true
    }

    override func render(renderer: MetalRenderer) {
        guard isOpen else { return }

        super.render(renderer: renderer)

        // Render close button
        closeButton.render(renderer: renderer)

        // Render title
        renderTitle(renderer: renderer)
    }

    private func renderTitle(renderer: MetalRenderer) {
        // Title is rendered as part of content label
    }

    override func handleTap(at position: Vector2) -> Bool {
        guard frame.contains(position) else { return false }

        // Check close button first
        if closeButton.handleTap(at: position) {
            return true
        }

        return true // Consume tap within panel bounds
    }
}

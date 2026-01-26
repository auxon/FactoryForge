//
//  MachineUILayoutEngine.swift
//  FactoryForge
//
//  Layout Engine for Formal MachineUI Schema
//  Converts Groups/Anchors into UIKit Auto Layout constraints
//

import UIKit

class MachineUILayoutEngine {
    private let schema: MachineUISchema
    private let rootView: UIView

    // Grid guides for constraint anchors
    private var columnGuides: [UILayoutGuide] = []
    private var rowGuides: [UILayoutGuide] = []

    init(schema: MachineUISchema, rootView: UIView) {
        self.schema = schema
        self.rootView = rootView
        setupGridGuides()
    }

    private func setupGridGuides() {
        // Calculate available width and height using constraints (not bounds)
        let availableWidth = rootView.widthAnchor
        let availableHeight = rootView.heightAnchor
        
        // Create column guides
        for i in 0..<schema.layout.grid.columns {
            let guide = UILayoutGuide()
            rootView.addLayoutGuide(guide)
            columnGuides.append(guide)

            // Position guide horizontally using constraints
            if i == 0 {
                // First column starts after safe area and padding
                guide.leadingAnchor.constraint(
                    equalTo: rootView.leadingAnchor,
                    constant: schema.layout.safeArea.left + schema.layout.padding.x
                ).isActive = true
            } else {
                // Subsequent columns follow the previous one with gutter spacing
                let prevGuide = columnGuides[i - 1]
                guide.leadingAnchor.constraint(
                    equalTo: prevGuide.trailingAnchor,
                    constant: CGFloat(schema.layout.grid.gutterX)
                ).isActive = true
            }

            // Each column gets equal width (accounting for gutters)
            guide.widthAnchor.constraint(
                equalTo: availableWidth,
                multiplier: 1.0 / CGFloat(schema.layout.grid.columns),
                constant: -(CGFloat(schema.layout.grid.gutterX) * (CGFloat(schema.layout.grid.columns - 1) / CGFloat(schema.layout.grid.columns)))
            ).isActive = true
        }

        // Create row guides
        for i in 0..<schema.layout.grid.rows {
            let guide = UILayoutGuide()
            rootView.addLayoutGuide(guide)
            rowGuides.append(guide)

            // Position guide vertically using constraints
            if i == 0 {
                // First row starts after safe area and padding
                guide.topAnchor.constraint(
                    equalTo: rootView.topAnchor,
                    constant: schema.layout.safeArea.top + schema.layout.padding.y
                ).isActive = true
            } else {
                // Subsequent rows follow the previous one with gutter spacing
                let prevGuide = rowGuides[i - 1]
                guide.topAnchor.constraint(
                    equalTo: prevGuide.bottomAnchor,
                    constant: CGFloat(schema.layout.grid.gutterY)
                ).isActive = true
            }

            // Each row gets equal height (accounting for gutters)
            guide.heightAnchor.constraint(
                equalTo: availableHeight,
                multiplier: 1.0 / CGFloat(schema.layout.grid.rows),
                constant: -(CGFloat(schema.layout.grid.gutterY) * (CGFloat(schema.layout.grid.rows - 1) / CGFloat(schema.layout.grid.rows)))
            ).isActive = true
        }
    }

    func layoutGroup(_ group: Group, containerView: UIView) {
        // Position container using anchor
        let anchor = group.anchor

        // Top edge
        let topGuide = rowGuides[anchor.gridY]
        containerView.topAnchor.constraint(equalTo: topGuide.topAnchor).isActive = true

        // Width (span multiple columns)
        if anchor.spanX > 1 {
            // Spanning multiple columns
            let leadingGuide = columnGuides[anchor.gridX]
            let trailingGuide = columnGuides[anchor.gridX + anchor.spanX - 1]
            
            // Handle horizontal alignment for spanning elements
            switch anchor.alignX {
            case .center:
                // Center the container within the span
                let spanCenterGuide = UILayoutGuide()
                rootView.addLayoutGuide(spanCenterGuide)
                spanCenterGuide.leadingAnchor.constraint(equalTo: leadingGuide.leadingAnchor).isActive = true
                spanCenterGuide.trailingAnchor.constraint(equalTo: trailingGuide.trailingAnchor).isActive = true
                containerView.centerXAnchor.constraint(equalTo: spanCenterGuide.centerXAnchor).isActive = true
                // Width should be less than or equal to span width to allow centering
                containerView.widthAnchor.constraint(lessThanOrEqualTo: spanCenterGuide.widthAnchor).isActive = true
                // Set a preferred width (~0.9× span width per spec)
                containerView.widthAnchor.constraint(equalTo: spanCenterGuide.widthAnchor, multiplier: 0.9).priority = UILayoutPriority(750)
            case .leading:
                containerView.leadingAnchor.constraint(equalTo: leadingGuide.leadingAnchor).isActive = true
                containerView.trailingAnchor.constraint(equalTo: trailingGuide.trailingAnchor).isActive = true
            case .trailing:
                containerView.leadingAnchor.constraint(equalTo: leadingGuide.leadingAnchor).isActive = true
                containerView.trailingAnchor.constraint(equalTo: trailingGuide.trailingAnchor).isActive = true
            case .fill:
                containerView.leadingAnchor.constraint(equalTo: leadingGuide.leadingAnchor).isActive = true
                containerView.trailingAnchor.constraint(equalTo: trailingGuide.trailingAnchor).isActive = true
            default:
                containerView.leadingAnchor.constraint(equalTo: leadingGuide.leadingAnchor).isActive = true
                containerView.trailingAnchor.constraint(equalTo: trailingGuide.trailingAnchor).isActive = true
            }
        } else {
            // Single column - handle alignment
            let leadingGuide = columnGuides[anchor.gridX]
            switch anchor.alignX {
            case .leading, .fill:
                containerView.leadingAnchor.constraint(equalTo: leadingGuide.leadingAnchor).isActive = true
                containerView.widthAnchor.constraint(equalTo: leadingGuide.widthAnchor).isActive = true
            case .center:
                containerView.centerXAnchor.constraint(equalTo: leadingGuide.centerXAnchor).isActive = true
                containerView.widthAnchor.constraint(equalTo: leadingGuide.widthAnchor).isActive = true
            case .trailing:
                containerView.trailingAnchor.constraint(equalTo: leadingGuide.trailingAnchor).isActive = true
                containerView.widthAnchor.constraint(equalTo: leadingGuide.widthAnchor).isActive = true
            default:
                containerView.leadingAnchor.constraint(equalTo: leadingGuide.leadingAnchor).isActive = true
                containerView.widthAnchor.constraint(equalTo: leadingGuide.widthAnchor).isActive = true
            }
        }

        // Height (span multiple rows)
        if anchor.spanY > 1 {
            let bottomGuide = rowGuides[anchor.gridY + anchor.spanY - 1]
            containerView.bottomAnchor.constraint(equalTo: bottomGuide.bottomAnchor).isActive = true
        } else {
            containerView.heightAnchor.constraint(equalTo: topGuide.heightAnchor).isActive = true
        }

        // Apply vertical alignment for single-row items
        if anchor.spanY == 1 && anchor.spanX == 1 {
            applyAnchorAlignment(anchor, to: containerView)
        }
    }

    private func applyAnchorAlignment(_ anchor: Anchor, to view: UIView) {
        // Horizontal alignment
        switch anchor.alignX {
        case .leading:
            // Already positioned at leading edge by layoutGroup
            break
        case .center:
            // Center within spanned columns
            // Only add centerX constraint if we're not already constrained by leading/trailing
            // When spanning, leading/trailing are already set, so we need to center within that span
            if anchor.spanX > 1 {
                // Create a container guide that spans the columns, then center within it
                let startGuide = columnGuides[anchor.gridX]
                let endGuide = columnGuides[anchor.gridX + anchor.spanX - 1]
                // Center between start and end guides
                view.centerXAnchor.constraint(equalTo: startGuide.leadingAnchor, constant: (endGuide.trailingAnchor.constraint(equalTo: startGuide.leadingAnchor).constant) / 2).isActive = false
                // Better approach: center relative to the midpoint of the span
                let midX = NSLayoutConstraint(item: view, attribute: .centerX, relatedBy: .equal, toItem: startGuide, attribute: .leading, multiplier: 1.0, constant: 0)
                midX.isActive = false
                // Actually, when spanning, the view already fills the span. For center alignment with span,
                // we should remove the leading/trailing constraints and use centerX + width instead.
                // But that's complex. For now, just don't add centerX when spanning - the view already fills correctly.
                // The alignment is more about content within the view, not the view itself.
            } else {
                // Single column - center within it
                let guide = columnGuides[anchor.gridX]
                view.centerXAnchor.constraint(equalTo: guide.centerXAnchor).isActive = true
            }
        case .trailing:
            // When spanning, trailing is already set. For single column, adjust.
            if anchor.spanX == 1 {
                let guide = columnGuides[anchor.gridX]
                view.trailingAnchor.constraint(equalTo: guide.trailingAnchor).isActive = true
            }
            // For span > 1, trailing is already set by layoutGroup
        case .fill:
            // Already fills the span
            break
        default:
            break
        }

        // Vertical alignment
        switch anchor.alignY {
        case .top:
            // Already positioned at top edge
            break
        case .center:
            // Only center if not spanning (when spanning, top/bottom are already set)
            if anchor.spanY == 1 {
                let guide = rowGuides[anchor.gridY]
                view.centerYAnchor.constraint(equalTo: guide.centerYAnchor).isActive = true
            }
            // For span > 1, top/bottom are already set by layoutGroup
        case .bottom:
            // When spanning, bottom is already set. For single row, adjust.
            if anchor.spanY == 1 {
                let guide = rowGuides[anchor.gridY]
                view.bottomAnchor.constraint(equalTo: guide.bottomAnchor).isActive = true
            }
            // For span > 1, bottom is already set by layoutGroup
        case .fill:
            // Already fills the span
            break
        default:
            break
        }
    }

    func validateInvariants() throws {
        // Check that all groups have headers
        for group in schema.groups {
            if group.header.text.isEmpty {
                throw LayoutError.missingGroupHeader(groupID: group.id)
            }
        }

        // Check process constraints
        if let process = schema.process {
            if process.label.text.isEmpty {
                throw LayoutError.missingProcessLabel
            }

            // Check that progress is visually adjacent to process label
            _ = process.anchor // TODO: Add adjacency validation logic
        }

        // Check flow axis constraints
        if schema.layout.flowAxis == .leftToRight {
            let inputGroups = schema.groups.filter { $0.role == .input }
            let outputGroups = schema.groups.filter { $0.role == .output }
            let processAnchor = schema.process?.anchor

            if let processX = processAnchor?.gridX {
                // Inputs should be left of process
                for input in inputGroups {
                    if input.anchor.gridX >= processX {
                        throw LayoutError.invalidFlowPosition(groupID: input.id, expectedBefore: processX)
                    }
                }

                // Outputs should be right of process
                for output in outputGroups {
                    if output.anchor.gridX <= processX {
                        throw LayoutError.invalidFlowPosition(groupID: output.id, expectedAfter: processX)
                    }
                }
            }
        }
    }

    enum LayoutError: Error {
        case missingGroupHeader(groupID: String)
        case missingProcessLabel
        case invalidFlowPosition(groupID: String, expectedBefore: Int)
        case invalidFlowPosition(groupID: String, expectedAfter: Int)
    }
}

// MARK: - Schema UI References
struct SchemaUIReferences {
    // Group references: groupId -> (container, slotViews, stateLabel)
    var groupViews: [String: (container: UIView, slotViews: [UIView], stateLabel: UILabel?)] = [:]
    
    // Process references
    var processContainer: UIView?
    var processProgressBar: UIProgressView?
    var processLabel: UILabel?
    /// State label: idle / working / blocked (no fuel, no ore, etc.)
    var processStateLabel: UILabel?
    
    // Recipes panel references
    var recipesContainer: UIView?
    var recipesGrid: UIView?
}

// MARK: - Layout Builder
class MachineUIBuilder {
    private let schema: MachineUISchema
    var references = SchemaUIReferences()

    init(schema: MachineUISchema) {
        self.schema = schema
    }

    func build(in rootView: UIView) -> SchemaUIReferences {
        let layoutEngine = MachineUILayoutEngine(schema: schema, rootView: rootView)

        // Validate invariants first
        try? layoutEngine.validateInvariants()

        // Build groups
        for group in schema.groups {
            let (groupContainer, slotViews, stateLabel) = buildGroup(group, style: schema.style)
            rootView.addSubview(groupContainer)
            layoutEngine.layoutGroup(group, containerView: groupContainer)
            
            // Store references
            references.groupViews[group.id] = (groupContainer, slotViews, stateLabel)
        }

        // Build process if present
        if let process = schema.process {
            let (processContainer, processProgressBar, processLabel, processStateLabel) = buildProcess(process, style: schema.style)
            rootView.addSubview(processContainer)
            layoutEngine.layoutGroup(Group(
                id: process.id,
                role: .input, // dummy role
                header: process.label,
                anchor: process.anchor,
                content: Group.GroupContent(slots: [], stateText: nil as StateText?),
                chrome: nil
            ), containerView: processContainer)
            
            references.processContainer = processContainer
            references.processProgressBar = processProgressBar
            references.processLabel = processLabel
            references.processStateLabel = processStateLabel
        }

        // Build recipes panel if present
        if let recipes = schema.recipes {
            let (recipesContainer, recipesGrid) = buildRecipesPanel(recipes, style: schema.style)
            rootView.addSubview(recipesContainer)
            layoutEngine.layoutGroup(Group(
                id: "recipes",
                role: .input, // dummy role
                header: Group.GroupHeader(text: recipes.title, styleRole: .neutral, alignment: .leading, accessibilityLabel: nil),
                anchor: recipes.anchor,
                content: Group.GroupContent(slots: [], stateText: nil as StateText?),
                chrome: nil
            ), containerView: recipesContainer)
            
            // Store references
            references.recipesContainer = recipesContainer
            references.recipesGrid = recipesGrid
        }

        return references
    }

    private func buildGroup(_ group: Group, style: Style) -> (UIView, [UIView], UILabel?) {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Apply chrome styling - make containers visually distinct
        // Use more visible background for debugging
        container.backgroundColor = UIColor(hex: "#1a1a1a")?.withAlphaComponent(0.6) // More visible background
        container.layer.borderWidth = 2.0 // Thicker border for visibility
        container.layer.borderColor = UIColor(hex: "#666666")?.cgColor // Lighter border
        container.layer.cornerRadius = 6.0
        container.isHidden = false // Ensure visible

        // Apply custom chrome if specified
        if let chrome = group.chrome {
            if let bgColor = chrome.backgroundColor {
                container.backgroundColor = UIColor(hex: bgColor)
            }
            if let borderWidth = chrome.borderWidth {
                container.layer.borderWidth = CGFloat(borderWidth)
            }
            if let cornerRadius = chrome.cornerRadius {
                container.layer.cornerRadius = CGFloat(cornerRadius)
            }
        }

        // Build header - positioned at top of container
        let headerLabel = buildHeaderLabel(group.header, style: style)
        container.addSubview(headerLabel)

        // Position header at top with padding
        headerLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 4).isActive = true
        headerLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4).isActive = true
        headerLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4).isActive = true

        // Build slots container
        let (slotsContainer, slotViews) = buildSlotsContainer(group.content.slots, style: style)
        container.addSubview(slotsContainer)

        // Position slots below header
        slotsContainer.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8).isActive = true
        slotsContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4).isActive = true
        slotsContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4).isActive = true

        // Build and add state text if present
        var stateLabel: UILabel? = nil
        if let stateText = group.content.stateText {
            stateLabel = buildStateLabel(stateText, style: style)
            container.addSubview(stateLabel!)

            // Position state text below slots
            stateLabel!.topAnchor.constraint(equalTo: slotsContainer.bottomAnchor, constant: 4).isActive = true
            stateLabel!.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4).isActive = true
            stateLabel!.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4).isActive = true
            stateLabel!.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4).isActive = true
        } else {
            // No state text, constrain slots to bottom
            slotsContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4).isActive = true
        }

        return (container, slotViews, stateLabel)
    }

    private func buildHeaderLabel(_ header: Group.GroupHeader, style: Style) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = header.text
        label.font = .systemFont(ofSize: style.typography.headerSize, weight: .semibold)
        label.textColor = UIColor(hex: colorForStyleRole(header.styleRole, palette: style.palette))
        label.textAlignment = alignmentFor(header.alignment)
        label.accessibilityLabel = header.accessibilityLabel

        // Add subtle background for header to make it clearly part of the container
        label.backgroundColor = UIColor(hex: colorForStyleRole(header.styleRole, palette: style.palette))?.withAlphaComponent(0.1)
        label.layer.cornerRadius = 3.0
        label.layer.masksToBounds = true

        return label
    }

    private func buildStateLabel(_ stateText: StateText, style: Style) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = stateText.empty // Default to empty state
        label.font = .systemFont(ofSize: style.typography.mutedSize)
        label.textColor = UIColor(hex: style.palette.mutedText)
        label.textAlignment = .center
        label.numberOfLines = 0

        return label
    }

    private func buildSlotsContainer(_ slots: [Slot], style: Style) -> (UIStackView, [UIView]) {
        let container = UIStackView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.axis = .horizontal
        container.spacing = 8
        // Use .fill instead of .fillEqually to respect slot intrinsic sizes
        container.distribution = .fill
        container.alignment = .center

        var slotViews: [UIView] = []
        for slot in slots {
            let slotView = buildSlotView(slot, style: style)
            container.addArrangedSubview(slotView)
            slotViews.append(slotView)
        }

        return (container, slotViews)
    }

    private func buildSlotView(_ slot: Slot, style: Style) -> UIView {
        // Create a button for the slot (similar to legacy slot buttons)
        let button = UIKit.UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = UIColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 1.0)
        button.layer.borderWidth = 1.0
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.cornerRadius = 4.0

        // Size based on renders.sizeDp
        // Use lower priority so it can shrink if container is too small
        let widthConstraint = button.widthAnchor.constraint(equalToConstant: CGFloat(slot.renders.sizeDp))
        widthConstraint.priority = UILayoutPriority(750) // Below required (1000) but high enough to be preferred
        widthConstraint.isActive = true
        
        let heightConstraint = button.heightAnchor.constraint(equalToConstant: CGFloat(slot.renders.sizeDp))
        heightConstraint.isActive = true

        // Add count label overlay if specified
        if slot.renders.overlay == .count {
            let countLabel = UILabel()
            countLabel.translatesAutoresizingMaskIntoConstraints = false
            countLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
            countLabel.textColor = .white
            countLabel.textAlignment = .right
            countLabel.backgroundColor = .clear
            countLabel.text = ""
            countLabel.isHidden = true
            countLabel.tag = 999 // Tag to identify count labels
            button.addSubview(countLabel)
            
            // Position in bottom-right corner
            countLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -2).isActive = true
            countLabel.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -2).isActive = true
            
            // Store slot ID for reference
            button.accessibilityIdentifier = "slot_\(slot.id)"
        }

        return button
    }

    private func buildProcess(_ process: Process, style: Style) -> (UIView, UIProgressView, UILabel, UILabel) {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.clipsToBounds = false
        // Process is a first-class entity: distinct background and border so it reads as "the smelting step"
        container.backgroundColor = UIColor(hex: "#1a1a1a")?.withAlphaComponent(0.55)
        container.layer.borderWidth = 1.5
        container.layer.borderColor = (UIColor(hex: colorForStyleRole(.process, palette: style.palette))?.withAlphaComponent(0.8) ?? UIColor.orange).cgColor
        container.layer.cornerRadius = 6.0
        container.isHidden = false

        // Process name label (e.g. "Smelting")
        let label = buildHeaderLabel(process.label, style: style)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        container.addSubview(label)

        // Progress bar
        let progressBar = UIProgressView(progressViewStyle: .default)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.progressTintColor = UIColor(hex: colorForStyleRole(.process, palette: style.palette))
        progressBar.trackTintColor = UIColor(hex: "#444444")
        progressBar.progress = 0.0
        progressBar.layer.cornerRadius = 4.0
        progressBar.clipsToBounds = true
        container.addSubview(progressBar)

        let barHeight: CGFloat = (process.anchor.spanY >= 2) ? 40 : 28
        progressBar.heightAnchor.constraint(equalToConstant: barHeight).isActive = true
        progressBar.transform = CGAffineTransform.identity

        // State label: idle / working / blocked (updated at runtime)
        let stateLabel = UILabel()
        stateLabel.translatesAutoresizingMaskIntoConstraints = false
        stateLabel.text = "Idle"
        stateLabel.font = .systemFont(ofSize: CGFloat(style.typography.bodySize), weight: .regular)
        stateLabel.textColor = UIColor(hex: style.palette.mutedText)
        stateLabel.textAlignment = .center
        stateLabel.numberOfLines = 1
        stateLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        stateLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        container.addSubview(stateLabel)

        // Layout: name | 12pt | progress | 8pt | state | 12pt bottom
        label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10).isActive = true
        label.centerXAnchor.constraint(equalTo: container.centerXAnchor).isActive = true
        label.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 8).isActive = true
        label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8).isActive = true

        progressBar.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 10).isActive = true
        progressBar.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12).isActive = true
        progressBar.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12).isActive = true

        stateLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 8).isActive = true
        stateLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8).isActive = true
        stateLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8).isActive = true
        stateLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10).isActive = true

        // Ensure process never collapses below label + bar + state (label ~20pt, gaps 10+10+8, bar 40, state ~16, bottom 10)
        let minHeight = container.heightAnchor.constraint(greaterThanOrEqualToConstant: 104)
        minHeight.priority = UILayoutPriority(999)
        minHeight.isActive = true

        return (container, progressBar, label, stateLabel)
    }

    private func buildRecipesPanel(_ recipes: RecipesPanel, style: Style) -> (UIView, UIView) {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor(hex: "#2a2a2a")?.withAlphaComponent(0.5)
        container.layer.borderWidth = 1.0
        container.layer.borderColor = UIColor(hex: "#444444")?.cgColor
        container.layer.cornerRadius = 4.0

        // Build header
        let headerLabel = UILabel()
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.text = recipes.title
        headerLabel.font = .systemFont(ofSize: style.typography.headerSize, weight: .medium)
        headerLabel.textColor = UIColor(hex: style.palette.mutedText)
        headerLabel.textAlignment = .center
        container.addSubview(headerLabel)

        // Position header
        headerLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8).isActive = true
        headerLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8).isActive = true
        headerLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8).isActive = true

        // Create a simple grid of recipe placeholders
        let recipesGrid = UIView()
        recipesGrid.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(recipesGrid)

        recipesGrid.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8).isActive = true
        recipesGrid.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8).isActive = true
        recipesGrid.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8).isActive = true
        recipesGrid.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8).isActive = true

        // Add some placeholder recipe cells
        for i in 0..<6 {
            let cell = UIView()
            cell.translatesAutoresizingMaskIntoConstraints = false
            cell.backgroundColor = UIColor(hex: "#555555")?.withAlphaComponent(0.3)
            cell.layer.borderWidth = 1.0
            cell.layer.borderColor = UIColor(hex: "#777777")?.cgColor
            cell.layer.cornerRadius = 4.0

            recipesGrid.addSubview(cell)

            // Simple grid layout (this could be improved)
            let cellSize: CGFloat = 50
            let spacing: CGFloat = 8
            let cellsPerRow = 3
            let row = i / cellsPerRow
            let col = i % cellsPerRow

            cell.widthAnchor.constraint(equalToConstant: cellSize).isActive = true
            cell.heightAnchor.constraint(equalToConstant: cellSize).isActive = true

            if row == 0 && col == 0 {
                cell.topAnchor.constraint(equalTo: recipesGrid.topAnchor).isActive = true
                cell.leadingAnchor.constraint(equalTo: recipesGrid.leadingAnchor).isActive = true
            } else if col == 0 {
                cell.topAnchor.constraint(equalTo: recipesGrid.subviews[i - cellsPerRow].bottomAnchor, constant: spacing).isActive = true
                cell.leadingAnchor.constraint(equalTo: recipesGrid.leadingAnchor).isActive = true
            } else {
                cell.topAnchor.constraint(equalTo: recipesGrid.subviews[i - 1].topAnchor).isActive = true
                cell.leadingAnchor.constraint(equalTo: recipesGrid.subviews[i - 1].trailingAnchor, constant: spacing).isActive = true
            }
        }

        return (container, recipesGrid)
    }

    private func colorForStyleRole(_ role: Group.GroupHeader.StyleRole, palette: Style.Palette) -> String {
        switch role {
        case .fuel: return palette.fuel
        case .input: return palette.input
        case .output: return palette.output
        case .process: return palette.process
        case .neutral: return palette.mutedText
        }
    }

    private func alignmentFor(_ alignment: Group.GroupHeader.Alignment) -> NSTextAlignment {
        switch alignment {
        case .leading: return .left
        case .center: return .center
        case .trailing: return .right
        }
    }
}

// UIColor extension is already defined in MachineUI.swift

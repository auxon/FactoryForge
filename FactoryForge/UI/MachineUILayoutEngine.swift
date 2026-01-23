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
        // Create column guides
        for i in 0..<schema.layout.grid.columns {
            let guide = UILayoutGuide()
            rootView.addLayoutGuide(guide)
            columnGuides.append(guide)

            // Position guide horizontally
            let multiplier = CGFloat(i) / CGFloat(schema.layout.grid.columns)
            guide.leadingAnchor.constraint(
                equalTo: rootView.leadingAnchor,
                constant: schema.layout.safeArea.left + schema.layout.padding.x + (multiplier * (rootView.bounds.width - schema.layout.safeArea.left - schema.layout.safeArea.right - 2 * schema.layout.padding.x))
            ).isActive = true

            guide.widthAnchor.constraint(
                equalTo: rootView.widthAnchor,
                multiplier: 1.0 / CGFloat(schema.layout.grid.columns),
                constant: -CGFloat(schema.layout.grid.gutterX)
            ).isActive = true
        }

        // Create row guides
        for i in 0..<schema.layout.grid.rows {
            let guide = UILayoutGuide()
            rootView.addLayoutGuide(guide)
            rowGuides.append(guide)

            // Position guide vertically
            let multiplier = CGFloat(i) / CGFloat(schema.layout.grid.rows)
            guide.topAnchor.constraint(
                equalTo: rootView.topAnchor,
                constant: schema.layout.safeArea.top + schema.layout.padding.y + (multiplier * (rootView.bounds.height - schema.layout.safeArea.top - schema.layout.safeArea.bottom - 2 * schema.layout.padding.y))
            ).isActive = true

            guide.heightAnchor.constraint(
                equalTo: rootView.heightAnchor,
                multiplier: 1.0 / CGFloat(schema.layout.grid.rows),
                constant: -CGFloat(schema.layout.grid.gutterY)
            ).isActive = true
        }
    }

    func layoutGroup(_ group: Group, containerView: UIView) {
        // Position container using anchor
        let anchor = group.anchor

        // Leading edge
        let leadingGuide = columnGuides[anchor.gridX]
        containerView.leadingAnchor.constraint(equalTo: leadingGuide.leadingAnchor).isActive = true

        // Top edge
        let topGuide = rowGuides[anchor.gridY]
        containerView.topAnchor.constraint(equalTo: topGuide.topAnchor).isActive = true

        // Width (span multiple columns)
        if anchor.spanX > 1 {
            let trailingGuide = columnGuides[anchor.gridX + anchor.spanX - 1]
            containerView.trailingAnchor.constraint(equalTo: trailingGuide.trailingAnchor).isActive = true
        } else {
            containerView.widthAnchor.constraint(equalTo: leadingGuide.widthAnchor).isActive = true
        }

        // Height (span multiple rows)
        if anchor.spanY > 1 {
            let bottomGuide = rowGuides[anchor.gridY + anchor.spanY - 1]
            containerView.bottomAnchor.constraint(equalTo: bottomGuide.bottomAnchor).isActive = true
        } else {
            containerView.heightAnchor.constraint(equalTo: topGuide.heightAnchor).isActive = true
        }

        // Apply alignment within spanned area
        applyAnchorAlignment(anchor, to: containerView)
    }

    private func applyAnchorAlignment(_ anchor: Anchor, to view: UIView) {
        // Horizontal alignment
        switch anchor.alignX {
        case .leading:
            // Already positioned at leading edge
            break
        case .center:
            // Center within spanned columns
            if anchor.spanX > 1 {
                let startGuide = columnGuides[anchor.gridX]
                _ = columnGuides[anchor.gridX + anchor.spanX - 1] // endGuide not used in simplified centering
                view.centerXAnchor.constraint(equalTo: startGuide.centerXAnchor).isActive = true
                // Note: This is simplified - real centering would need more complex logic
            }
        case .trailing:
            if anchor.spanX > 1 {
                let endGuide = columnGuides[anchor.gridX + anchor.spanX - 1]
                view.trailingAnchor.constraint(equalTo: endGuide.trailingAnchor).isActive = true
            }
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
            if anchor.spanY > 1 {
                let startGuide = rowGuides[anchor.gridY]
                _ = rowGuides[anchor.gridY + anchor.spanY - 1] // endGuide not used in simplified centering
                view.centerYAnchor.constraint(equalTo: startGuide.centerYAnchor).isActive = true
            }
        case .bottom:
            if anchor.spanY > 1 {
                let endGuide = rowGuides[anchor.gridY + anchor.spanY - 1]
                view.bottomAnchor.constraint(equalTo: endGuide.bottomAnchor).isActive = true
            }
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

// MARK: - Layout Builder
class MachineUIBuilder {
    private let schema: MachineUISchema

    init(schema: MachineUISchema) {
        self.schema = schema
    }

    func build(in rootView: UIView) -> UIView {
        let layoutEngine = MachineUILayoutEngine(schema: schema, rootView: rootView)

        // Validate invariants first
        try? layoutEngine.validateInvariants()

        // Build groups
        for group in schema.groups {
            let groupContainer = buildGroup(group, style: schema.style)
            rootView.addSubview(groupContainer)
            layoutEngine.layoutGroup(group, containerView: groupContainer)
        }

        // Build process if present
        if let process = schema.process {
            let processContainer = buildProcess(process, style: schema.style)
            rootView.addSubview(processContainer)
            layoutEngine.layoutGroup(Group(
                id: process.id,
                role: .input, // dummy role
                header: process.label,
                anchor: process.anchor,
                content: Group.GroupContent(slots: [], stateText: nil as StateText?),
                chrome: nil
            ), containerView: processContainer)
        }

        // Build recipes panel if present
        if let recipes = schema.recipes {
            let recipesContainer = buildRecipesPanel(recipes, style: schema.style)
            rootView.addSubview(recipesContainer)
            layoutEngine.layoutGroup(Group(
                id: "recipes",
                role: .input, // dummy role
                header: Group.GroupHeader(text: recipes.title, styleRole: .neutral, alignment: .leading, accessibilityLabel: nil),
                anchor: recipes.anchor,
                content: Group.GroupContent(slots: [], stateText: nil as StateText?),
                chrome: nil
            ), containerView: recipesContainer)
        }

        return rootView
    }

    private func buildGroup(_ group: Group, style: Style) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Apply chrome styling - make containers visually distinct
        container.backgroundColor = UIColor(hex: "#1a1a1a")?.withAlphaComponent(0.3) // Subtle background
        container.layer.borderWidth = 1.0
        container.layer.borderColor = UIColor(hex: "#333333")?.cgColor
        container.layer.cornerRadius = 6.0

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
        let slotsContainer = buildSlotsContainer(group.content.slots, style: style)
        container.addSubview(slotsContainer)

        // Position slots below header
        slotsContainer.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8).isActive = true
        slotsContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4).isActive = true
        slotsContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4).isActive = true

        // Build and add state text if present
        if let stateText = group.content.stateText {
            let stateLabel = buildStateLabel(stateText, style: style)
            container.addSubview(stateLabel)

            // Position state text below slots
            stateLabel.topAnchor.constraint(equalTo: slotsContainer.bottomAnchor, constant: 4).isActive = true
            stateLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4).isActive = true
            stateLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4).isActive = true
            stateLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4).isActive = true
        } else {
            // No state text, constrain slots to bottom
            slotsContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4).isActive = true
        }

        return container
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

    private func buildSlotsContainer(_ slots: [Slot], style: Style) -> UIView {
        let container = UIStackView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.axis = .horizontal
        container.spacing = 8
        container.distribution = .fillEqually

        for slot in slots {
            let slotView = buildSlotView(slot, style: style)
            container.addArrangedSubview(slotView)
        }

        return container
    }

    private func buildSlotView(_ slot: Slot, style: Style) -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .gray // Placeholder
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.black.cgColor

        // Size based on renders.sizeDp
        view.widthAnchor.constraint(equalToConstant: CGFloat(slot.renders.sizeDp)).isActive = true
        view.heightAnchor.constraint(equalToConstant: CGFloat(slot.renders.sizeDp)).isActive = true

        return view
    }

    private func buildProcess(_ process: Process, style: Style) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Build process label
        let label = buildHeaderLabel(process.label, style: style)
        container.addSubview(label)

        // Build progress bar
        let progressBar = UIProgressView(progressViewStyle: .bar)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.progressTintColor = UIColor(hex: colorForStyleRole(.process, palette: style.palette))
        container.addSubview(progressBar)

        // Layout vertically
        label.topAnchor.constraint(equalTo: container.topAnchor).isActive = true
        label.centerXAnchor.constraint(equalTo: container.centerXAnchor).isActive = true

        progressBar.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8).isActive = true
        progressBar.leadingAnchor.constraint(equalTo: container.leadingAnchor).isActive = true
        progressBar.trailingAnchor.constraint(equalTo: container.trailingAnchor).isActive = true
        progressBar.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true

        return container
    }

    private func buildRecipesPanel(_ recipes: RecipesPanel, style: Style) -> UIView {
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

        return container
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
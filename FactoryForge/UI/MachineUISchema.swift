//
//  MachineUISchema.swift
//  FactoryForge
//
//  Formal MachineUI Layout Schema - Groups-based Architecture
//  Solves label anchoring issues by making labels children of Groups
//

import Foundation

// MARK: - Top-level Document
struct MachineUISchema: Codable {
    let schema: String
    let version: String
    let id: String
    let machineKind: String
    let title: String
    let layout: Layout
    let groups: [Group]
    let process: Process?
    let recipes: RecipesPanel?
    let style: Style
    let invariants: [String]

    enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case version, id, machineKind, title, layout, groups, process, recipes, style, invariants
    }
}

// MARK: - Layout
struct Layout: Codable {
    let flowAxis: FlowAxis
    let safeArea: SafeArea
    let padding: Padding
    let grid: Grid

    enum FlowAxis: String, Codable {
        case leftToRight, topToBottom
    }

    struct SafeArea: Codable {
        let top: Double
        let left: Double
        let bottom: Double
        let right: Double
    }

    struct Padding: Codable {
        let x: Double
        let y: Double
    }

    struct Grid: Codable {
        let columns: Int
        let rows: Int
        let gutterX: Double
        let gutterY: Double
    }
}

// MARK: - Group
struct Group: Codable {
    let id: String
    let role: GroupRole
    let header: GroupHeader
    let anchor: Anchor
    let content: GroupContent
    let chrome: GroupChrome?

    enum GroupRole: String, Codable {
        case fuel, input, output, byproduct, catalyst, fluidInput, fluidOutput, power
    }

    struct GroupHeader: Codable {
        let text: String
        let styleRole: StyleRole
        let alignment: Alignment
        let accessibilityLabel: String?

        enum StyleRole: String, Codable {
            case fuel, input, output, process, neutral
        }

        enum Alignment: String, Codable {
            case leading, center, trailing
        }
    }

    struct GroupContent: Codable {
        let slots: [Slot]
        let stateText: StateText?
    }

    struct GroupChrome: Codable {
        let backgroundColor: String?
        let borderWidth: Double?
        let cornerRadius: Double?
    }
}

// MARK: - Anchor
struct Anchor: Codable {
    let gridX: Int
    let gridY: Int
    let spanX: Int
    let spanY: Int
    let alignX: Alignment
    let alignY: Alignment

    enum Alignment: String, Codable {
        case leading, center, trailing, fill, top, bottom
    }
}

// MARK: - Slot
struct Slot: Codable {
    let id: String
    let slotKind: SlotKind
    let capacity: Capacity
    let accepts: Accepts
    let renders: Renders

    enum SlotKind: String, Codable {
        case item, fluid, power, tool
    }

    struct Capacity: Codable {
        let maxStacks: Int
        let maxAmount: Double?
    }

    struct Accepts: Codable {
        let tags: [String]?
        let itemIds: [String]?
        let fluidTypes: [Int]?
    }

    struct Renders: Codable {
        let sizeDp: Double
        let style: RenderStyle
        let overlay: Overlay?

        enum RenderStyle: String, Codable {
            case square, tank, meter
        }

        enum Overlay: String, Codable {
            case none, count, percent, connection
        }
    }
}

// MARK: - State Text
struct StateText: Codable {
    let mode: Mode
    let empty: String
    let nonEmpty: String?

    enum Mode: String, Codable {
        case auto, always, never
    }
}

// MARK: - Process
struct Process: Codable {
    let id: String
    let label: Group.GroupHeader
    let anchor: Anchor
    let progress: Progress
    let operators: Operators

    struct Progress: Codable {
        let style: ProgressStyle
        let bindTo: BindTo
        let showPercent: Bool

        enum ProgressStyle: String, Codable {
            case bar, ring, none
        }

        enum BindTo: String, Codable {
            case recipeProgress, fuelBurn, machineWarmup
        }
    }

    struct Operators: Codable {
        let showFlowGlyphs: Bool
        let glyphStyleRole: StyleRole

        enum StyleRole: String, Codable {
            case neutral, muted
        }
    }
}

// MARK: - Recipes Panel
struct RecipesPanel: Codable {
    let title: String
    let mode: Mode
    let anchor: Anchor
    let grid: RecipeGrid

    enum Mode: String, Codable {
        case picker, list, hidden
    }

    struct RecipeGrid: Codable {
        let cellSizeDp: Double
        let columns: Int
        let rowSpacingDp: Double
        let colSpacingDp: Double
    }
}

// MARK: - Style
struct Style: Codable {
    let palette: Palette
    let typography: Typography
    let chrome: Chrome

    struct Palette: Codable {
        let fuel: String
        let input: String
        let output: String
        let process: String
        let mutedText: String
    }

    struct Typography: Codable {
        let headerSize: Double
        let bodySize: Double
        let mutedSize: Double
    }

    struct Chrome: Codable {
        let panelOpacity: Double
        let cornerRadiusDp: Double
        let labelBackplateOpacity: Double
    }
}
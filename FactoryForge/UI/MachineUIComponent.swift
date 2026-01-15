//
//  MachineUIComponent.swift
//  FactoryForge
//
//  Created by Richard Anthony Hein on 2026-01-15.
//
import Foundation
import UIKit

/// Protocol for machine UI components
protocol MachineUIComponent {
    func setupUI(for entity: Entity, in ui: MachineUI)
    func updateUI(for entity: Entity, in ui: MachineUI)
    func getLabels() -> [UILabel]
    func getScrollViews() -> [UIScrollView]
    func render(in renderer: MetalRenderer)
}

/// Base class for machine UI components with shared fluid color utilities
class BaseMachineUIComponent: MachineUIComponent {

    func setupUI(for entity: Entity, in ui: MachineUI) {
        // Base implementation - override in subclasses
    }

    func updateUI(for entity: Entity, in ui: MachineUI) {
        // Base implementation - override in subclasses
    }

    func getLabels() -> [UILabel] {
        return []
    }

    func getScrollViews() -> [UIScrollView] {
        return []
    }

    func render(in renderer: MetalRenderer) {
        // Base implementation - override in subclasses
    }
}

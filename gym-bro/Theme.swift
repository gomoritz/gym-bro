//
//  Theme.swift
//  gym-bro
//

import SwiftUI

enum Theme {
    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radii

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let pill: CGFloat = 100
    }

    // MARK: - Touch Targets

    enum TouchTarget {
        static let minimum: CGFloat = 44
        static let comfortable: CGFloat = 52
        static let large: CGFloat = 60
    }

    // MARK: - Accent Colors

    enum Colors {
        static let primary = Color.blue
        static let success = Color.green
        static let warning = Color.orange
        static let danger = Color.red
        static let volume = Color.purple
        static let energy = Color.yellow
        static let timer = Color.orange
        static let transition = Color.blue
    }
}

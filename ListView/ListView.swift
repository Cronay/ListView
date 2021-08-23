//
//  ListView.swift
//  ListView
//
//  Created by Yannic Borgfeld on 23.08.21.
//

import Foundation
import UIKit

struct Vertical {
    var y: CGFloat
    var height: CGFloat
    
    var maxY: CGFloat { y + height }
    
    init(y: CGFloat, height: CGFloat) {
        precondition(height >= 0)
        self.y = y
        self.height = height
    }
    
    func intersect(_ other: Vertical) -> Bool {
        maxY >= other.y && y <= other.maxY
    }
    
    func intersect(_ rect: CGRect) -> Bool {
        intersect(rect.vertical)
    }
}

extension CGRect {
    var vertical: Vertical {
        Vertical(y: minY, height: height)
    }
}

struct Index: Hashable, Comparable {
    var section: Int
    var row: Int
    
    static func < (lhs: Index, rhs: Index) -> Bool {
        lhs.section < rhs.section || (lhs.section == rhs.section && lhs.row < rhs.row)
    }
}

final class ListView: UIScrollView {
    
    static let defaultRowHeight: CGFloat = 50
    
    private(set) var sectionDimensions = [Int]()
    private(set) var displayedRows = [Index: RowView]()
    private(set) var verticals = [Index: Vertical]()
    
    private var reusePool = [ObjectIdentifier: [RowView]]()

    private var rowViewSource: ((Index, ListView) -> RowView)? = nil
    
    init() {
        super.init(frame: .zero)
        alwaysBounceVertical = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // We get all verticals which intersect with the list views bounds which means they are within the view
        let visibles: [(Index, Vertical)] = verticals.filter { $0.value.intersect(bounds) }
        
        // Hide views which are disappearing and add them to the reuse pool again
        for index in displayedRows.keys {
            if !visibles.contains(where: { $0.0 == index }) {
                reuse(at: index)
            }
        }
        
        assert(displayedRows.keys.allSatisfy { index in visibles.contains { $0.0 == index } }, "Not all hidden rows were reused!")
        
        // Check if all visible rows have a view
        for (index, vertical) in visibles {
            let view = getView(for: index)
            let frame = frame(for: vertical)
            
            if view.frame != frame {
                view.frame = frame
            }
        }
        
        assert(visibles.allSatisfy { displayedRows.keys.contains($0.0) }, "Not all visible rows are actually displayed!")
        assert(displayedRows.allSatisfy { $0.value.isHidden == false }, "Not all visible rows are unhidden!")
    }
    
    func reload(sectionDimensions: [Int], rowViewSource: @escaping (Index, ListView) -> RowView) {
        self.rowViewSource = rowViewSource
        
        for index in displayedRows.keys {
            reuse(at: index)
        }
        
        assert(displayedRows.isEmpty)
        
        let rowCount = sectionDimensions.reduce(0, +)
        
        verticals.removeAll(keepingCapacity: true)
        verticals.reserveCapacity(rowCount)
        
        var currentY: CGFloat = 0
        for section in sectionDimensions.indices {
            for row in 0..<sectionDimensions[section] {
                let index = Index(section: section, row: row)
                let vertical = Vertical(y: currentY, height: ListView.defaultRowHeight)
                verticals[index] = vertical
                currentY = vertical.maxY
            }
        }
        
        self.sectionDimensions = sectionDimensions
        
        bounds.origin = .zero
        contentSize.height = currentY
        setNeedsLayout()
    }

    private func reuse(at index: Index) {
        let view = displayedRows[index]!
        view.isHidden = true
        displayedRows[index] = nil
        
        let type = type(of: view)
        let poolKey = ObjectIdentifier(type)
        
        assert(reusePool[poolKey] != nil, "Should create a pool for \(poolKey) when first dequeuing the row")
        reusePool[poolKey]!.append(view)
    }

    private func getView(for index: Index) -> RowView {
        guard displayedRows[index] == nil else { return displayedRows[index]! }

        let view: RowView = rowViewSource!(index, self)
        
        view.isHidden = false
        view.autoresizingMask = []
        // Because we perform layout manually, we need to explicitly re-enable this property
        view.translatesAutoresizingMaskIntoConstraints = true
        
        displayedRows[index] = view
        
        return view
    }
    
    private func frame(for vertical: Vertical) -> CGRect {
        return CGRect(x: bounds.minX,
                      y: vertical.y,
                      width: bounds.width,
                      height: vertical.height)
    }
    
    func dequeueRow<V: RowView>(type: V.Type, at index: Index) -> V {
        let poolKey = ObjectIdentifier(V.self)
        
        let view: V
        if reusePool[poolKey] == nil {
            reusePool[poolKey] = []
            view = V()
        } else if reusePool[poolKey]!.isEmpty {
            view = V()
        } else {
            view = reusePool[poolKey]!.popLast()! as! V
        }
        
        addSubview(view)
        return view
    }

}

protocol RowView: UIView {
    init()
}

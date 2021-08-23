//
//  ViewController.swift
//  ListView
//
//  Created by Yannic Borgfeld on 23.08.21.
//

import UIKit

class ViewController: UIViewController {

    private let listView = ListView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(listView)
        listView.backgroundColor = .red
        
        listView.reload(sectionDimensions: [3]) { index, listView in
            let label = listView.dequeueRow(type: UILabel.self, at: index)
            label.backgroundColor = .blue
            label.text = "Section: \(index.section), Row: \(index.row)"
            return label
        }
    }

    override func viewWillLayoutSubviews() {
        listView.frame = view.bounds.inset(by: view.safeAreaInsets).insetBy(dx: 16, dy: 16)
    }
}

extension UILabel: RowView {}


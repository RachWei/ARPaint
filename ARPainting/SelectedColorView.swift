//
//  SelectedColorView.swift
//  ARPainting
//
//  Created by Rong le on 5/24/20.
//  Copyright © 2020 collectiveidea. All rights reserved.
//

import Foundation
import UIKit

class SelectedColorView: UIView {
    var color: UIColor!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    init(frame: CGRect, color: UIColor) {
        super.init(frame: frame)
        
        setViewColor(color)
    }
    
    func setViewColor(_ _color: UIColor) {
        color = _color
        print("setViewColor: \(color)")
        setBackgroundColor()
    }
    
    func setBackgroundColor() {
        backgroundColor = color
    }
}

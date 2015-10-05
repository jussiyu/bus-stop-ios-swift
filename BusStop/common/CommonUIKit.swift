// Copyright (c) 2015 Solipaste Oy
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


import Foundation
import UIKit

// MARK: - NSLayoutConstraint
extension NSLayoutConstraint {
  class func constraintsWithVisualFormat(format: String, options opts: NSLayoutFormatOptions = NSLayoutFormatOptions(rawValue: 0), metrics: [String : AnyObject] = [:], views: [String : AnyObject] = [:], active: Bool) -> [NSLayoutConstraint] {
    let constraints = NSLayoutConstraint.constraintsWithVisualFormat(format, options: opts, metrics: metrics, views: views) 
    if active {
      NSLayoutConstraint.activateConstraints(constraints)
    }
    return constraints
  }
}

// MARK: - UIView
extension UIView {
  func constraintsWithIdentifier(identifier: String) -> [NSLayoutConstraint] {
    var matching = [NSLayoutConstraint]()
    for c in constraints {
      if c.identifier == identifier {
        matching.append(c)
      }
    }
    return matching
  }
}

// MARK: - UITableView
extension UITableView {
  func scrollToTop(animated animated: Bool) {
    // This is trigger didscroll messages
    self.setContentOffset(CGPoint(x: 0,y: 0), animated: true)
  }
}

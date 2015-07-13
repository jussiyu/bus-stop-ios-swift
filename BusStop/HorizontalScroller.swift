//
//  HorizontalScroller.swift
//  Pods
//
//  Created by Jussi Yli-Urpo on 13.7.15.
//
//

import UIKit

@objc protocol HorizontalScrollerDelegate: class {
  func numberOfItemsInHorizontalScroller(horizontalScroller: HorizontalScroller) -> Int
  func horizontalScroller(horizontalScroller: HorizontalScroller, viewAtIndexPath indexPath: Int) -> UIView
  optional func initialViewIndex(horizontalScroller: HorizontalScroller) -> Int
}

class HorizontalScroller: UIView {
  
  weak var delegate: HorizontalScrollerDelegate?
  
  private var scroller: UIScrollView!
  private var contentView: UIView!
  var viewArray = [UIView]()

  let VIEW_OFFSET: CGFloat = 100
  let VIEW_PADDING: CGFloat = 10
  
  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    initialize()
  }
  
  private func initialize() {
    self.backgroundColor = UIColor.brownColor()
    scroller = UIScrollView()
    scroller.setTranslatesAutoresizingMaskIntoConstraints(false)
    scroller.decelerationRate = UIScrollViewDecelerationRateFast
    addSubview(scroller)
    contentView = UIView(frame: CGRect(x: 0, y: 0, width: 2000, height: 129))
    scroller.addSubview(contentView)
    
    
    self.addConstraint(NSLayoutConstraint(item: scroller, attribute: .Leading, relatedBy: .Equal, toItem: self, attribute: .Leading, multiplier: 1.0, constant: 0.0))
//    self.addConstraint(NSLayoutConstraint(item: scroller, attribute: .Trailing, relatedBy: .Equal, toItem: self, attribute: .Trailing, multiplier: 1.0, constant: 0.0))
    self.addConstraint(NSLayoutConstraint(item: scroller, attribute: .Width, relatedBy: .Equal, toItem: self, attribute: .Width, multiplier: 1.0, constant: 0.0))
    self.addConstraint(NSLayoutConstraint(item: scroller, attribute: .Top, relatedBy: .Equal, toItem: self, attribute: .Top, multiplier: 1.0, constant: 0.0))
    self.addConstraint(NSLayoutConstraint(item: scroller, attribute: .Bottom, relatedBy: .Equal, toItem: self, attribute: .Bottom, multiplier: 1.0, constant: 0.0))
  }
  
  func viewAtIndex(index: Int) -> UIView {
    return viewArray[index]
  }
  
  func reload() {
    if let delegate = delegate {
      viewArray = []
      
      let views = contentView.subviews
      for view in views {
        view.removeFromSuperview()
      }
      var xValue = VIEW_OFFSET
      
      for index in 0..<delegate.numberOfItemsInHorizontalScroller(self) {
        xValue += VIEW_PADDING
        let subView = delegate.horizontalScroller(self, viewAtIndexPath: index)
//        subView.frame.origin.x = CGFloat(xValue)
        contentView.addSubview(subView)
        subView.setTranslatesAutoresizingMaskIntoConstraints(false)
        contentView.addConstraint(NSLayoutConstraint(item: subView, attribute: .Top, relatedBy: .Equal, toItem: contentView, attribute: .Top, multiplier: 1.0, constant: VIEW_PADDING))
        contentView.addConstraint(NSLayoutConstraint(item: subView, attribute: .Leading, relatedBy: .Equal, toItem: contentView, attribute: .Leading, multiplier: 1.0, constant: xValue))
        subView.addConstraint(NSLayoutConstraint(item: subView, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: 200))
        subView.addConstraint(NSLayoutConstraint(item: subView, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: 129))
        //        subView.frame = CGRectMake(CGFloat(xValue), CGFloat(0), subView.bounds.height, subView.bounds.width)
        xValue += 200 + VIEW_PADDING
        viewArray.append(subView)
      }
      
      if viewArray.count > 0 {
        contentView.addConstraint(NSLayoutConstraint(item: viewArray.last!, attribute: .Trailing, relatedBy: .Equal, toItem: contentView, attribute: .Trailing, multiplier: 1.0, constant: VIEW_PADDING))
      }
      scroller.contentSize = CGSizeMake(CGFloat(xValue + VIEW_PADDING), frame.size.height)
      contentView.frame = CGRect(x: 0, y: 0, width: CGFloat(xValue + VIEW_PADDING), height: frame.size.height)
      
      if let initialView = delegate.initialViewIndex?(self) {
        scroller.setContentOffset(CGPoint(x: CGFloat(VIEW_PADDING), y: 0), animated: true)
//        scroller.setContentOffset(CGPoint(x: CGFloat(initialView)*CGFloat((VIEW_DIMENSIONS + (2 * VIEW_PADDING))), y: 0), animated: true)
      }
      println("Scroller contentsize: \(scroller.contentSize)")
      println("Scroller bounds: \(scroller.bounds)")
      println("Scroller frame: \(scroller.frame)")
      println("contentview bounds: \(contentView.bounds)")
      println("contentview frame: \(contentView.frame)")
      println("contentview origin: \(contentView.frame.origin)")
      println("horiz bounds: \(self.bounds)")
      println("horiz frame: \(self.frame)")
      
    }
  }
  
}

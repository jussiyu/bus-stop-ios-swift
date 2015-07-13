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
  func horizontalScroller(horizontalScroller: HorizontalScroller, clickedAtIndex: Int)
}

class HorizontalScroller: UIView {
  
  weak var delegate: HorizontalScrollerDelegate?
  
  private var scroller: UIScrollView!
  var viewArray = [UIView]()

  let VIEW_PADDING: CGFloat = 10
  let VIEW_WIDTH: CGFloat = 200
  
  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    initialize()
  }
  
  private func initialize() {
    self.backgroundColor = UIColor.brownColor()
    scroller = UIScrollView()
    self.setTranslatesAutoresizingMaskIntoConstraints(false)
    scroller.setTranslatesAutoresizingMaskIntoConstraints(false)
    scroller.decelerationRate = UIScrollViewDecelerationRateFast
    addSubview(scroller)
    scroller.delegate = self    
    
    self.addConstraint(NSLayoutConstraint(item: scroller, attribute: .Leading, relatedBy: .Equal, toItem: self, attribute: .Leading, multiplier: 1.0, constant: 0.0))
//    self.addConstraint(NSLayoutConstraint(item: scroller, attribute: .Trailing, relatedBy: .Equal, toItem: self, attribute: .Trailing, multiplier: 1.0, constant: 0.0))
    self.addConstraint(NSLayoutConstraint(item: scroller, attribute: .Width, relatedBy: .Equal, toItem: self, attribute: .Width, multiplier: 1.0, constant: 0.0))
    self.addConstraint(NSLayoutConstraint(item: scroller, attribute: .Top, relatedBy: .Equal, toItem: self, attribute: .Top, multiplier: 1.0, constant: 0))
//    self.addConstraint(NSLayoutConstraint(item: scroller, attribute: .Bottom, relatedBy: .Equal, toItem: self, attribute: .Bottom, multiplier: 1.0, constant: 0.0))
    self.addConstraint(NSLayoutConstraint(item: scroller, attribute: .Height, relatedBy: .Equal, toItem: self, attribute: .Height, multiplier: 1.0, constant: 0.0))
  }
  
  func viewAtIndex(index: Int) -> UIView {
    return viewArray[index]
  }
  
  func reload() {
    if let delegate = delegate {
      viewArray = []
      
      let views = scroller.subviews
      for view in views {
        view.removeFromSuperview()
      }
      var VIEW_OFFSET: CGFloat = 0
      var xValue: CGFloat = 0
      
      for index in 0..<delegate.numberOfItemsInHorizontalScroller(self) {
//        xValue += VIEW_PADDING
        let subView = delegate.horizontalScroller(self, viewAtIndexPath: index)
//        subView.frame.origin.x = CGFloat(xValue)
        scroller.addSubview(subView)
        subView.setTranslatesAutoresizingMaskIntoConstraints(false)
        scroller.addConstraint(NSLayoutConstraint(item: subView, attribute: .Top, relatedBy: .Equal, toItem: scroller, attribute: .Top, multiplier: 1.0, constant: VIEW_PADDING))
        if index == 0 {
          scroller.addConstraint(NSLayoutConstraint(item: subView, attribute: .CenterX, relatedBy: .Equal, toItem: scroller, attribute: .CenterX, multiplier: 1.0, constant: 0))
          VIEW_OFFSET = subView.frame.minX
          xValue = VIEW_OFFSET
        } else {
          scroller.addConstraint(NSLayoutConstraint(item: subView, attribute: .Leading, relatedBy: .Equal, toItem: viewArray.last!, attribute: .Trailing, multiplier: 1.0, constant: 0))
        }
        subView.addConstraint(NSLayoutConstraint(item: subView, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: VIEW_WIDTH))
        subView.addConstraint(NSLayoutConstraint(item: subView, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: 129))
        xValue += VIEW_WIDTH + VIEW_PADDING
        viewArray.append(subView)
      }
      
      if viewArray.count > 0 {
        scroller.addConstraint(NSLayoutConstraint(item: viewArray.last!, attribute: .Trailing, relatedBy: .Equal, toItem: scroller, attribute: .Trailing, multiplier: 1.0, constant: VIEW_OFFSET))
        scroller.addConstraint(NSLayoutConstraint(item: viewArray.last!, attribute: .Bottom, relatedBy: .Equal, toItem: scroller, attribute: .Bottom, multiplier: 1.0, constant: 0))
      }
      
      if let initialView = delegate.initialViewIndex?(self) {
        scroller.setContentOffset(CGPoint(x: CGFloat(VIEW_OFFSET), y: 0), animated: true)
//        scroller.setContentOffset(CGPoint(x: CGFloat(initialView)*CGFloat((VIEW_DIMENSIONS + (2 * VIEW_PADDING))), y: 0), animated: true)
      }
      println("Scroller contentsize: \(scroller.contentSize)")
      println("Scroller bounds: \(scroller.bounds)")
      println("Scroller frame: \(scroller.frame)")
//      println("contentview bounds: \(contentView.bounds)")
//      println("contentview frame: \(contentView.frame)")
//      println("contentview origin: \(contentView.frame.origin)")
      println("horiz bounds: \(self.bounds)")
      println("horiz frame: \(self.frame)")
      
    }
  }
}

//             ----- -----
// |xxxXXXXxxx|xxxXXXXxxx|xxxXXXXxxx|
// MARK: - UIScrollViewDelegate
extension HorizontalScroller: UIScrollViewDelegate {
  
  func scrollViewDidEndScrollingAnimation(scrollView: UIScrollView) {
    if let scrollViewPageWidth = viewArray.first?.bounds.width {
      let page = Double((scrollView.contentOffset.x + scrollViewPageWidth / 2) / scrollViewPageWidth)
      let scrollViewPage = page.toInt()
      delegate?.horizontalScroller(self, clickedAtIndex: scrollViewPage)
      //    vehicleTableView.reloadData()
      println("scroll end on page: \(scrollViewPage)")
    }
  }
  
  func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
    if let scrollViewPageWidth = viewArray.first?.bounds.width {
      let page = Double((scrollView.contentOffset.x + scrollViewPageWidth / 2) / scrollViewPageWidth)
      let scrollViewPage = page.toInt()
      //    vehicleTableView.reloadData()
      delegate?.horizontalScroller(self, clickedAtIndex: scrollViewPage)
      println("deaccelarate end on page: \(scrollViewPage)")
    }
  }
  
  // paging for scrollview
  func scrollViewWillEndDragging(scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    
    if let scrollViewPageWidth = viewArray.first?.bounds.width {
      var currentOffset = CGFloat(scrollView.contentOffset.x)
      var targetOffset = CGFloat(targetContentOffset.memory.x)
      var newTargetOffset = CGFloat(0)
      
      // try first with the targetOffset
      newTargetOffset = round((targetOffset) / scrollViewPageWidth) * scrollViewPageWidth
      
      if newTargetOffset < 0 {
        newTargetOffset = 0
      }
      
      if velocity.x != 0 && newTargetOffset != targetOffset {
        // take velocity into account and set targetOffset to the io/out parameter
        if velocity.x > 0 {
          newTargetOffset = ceil((targetOffset - scrollViewPageWidth / 2) / scrollViewPageWidth ) * scrollViewPageWidth
          targetContentOffset.memory.x = newTargetOffset
        } else {
          newTargetOffset = floor((targetOffset + scrollViewPageWidth / 2) / scrollViewPageWidth ) * scrollViewPageWidth
          targetContentOffset.memory.x = newTargetOffset
        }
      } else {
        // no velocity so animate manually
        scrollView.setContentOffset(CGPointMake(CGFloat(newTargetOffset), 0), animated: true)
      }
    }
  }
}

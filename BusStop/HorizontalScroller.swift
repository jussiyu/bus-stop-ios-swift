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
  func horizontalScrollerNoDataView(horizontalScroller: HorizontalScroller) -> UIView
  optional func initialViewIndex(horizontalScroller: HorizontalScroller) -> Int
  func horizontalScroller(horizontalScroller: HorizontalScroller, clickedAtIndex: Int)
}

class HorizontalScroller: UIView {
  
  weak var delegate: HorizontalScrollerDelegate?
  
  private var scroller: UIScrollView!
  var viewArray = [UIView]()

  let subViewWidth: CGFloat = 200
  let subViewHeight: CGFloat = 129
  
  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    initialize()
  }
  
  private func initialize() {
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
  
  var viewCount: Int {
    return viewArray.count
  }
  
  func reloadData() {
    if let delegate = delegate {
      viewArray = []

      // delete old views 
      // TODO: reuse old views
      let views = scroller.subviews
      for view in views {
        view.removeFromSuperview()
      }
      
      // Create all the subviews
      for index in 0..<delegate.numberOfItemsInHorizontalScroller(self) {
        let subView = delegate.horizontalScroller(self, viewAtIndexPath: index)
        subView.setTranslatesAutoresizingMaskIntoConstraints(false)
        scroller.addSubview(subView)
        scroller.addConstraint(NSLayoutConstraint(item: subView, attribute: .Top, relatedBy: .Equal, toItem: scroller, attribute: .Top, multiplier: 1.0, constant: 0))
        if index == 0 {
          scroller.addConstraint(NSLayoutConstraint(item: subView, attribute: .CenterX, relatedBy: .Equal, toItem: scroller, attribute: .CenterX, multiplier: 1.0, constant: 0))
        } else {
          scroller.addConstraint(NSLayoutConstraint(item: subView, attribute: .Leading, relatedBy: .Equal, toItem: viewArray.last!, attribute: .Trailing, multiplier: 1.0, constant: 0))
        }
        subView.addConstraint(NSLayoutConstraint(item: subView, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: subViewWidth))
        subView.addConstraint(NSLayoutConstraint(item: subView, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: subViewHeight))
        viewArray.append(subView)
      }
      
      // Create no-data view if no other subviews
      if delegate.numberOfItemsInHorizontalScroller(self) == 0 {
        let subView = delegate.horizontalScrollerNoDataView(self)
        subView.setTranslatesAutoresizingMaskIntoConstraints(false)
        scroller.addSubview(subView)
        scroller.addConstraint(NSLayoutConstraint(item: subView, attribute: .Top, relatedBy: .Equal, toItem: scroller, attribute: .Top, multiplier: 1.0, constant: 0))
        scroller.addConstraint(NSLayoutConstraint(item: subView, attribute: .CenterX, relatedBy: .Equal, toItem: scroller, attribute: .CenterX, multiplier: 1.0, constant: 0))
        subView.addConstraint(NSLayoutConstraint(item: subView, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: subViewWidth))
        subView.addConstraint(NSLayoutConstraint(item: subView, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: subViewHeight))
        viewArray.append(subView)
      }

      // Force layout so that we can use leading padding for calculating the trailing padding
      setNeedsLayout()
      layoutIfNeeded()

      if viewArray.count > 0 {
        scroller.addConstraint(NSLayoutConstraint(item: viewArray.last!, attribute: .Bottom, relatedBy: .Equal, toItem: scroller, attribute: .Bottom, multiplier: 1.0, constant: 0))
        scroller.addConstraint(NSLayoutConstraint(item: viewArray.last!, attribute: .Trailing, relatedBy: .Equal, toItem: scroller, attribute: .Trailing, multiplier: 1.0, constant: -viewArray.first!.frame.minX))
      }

      if let initialView = delegate.initialViewIndex?(self) {
        scroller.setContentOffset(CGPoint(x: CGFloat(viewArray[initialView].frame.minX), y: 0), animated: true)
      }
      
//      setNeedsLayout()
//      layoutIfNeeded()
//      
//      for i in 0..<viewCount {
//        let subView = viewAtIndex(i)
//        println("scroller subView \(i) bounds: \(subView.bounds)")
//        println("scroller subView \(i) frame: \(subView.frame)")
//      }
//
//      println("Scroller contentsize: \(scroller.contentSize)")
//      println("Scroller bounds: \(scroller.bounds)")
//      println("Scroller frame: \(scroller.frame)")
//      println("horiz bounds: \(self.bounds)")
//      println("horiz frame: \(self.frame)")
      
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
      let scrollViewPage = page.toInt() - 1
      delegate?.horizontalScroller(self, clickedAtIndex: scrollViewPage)
      println("scroll end on page: \(scrollViewPage)")
    }
  }
  
  func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
    if let scrollViewPageWidth = viewArray.first?.bounds.width {
      let page = Double((scrollView.contentOffset.x + scrollViewPageWidth / 2) / scrollViewPageWidth)
      let scrollViewPage = page.toInt() - 1
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

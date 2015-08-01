//
//  HorizontalScroller.swift
//  Pods
//
//  Created by Jussi Yli-Urpo on 13.7.15.
//
//

import UIKit
import XCGLogger

@objc protocol HorizontalScrollerDelegate: class {
  
  // data functions
  func numberOfItemsInHorizontalScroller(horizontalScroller: HorizontalScroller) -> Int
  func horizontalScroller(horizontalScroller: HorizontalScroller, viewAtIndexPath indexPath: Int) -> UIView
  func horizontalScrollerNoDataView(horizontalScroller: HorizontalScroller) -> UIView

  // notifications
  optional func horizontalScroller(horizontalScroller: HorizontalScroller, didScrollToViewAtIndex: Int)
  optional func initialViewIndex(horizontalScroller: HorizontalScroller) -> Int
  optional func horizontalScrollerWillBeginDragging(horizontalScroller: HorizontalScroller)
  optional func horizontalScrollerTapped(horizontalScroller: HorizontalScroller, numberOfTaps: Int)
}

class HorizontalScroller: UIView {
  
  weak var delegate: HorizontalScrollerDelegate?
  
  private var scroller: UIScrollView!
  private var scrollerSubviews = [UIView]()
  private var reusableSubviews = [UIView]()
  
  private var singleTapRecognizer: UITapGestureRecognizer?
  private var multiTapRecognizer: UITapGestureRecognizer?
  
  var viewCount: Int {
    return scrollerSubviews.count
  }

  static let subviewConstraintSidePadding = "subviewConstraintSidePadding"

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
    
    NSLayoutConstraint.activateConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[scroller]|", options: nil, metrics: [:], views: ["scroller":scroller]))
    NSLayoutConstraint.activateConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[scroller]|", options: nil, metrics: [:], views: ["scroller":scroller]))
    
    singleTapRecognizer = UITapGestureRecognizer(target: self, action: "viewTapped:")
    addGestureRecognizer(singleTapRecognizer!)
    multiTapRecognizer = UITapGestureRecognizer(target: self, action: "viewTapped:")
    multiTapRecognizer!.numberOfTapsRequired = 3
    addGestureRecognizer(multiTapRecognizer!)
    singleTapRecognizer?.requireGestureRecognizerToFail(multiTapRecognizer!)
    
    scroller.scrollsToTop = false
  }
  
  deinit {
    singleTapRecognizer?.removeTarget(nil, action: nil)
  }
  
  func viewAtIndex(index: Int) -> UIView? {
    if index < scrollerSubviews.count {
      return scrollerSubviews[index]
    } else {
      return nil
    }
  }
  
  func scrollToViewWithIndex(index: Int, animated: Bool = true ) {
    if scrollerSubviews.count > index {
      // center the header with index to the scroller
      let scrollViewWidth = bounds.width
      let currentViewCenter = scrollerSubviews[index].frame.midX
      let newOffset = currentViewCenter - scrollViewWidth / 2
      log.debug("Scrolling to view with index \(index); from offset \(self.scroller.contentOffset) to \(newOffset)")
      scroller.setContentOffset(CGPoint(x: CGFloat(newOffset), y: 0), animated: animated)
    }
  }
  
  func dequeueReusableView() -> UIView? {
    if reusableSubviews.count > 0 {
      return reusableSubviews.removeAtIndex(reusableSubviews.count - 1)
    } else {
      return nil
    }
  }
  
  func reloadData() {
    if let delegate = delegate {

      // move old views to reuse list 
      while scrollerSubviews.count > 0 {
        let view = scrollerSubviews.removeAtIndex(scrollerSubviews.count - 1)
        reusableSubviews.append(view)
        view.removeFromSuperview()
      }
      
      // Create all the subviews
      for index in 0..<delegate.numberOfItemsInHorizontalScroller(self) {
        let subview = delegate.horizontalScroller(self, viewAtIndexPath: index)
        subview.setTranslatesAutoresizingMaskIntoConstraints(false)
        scroller.addSubview(subview)
        scroller.addConstraint(NSLayoutConstraint(item: subview, attribute: .Top, relatedBy: .Equal, toItem: scroller, attribute: .Top, multiplier: 1.0, constant: 0))
        if index == 0 {
          scroller.addConstraint(NSLayoutConstraint(item: subview, attribute: .CenterX, relatedBy: .Equal, toItem: scroller, attribute: .CenterX, multiplier: 1.0, constant: 0))
        } else {
          let left = NSLayoutConstraint(item: subview, attribute: .Leading, relatedBy: .Equal, toItem: scrollerSubviews.last!, attribute: .Trailing, multiplier: 1.0, constant: 0)
          left.identifier = HorizontalScroller.subviewConstraintSidePadding
          scroller.addConstraint(left)
        }
        scrollerSubviews.append(subview)
      }
      
      // Create no-data view if no other subviews
      if delegate.numberOfItemsInHorizontalScroller(self) == 0 {
        let subview = delegate.horizontalScrollerNoDataView(self)
        subview.setTranslatesAutoresizingMaskIntoConstraints(false)
        scroller.addSubview(subview)
        scroller.addConstraint(NSLayoutConstraint(item: subview, attribute: .Top, relatedBy: .Equal, toItem: scroller, attribute: .Top, multiplier: 1.0, constant: 0))
        scroller.addConstraint(NSLayoutConstraint(item: subview, attribute: .CenterX, relatedBy: .Equal, toItem: scroller, attribute: .CenterX, multiplier: 1.0, constant: 0))
        scrollerSubviews.append(subview)
      }

      // Force layout so that we can use leading padding for calculating the trailing padding
      setNeedsLayout()
      layoutIfNeeded()

      if scrollerSubviews.count > 0 {
        scroller.addConstraint(NSLayoutConstraint(item: scrollerSubviews.last!, attribute: .Bottom, relatedBy: .Equal, toItem: scroller, attribute: .Bottom, multiplier: 1.0, constant: 0))
        scroller.addConstraint(NSLayoutConstraint(item: scrollerSubviews.last!, attribute: .Trailing, relatedBy: .Equal, toItem: scroller, attribute: .Trailing, multiplier: 1.0, constant: -scrollerSubviews.first!.frame.minX))
      }

      if let initialViewIndex = delegate.initialViewIndex?(self) {
        scrollToViewWithIndex(initialViewIndex)
      }
      
      // force intrisic size calculation now that all subviews have been created
      invalidateIntrinsicContentSize()
      
//      setNeedsLayout()
//      layoutIfNeeded()
//      
//      for i in 0..<viewCount {
//        let subView = viewAtIndex(i)
//        log.verbose("scroller subView \(i) bounds: \(subView.bounds)")
//        log.verbose("scroller subView \(i) frame: \(subView.frame)")
//      }
//
//      log.verbose("Scroller contentsize: \(scroller.contentSize)")
//      log.verbose("Scroller bounds: \(scroller.bounds)")
//      log.verbose("Scroller frame: \(scroller.frame)")
//      log.verbose("horiz bounds: \(self.bounds)")
//      log.verbose("horiz frame: \(self.frame)")
      
    }
  }
  
  override func intrinsicContentSize() -> CGSize {
    // Calculate height based on the first subview bounds
    log.verbose("viewArray.first?.bounds.height: \(self.scrollerSubviews.first?.bounds.height)")
    return CGSize(width: UIViewNoIntrinsicMetric, height: scrollerSubviews.first?.bounds.height ?? UIViewNoIntrinsicMetric)
  }
  
}

//             ----- -----
// |xxxXXXXxxx|xxxXXXXxxx|xxxXXXXxxx|
// MARK: - UIScrollViewDelegate
extension HorizontalScroller: UIScrollViewDelegate {

  private func scrollViewDidSomehowEndScrolling(scrollView: UIScrollView) {
    // Calculate the currently centered subview and notify the delegate
    if let scrollViewPageWidth = scrollerSubviews.first?.bounds.width {
      let page = Double((scrollView.contentOffset.x + scrollViewPageWidth / 2) / scrollViewPageWidth)
      let scrollViewPage = max(page.toInt() - 1, 0)
      delegate?.horizontalScroller?(self, didScrollToViewAtIndex: scrollViewPage)
    }

  }
  func scrollViewDidEndScrollingAnimation(scrollView: UIScrollView) {
    scrollViewDidSomehowEndScrolling(scrollView)
  }
  
  func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
    scrollViewDidSomehowEndScrolling(scrollView)
  }
  
  // paging for scrollview
  func scrollViewWillEndDragging(scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    
    if let scrollViewPageWidth = scrollerSubviews.first?.bounds.width {
      var currentOffset = CGFloat(scrollView.contentOffset.x)
      var targetOffset = CGFloat(targetContentOffset.memory.x)
      
      // try first with the (positive!) targetOffset
      var newTargetOffset = max(0, round(targetOffset / scrollViewPageWidth) * scrollViewPageWidth)
      
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
      
      log.debug("scrolling to offset \(newTargetOffset)")
    }
  }
  
  func scrollViewWillBeginDragging(scrollView: UIScrollView) {
    delegate?.horizontalScrollerWillBeginDragging?(self)
  }
  
}

// MARK: - selector handler
extension HorizontalScroller {
  @objc func viewTapped(sender: UITapGestureRecognizer){
    log.verbose("viewtapped \(sender.numberOfTapsRequired) time(s)")
    if sender.state == .Ended {
      delegate?.horizontalScrollerTapped?(self, numberOfTaps: sender.numberOfTapsRequired)
    }
  }
}
// handling code


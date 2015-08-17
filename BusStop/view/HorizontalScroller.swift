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

import UIKit
import XCGLogger

@objc protocol HorizontalScrollerDelegate: class {
  
  // data functions
  func numberOfItemsInHorizontalScroller(horizontalScroller: HorizontalScroller) -> Int
  func horizontalScroller(horizontalScroller: HorizontalScroller, existingViewAtIndexPath indexPath: Int) -> UIView?
  func horizontalScroller(horizontalScroller: HorizontalScroller, viewAtIndexPath indexPath: Int) -> UIView
  func horizontalScrollerNoDataView(horizontalScroller: HorizontalScroller) -> UIView

  // notifications
  optional func horizontalScroller(horizontalScroller: HorizontalScroller, didScrollToViewAtIndex: Int)
  optional func initialViewIndex(horizontalScroller: HorizontalScroller) -> Int
  optional func horizontalScrollerWillBeginDragging(horizontalScroller: HorizontalScroller)
  optional func horizontalScrollerTapped(horizontalScroller: HorizontalScroller, numberOfTaps: Int)
}

protocol FadeableUIView {
  func fadeOutByOffset(offset: CGFloat)
}

class HorizontalScroller: UIView {
  
  weak var delegate: HorizontalScrollerDelegate?
  
  private var scroller: UIScrollView!
  private var scrollerSubviews = [Int:UIView]()
  private var reusableSubviews = [Int:UIView]()
  
  private var singleTapRecognizer: UITapGestureRecognizer?
  private var multiTapRecognizer: UITapGestureRecognizer?
  
  private let noncurrentViewAlpha: CGFloat = 0.5
  
  var currentViewIndex: Int? {
    if let scrollViewPageWidth = scrollerSubviews[0]?.bounds.width where scrollViewPageWidth > 0 {
      let page = Double(scroller.contentOffset.x / scrollViewPageWidth)
      return max(page.toInt(), 0)
    } else { // no subviews
      return nil
    }
  }
  
  var touchEnabled: Bool {
    get {return scroller.scrollEnabled}
    set {
      scroller.scrollEnabled = newValue
      singleTapRecognizer?.enabled = newValue
      multiTapRecognizer?.enabled = newValue
    }
  }
  var viewCount: Int {
    return scrollerSubviews.count
  }

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
  
  /// Return true if we actually scrolled somewhere
  func shouldScrollToViewWithIndex(index: Int, animated: Bool = true ) -> Bool {
    if index > scrollerSubviews.count {
      return false
    }
    
    // center the header with index to the scroller
    let scrollViewWidth = bounds.width
    if let currentViewCenter = scrollerSubviews[index]?.frame.midX {
      let newOffset = currentViewCenter - scrollViewWidth / 2

      // Do we need to scroll anywhere?
      if newOffset != scroller.contentOffset.y {
        log.debug("Scrolling to view with index \(index); from offset \(self.scroller.contentOffset) to \(newOffset)")
        scroller.setContentOffset(CGPoint(x: CGFloat(newOffset), y: 0), animated: animated)
        return true

      } else {
        return false
      }
      
    } else {
      return false
    }
  }

  func dequeueReusableView(index: Int) -> UIView? {
    if reusableSubviews.count > 0 {
      let view = reusableSubviews[index]
      reusableSubviews[index] = nil
      return view
    } else {
      return nil
    }
  }
  
  func reloadData() {
    UIView.animateWithDuration(0.2, delay: 0, options: UIViewAnimationOptions.CurveEaseIn, animations: {self.alpha = 0}, completion: {_ in
      self.doReloadData()
      UIView.animateWithDuration(0.2, delay: 0, options: UIViewAnimationOptions.CurveEaseOut, animations: {self.alpha = 1}, completion: {_ in 0})
    })
  }
  
  private func doReloadData() {
    if let delegate = delegate {
     
      let subViewCount = delegate.numberOfItemsInHorizontalScroller(self)

      // move old views to reuse list
      for (index, view) in enumerate(scrollerSubviews) {
        if index < subViewCount {
          // recycle view
          reusableSubviews[index] = scrollerSubviews[index]
        } else {
          // remove an extra views
          scrollerSubviews[index]?.removeFromSuperview()
        }
        scrollerSubviews[index] = nil
      }
      
      // Create all the subviews
      for index in 0..<subViewCount {
        if let subview = delegate.horizontalScroller(self, existingViewAtIndexPath: index) {
          // An existing view on the same location so lets use it
          scrollerSubviews[index] = subview
          
        } else {
          // A new view view needs to be created with new constraints
          let subview = delegate.horizontalScroller(self, viewAtIndexPath: index)
          subview.setTranslatesAutoresizingMaskIntoConstraints(false)
          scroller.addSubview(subview)
          scroller.addConstraint(NSLayoutConstraint(item: subview, attribute: .Top, relatedBy: .Equal, toItem: scroller, attribute: .Top, multiplier: 1.0, constant: 0))
          if index == 0 {
            scroller.addConstraint(NSLayoutConstraint(item: subview, attribute: .CenterX, relatedBy: .Equal, toItem: scroller, attribute: .CenterX, multiplier: 1.0, constant: 0))
          } else {
            let left = NSLayoutConstraint(item: subview, attribute: .Leading, relatedBy: .Equal, toItem: scrollerSubviews[index - 1]!, attribute: .Trailing, multiplier: 1.0, constant: 0)
            scroller.addConstraint(left)
          }
          scrollerSubviews[index] = subview
        }
      }
      
      // Create no-data view if no other subviews
      if delegate.numberOfItemsInHorizontalScroller(self) == 0 {
        let subview = delegate.horizontalScrollerNoDataView(self)
        subview.setTranslatesAutoresizingMaskIntoConstraints(false)
        scroller.addSubview(subview)
        scroller.addConstraint(NSLayoutConstraint(item: subview, attribute: .Top, relatedBy: .Equal, toItem: scroller, attribute: .Top, multiplier: 1.0, constant: 0))
        scroller.addConstraint(NSLayoutConstraint(item: subview, attribute: .CenterX, relatedBy: .Equal, toItem: scroller, attribute: .CenterX, multiplier: 1.0, constant: 0))
        scrollerSubviews[0] = subview
      }

      // Force layout so that we can use leading padding for calculating the trailing padding
      shrinkViewByOffset(0)
      setNeedsLayout()
      layoutIfNeeded()
      updateViewFade()

      // set the bottom and trailing constraints from the last subview to the super view - first remove old ones
      let lastViewConstraintId = "last-view-to-superview"
      scroller.removeConstraints(constraintsWithIdentifier(lastViewConstraintId))
      if let lastSubview = scrollerSubviews[subViewCount - 1] where scrollerSubviews.count > 0 {
        let bottom = NSLayoutConstraint(item: lastSubview, attribute: .Bottom, relatedBy: .Equal, toItem: scroller, attribute: .Bottom, multiplier: 1.0, constant: 0)
        bottom.identifier = lastViewConstraintId
        scroller.addConstraint(bottom)
        let trailing = NSLayoutConstraint(item: lastSubview, attribute: .Trailing, relatedBy: .Equal, toItem: scroller, attribute: .Trailing, multiplier: 1.0, constant: -scrollerSubviews[0]!.frame.minX)
        trailing.identifier = lastViewConstraintId
        scroller.addConstraint(trailing)
      }

      if let initialViewIndex = delegate.initialViewIndex?(self) {
        shouldScrollToViewWithIndex(initialViewIndex)
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
    log.verbose("viewArray.first?.bounds.height: \(self.scrollerSubviews[0]?.bounds.height)")
    return CGSize(width: UIViewNoIntrinsicMetric, height: scrollerSubviews[0]?.bounds.height ?? UIViewNoIntrinsicMetric)
  }
  
  
  func shrinkViewByOffset(offset: CGFloat) {
    
    if let currentViewIndex = currentViewIndex, currentView = viewAtIndex(currentViewIndex) as? FadeableUIView {
        // shink and hide not needed info
        currentView.fadeOutByOffset(offset)
        
        // Move adjacent headers to side and him them
        for viewIndex in 0..<scrollerSubviews.count {
          if let view = viewAtIndex(viewIndex) {
            if viewIndex != currentViewIndex {
              view.alpha = noncurrentViewAlpha - offset / 10
              view.transform = CGAffineTransformMakeTranslation(viewIndex > currentViewIndex ? offset : -offset, 0)
            } else {
              view.alpha = 1
              view.transform = CGAffineTransformIdentity
            }
          }
        }
    }
  }

  private func updateViewFade() {
    if let currentViewIndex = currentViewIndex {
      for index in 0 ..< scrollerSubviews.count {
        if index == currentViewIndex {
          UIView.animateWithDuration(0.2) {scrollerSubviews[index]?.alpha = 1}
        } else {
          UIView.animateWithDuration(0.2) {scrollerSubviews[index]?.alpha = self.noncurrentViewAlpha}
        }
      }
    }
  }
}

//             ----- -----
// |xxxXXXXxxx|xxxXXXXxxx|xxxXXXXxxx|
// MARK: - UIScrollViewDelegate
extension HorizontalScroller: UIScrollViewDelegate {

  private func scrollViewDidSomehowEndScrolling(scrollView: UIScrollView) {
    updateViewFade()
    if let currentViewIndex = currentViewIndex {
      delegate?.horizontalScroller?(self, didScrollToViewAtIndex: currentViewIndex)
    }
  }

  func scrollViewDidEndScrollingAnimation(scrollView: UIScrollView) {
    if !scrollView.decelerating {
      scrollViewDidSomehowEndScrolling(scrollView)
    }
  }
  
  func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
    scrollViewDidSomehowEndScrolling(scrollView)
  }
  
  // paging for scrollview
  func scrollViewWillEndDragging(scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    
    if let scrollViewPageWidth = scrollerSubviews[0]?.bounds.width where scrollViewPageWidth > 0 {
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
  
  func scrollViewDidScroll(scrollView: UIScrollView) {
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


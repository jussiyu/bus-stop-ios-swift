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

//
// MARK: - SelectedStopTableViewCellDelegate protocol
//
protocol SelectedStopTableViewCellDelegate {
  func shouldSetFavorite(favorite: Bool) -> Bool
  func close()
}

//
// MARK: - UITableViewCell implementation
//
class SelectedStopTableViewCell: UITableViewCell {
  
  var delegate: SelectedStopTableViewCellDelegate?

  @IBOutlet weak var stopNameLabel: UILabel!
  @IBOutlet weak var stopCountLabel: UILabel!
  @IBOutlet weak var distanceHintLabel: UILabel!
  @IBOutlet weak var closeButton: UIButton!
  @IBOutlet weak var delayLabel: UILabel!
  @IBOutlet weak var favoriteButton: UIButton!
  
  override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

  @IBAction func favoriteButtonTapped(sender: AnyObject) {
    if let button = sender as? UIButton {
      if let delegate = delegate where delegate.shouldSetFavorite(button.selected) {
        button.selected = !button.selected
      }
      
    }
  }
  @IBAction func closeButtonTapped(sender: UIButton) {
    delegate?.close()
  }
}

//
//  ViewController.swift
//  point2
//
//  Created by Mikey Lintz on 10/21/17.
//  Copyright © 2017 Mikey Lintz. All rights reserved.
//

import UIKit
import SwiftyDropbox
import Projection

private let path = "/!point2.txt"

final class ViewController: UIViewController {
  private static let defaultPrefix = "- "

  private var inputTextView: UITextView!
  private var statusLabel: UILabel!
  private var submitButton: UIButton!
  private var keyboardHeight = CGFloat(0)
  fileprivate var contentTextView: UITextView!
  var store: Store? {
    willSet {
      guard store == nil else {
        preconditionFailure("Store can only be set once")
      }
    }
    didSet {
      store!.delegate = self
      store!.downloadLatestContentIfIdle()
      updateStatusLabel()
    }
  }

  static var shared: ViewController?

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    guard ViewController.shared == nil else {
      fatalError("ViewController already exists")
    }
    ViewController.shared = self
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    inputTextView = UITextView()
    inputTextView.backgroundColor = .black
    inputTextView.font = UIFont.systemFont(ofSize: 18)
    inputTextView.textColor = .gray
    inputTextView.text = ViewController.defaultPrefix
    view.addSubview(inputTextView)

    statusLabel = UILabel()
    statusLabel.text = "Store not initialized"
    statusLabel.backgroundColor = .red
    statusLabel.textColor = .white
    view.addSubview(statusLabel)

    submitButton = UIButton(type: .roundedRect)
    submitButton.setTitle("Submit", for: .normal)
    submitButton.setTitleColor(.lightGray, for: .normal)
    submitButton.setBackgroundColor(color: .gray, for: .normal)
    submitButton.addTarget(self, action: #selector(handleSubmit), for: .touchUpInside)
    view.addSubview(submitButton)

    contentTextView = UITextView()
    contentTextView.text = ""
    contentTextView.isEditable = false
    contentTextView.backgroundColor = .lightGray
    contentTextView.font = inputTextView.font
    contentTextView.textColor = .white
    view.addSubview(contentTextView)

    NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(_:)), name: .UIKeyboardWillShow, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidHide(_:)), name: .UIKeyboardWillHide, object: nil)
  }

  @objc private func keyboardDidShow(_ notification: NSNotification) {
    let userInfo = notification.userInfo!
    let keyboardRect = userInfo[UIKeyboardFrameEndUserInfoKey]! as! CGRect
    let duration = userInfo[UIKeyboardAnimationDurationUserInfoKey]! as! TimeInterval
    keyboardHeight = keyboardRect.height
    view.setNeedsLayout()
    UIView.animate(withDuration: duration) {
      self.view.layoutIfNeeded()
      let offsetY = self.contentTextView.contentSize.height - self.contentTextView.bounds.height
      self.contentTextView.setContentOffset(CGPoint(x: 0, y: max(0, offsetY)), animated: true)
    }
  }

  @objc private func keyboardDidHide(_ notification: NSNotification) {
    let userInfo = notification.userInfo!
    let duration = userInfo[UIKeyboardAnimationDurationUserInfoKey]! as! TimeInterval
    keyboardHeight = 0
    view.setNeedsLayout()
    UIView.animate(withDuration: duration) {
      self.view.layoutIfNeeded()
      let offsetY = self.contentTextView.contentSize.height - self.contentTextView.bounds.height
      self.contentTextView.setContentOffset(CGPoint(x: 0, y: max(0, offsetY)), animated: true)
    }
  }

  @objc private func handleSubmit(_ notification: NSNotification) {
    guard let content = inputTextView.text, !content.isEmpty else {
      return
    }
    inputTextView.text = ViewController.defaultPrefix
    store!.appendItem(item: content)
  }

  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    view.prj_applyProjection { m, bounds in
      m[contentTextView]
        .left(bounds.left)
        .right(bounds.right)
        .height((bounds.bottom - keyboardHeight) / 2)
        .bottom(bounds.bottom - keyboardHeight)

      m[submitButton]
        .bottomLeft(m[contentTextView].topLeft)
        .height(60)
        .width(bounds.width)

      m[statusLabel]
        .bottomLeft(m[submitButton].topLeft)
        .height(statusLabel.font.lineHeight)
        .width(bounds.width)

      m[inputTextView]
        .top(view.safeAreaLayoutGuide.layoutFrame.minY)
        .bottomLeft(m[statusLabel].topLeft)
        .width(bounds.width)
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    inputTextView.becomeFirstResponder()

    guard let client = DropboxClientsManager.authorizedClient else {
      DropboxClientsManager.authorizeFromController(UIApplication.shared, controller: self) { url in
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
      }
      return
    }
    store = Store(filesClient: client.files)
  }

  fileprivate func updateStatusLabel() {
    var statusLabelText: String
    switch store!.syncState {
    case .idle:
      statusLabelText = "Idle"
    case .downloading(newItemsIdle: let idle):
      statusLabelText = "Downloading with \(idle.count) idle items"
    case .uploading(newItemsUploading: let uploading, newItemsIdle: let idle):
      statusLabelText = "Uploading \(uploading.count) items with \(idle.count) idle items"
    }
    statusLabel.text = statusLabelText
  }
}

extension ViewController: StoreDelegate {
  func syncStateDidChange(state: SyncState) {
      updateStatusLabel()
  }

  func contentDidChange(content: String) {
    if content != contentTextView.text {
      contentTextView.text = content
      let offsetY = contentTextView.contentSize.height - contentTextView.bounds.height
      contentTextView.setContentOffset(CGPoint(x: 0, y: max(0, offsetY)), animated: true)
    }
  }
}

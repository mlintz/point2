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

  private var inputTextField: UITextField!
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

  override var prefersStatusBarHidden: Bool {
    return true
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black

    inputTextField = UITextField()
    inputTextField.backgroundColor = .black
    inputTextField.font = UIFont.systemFont(ofSize: 24)
    inputTextField.textColor = .gray
    inputTextField.text = ViewController.defaultPrefix
    inputTextField.delegate = self
    inputTextField.autocorrectionType = .no
    view.addSubview(inputTextField)

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
    contentTextView.backgroundColor = .black
    contentTextView.font = inputTextField.font
    contentTextView.textColor = .gray
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

  @objc private func handleSubmit() {
    guard let content = inputTextField.text, !content.isEmpty else {
      return
    }
    inputTextField.text = ViewController.defaultPrefix
    store!.appendItem(item: content)
  }

  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    view.prj_applyProjection { m, bounds in
      m[statusLabel]
        .top(view.safeAreaLayoutGuide.layoutFrame.minY)
        .left(bounds.left)
        .height(statusLabel.font.lineHeight)
        .width(bounds.width)

      m[inputTextField]
        .bottom(bounds.bottom - keyboardHeight)
        .left(bounds.left)
        .width(bounds.width)
        .height(inputTextField.font!.lineHeight + 20)

      m[contentTextView]
        .topLeft(m[statusLabel].bottomLeft)
        .bottomRight(m[inputTextField].topRight)

//      m[submitButton]
//        .topLeft(m[statusLabel].bottomLeft)
//        .height(60)
//        .width(bounds.width)

    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    inputTextField.becomeFirstResponder()

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
    var statusLabelColor: UIColor
    switch store!.syncState {
    case .idle:
      statusLabelText = "Idle"
      statusLabelColor = .black
    case .downloading(newItemsIdle: let idle):
      statusLabelText = "Downloading with \(idle.count) idle items"
      if idle.isEmpty {
        statusLabelColor = .black
      } else {
        statusLabelColor = .red
      }
    case .uploading(newItemsUploading: let uploading, newItemsIdle: let idle):
      statusLabelText = "Uploading \(uploading.count) items with \(idle.count) idle items"
      statusLabelColor = .red
    }
    statusLabel.text = statusLabelText
    statusLabel.backgroundColor = statusLabelColor
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

extension ViewController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    handleSubmit()
    return true
  }

  func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
    return false
  }
}

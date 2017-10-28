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
  private var inputTextView: UITextView!
  private var statusLabel: UILabel!
  private var submitButton: UIButton!
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
    contentTextView.isEditable = false
    contentTextView.backgroundColor = .lightGray
    contentTextView.font = inputTextView.font
    contentTextView.textColor = .white
    view.addSubview(contentTextView)
  }

  @objc private func handleSubmit() {
    guard let content = inputTextView.text, !content.isEmpty else {
      return
    }
    inputTextView.text = ""
    store!.appendItem(item: content)
  }

  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    view.prj_applyProjection { m, bounds in
      m[inputTextView]
        .top(view.safeAreaLayoutGuide.layoutFrame.minY)
        .width(bounds.width)
        .left(0)
        .bottom(bounds.height/2 - 80)

      m[statusLabel]
        .topLeft(m[inputTextView].bottomLeft)
        .height(statusLabel.font.lineHeight)
        .width(bounds.width)

      m[submitButton]
        .topLeft(m[statusLabel].bottomLeft)
        .bottom(bounds.height/2)
        .width(bounds.width)

      m[contentTextView]
        .topLeft(m[submitButton].bottomLeft)
        .bottomRight(bounds.bottomRight)
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

//    let request = client.files.download(path: path)
//    request.response { response, error in
//      guard let file = response?.1, let metadata = response?.0 else {
//        fatalError("\(error!)")
//      }
//
//      let rev = metadata.rev
//      let uploadData = "doodlydoo".data(using: .utf8)!
//      let uploadRequest = client.files.upload(path: path, mode: .update(rev), autorename: true, clientModified: nil, mute: false, input: uploadData)
//      uploadRequest.response { response, error in
//        print(response)
//        print(error)
//      }

//      if let response = response {
//        let string = String(data: response.1, encoding: .utf8)
//        print(string!)
//      } else if let error = error {
//        print(error)
//      }
//    }
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
    contentTextView.text = content
  }
}

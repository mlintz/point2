//
//  Store.swift
//  point2
//
//  Created by Mikey Lintz on 10/21/17.
//  Copyright © 2017 Mikey Lintz. All rights reserved.
//

// XXX(mikey): write integration tests

import Foundation
import SwiftyDropbox

struct ServerState {
  var data: Data
  var revision: String?
}

enum SyncState {
  case uploading(newItemsUploading: [String], newItemsIdle: [String])
  case downloading(newItemsIdle: [String])
  case idle

  fileprivate func contentWithServerData(data: Data) -> String {
    // XXX(mikey): include integration test with server data having trailing newline
    var str = String(data: data, encoding: .utf8)!
    if let range = str.rangeOfCharacter(from: .whitespacesAndNewlines, options: [.anchored, .backwards]) {
      str.removeSubrange(range)
    }
    switch self {
    case .uploading(newItemsUploading: let uploading, newItemsIdle: let idle):
      return ([str] + uploading + idle).joined(separator: "\n")
    case .downloading(newItemsIdle: let newItemsIdle):
      return ([str] + newItemsIdle).joined(separator: "\n")
    case .idle:
      return str
    }
  }
}

protocol StoreDelegate: class {
  func syncStateDidChange(state: SyncState)
  func contentDidChange(content: String)
}

final class Store {
  private static let path = "/!point2.txt"

  private var serverState: ServerState
  private(set) var syncState: SyncState = .idle {
    didSet {
      delegate!.syncStateDidChange(state: syncState)
    }
  }
  private let filesClient: FilesRoutes

  weak var delegate: StoreDelegate?

  init(filesClient: FilesRoutes) {
    self.filesClient = filesClient
    serverState = ServerState(data: Data(), revision: nil)
    getLatestCursorThenLongPoll(cursor: nil)
  }

  private func getLatestCursorThenLongPoll(cursor: String?) {
    let completionHandler = { (result: Files.ListFolderResult?, err: Any?) in
      guard err == nil else {
        self.getLatestCursorThenLongPoll(cursor: result?.cursor)
        return
      }
      guard let response = result else {
        preconditionFailure()
      }
      for metadata in response.entries {
        if let pathLower = metadata.pathLower, pathLower == Store.path {
          self.downloadLatestContentIfIdle()
        }
      }
      guard !response.hasMore else {
        self.getLatestCursorThenLongPoll(cursor: response.cursor)
        return
      }
      self.longPoll(cursor: response.cursor)
    }

    if let cursor = cursor {
      filesClient.listFolderContinue(cursor: cursor).response(completionHandler: completionHandler)
    } else {
      filesClient.listFolder(path: "").response(completionHandler: completionHandler)
    }
  }

  private func longPoll(cursor: String) {
    filesClient.listFolderLongpoll(cursor: cursor).response { result, err in
      guard err == nil else {
        self.longPoll(cursor: cursor)
        return
      }
      self.getLatestCursorThenLongPoll(cursor: cursor)
    }
  }

  func downloadLatestContentIfIdle() {
    guard case SyncState.idle = syncState else {
      return
    }
    syncState = .downloading(newItemsIdle: [])
    downloadLatestContent()
  }

  private func downloadLatestContent() {
    guard case .downloading = syncState else {
      preconditionFailure("Expected sync state: .downloading. Received: \(syncState)")
    }
    filesClient.download(path: Store.path).response { response, err in
      guard case .downloading(newItemsIdle: let idle) = self.syncState else {
        preconditionFailure("Expected sync state: .downloading. Received: \(self.syncState)")
      }
      guard let response = response else {
        guard let err = err else {
          fatalError("unreachable")
        }
        print("Retrying download due to error: \(err)")
        self.downloadLatestContentIfIdle()
        return
      }

      guard response.0.pathLower! == Store.path else {
        fatalError("path doesn't match. expected \(Store.path), received \(response.0.pathLower!)")
      }

      self.serverState = ServerState(data: response.1, revision: response.0.rev)
      self.delegate!.contentDidChange(content: self.syncState.contentWithServerData(data: self.serverState.data))
      guard idle.isEmpty else {
        self.syncState = .uploading(newItemsUploading: idle, newItemsIdle: [])
        self.uploadSyncState()
        return
      }
      self.syncState = .idle
    }
  }

  func appendItem(item: String) {
    var item = item
    if let range = item.rangeOfCharacter(from: .whitespacesAndNewlines, options: [.anchored, .backwards]) {
      item.removeSubrange(range)
    }

    switch syncState {
    case .idle:
      syncState = .uploading(newItemsUploading: [item], newItemsIdle: [])
      uploadSyncState()
    case .downloading(newItemsIdle: var idle):
      idle.append(item)
      syncState = .downloading(newItemsIdle: idle)
    case .uploading(newItemsUploading: let uploading, newItemsIdle: var idle):
      idle.append(item)
      syncState = .uploading(newItemsUploading: uploading, newItemsIdle: idle)
    }
    delegate!.contentDidChange(content: syncState.contentWithServerData(data: serverState.data))
  }

  private func uploadSyncState() {
    guard case .uploading = syncState else {
      preconditionFailure("Expected sync state: .uploading. Received: \(syncState)")
    }

    let input = syncState.contentWithServerData(data: serverState.data).data(using: .utf8)!

    filesClient.upload(
      path: Store.path,
      mode: .update(self.serverState.revision!),
      autorename: true,
      clientModified: nil,
      mute: false,
      input: input
    ).response { response, err in
      guard case .uploading(newItemsUploading: let uploading, newItemsIdle: let idle) = self.syncState else {
        preconditionFailure("Expected sync state: .uploading. Received: \(self.syncState)")
      }
      guard let response = response else {
        guard let err = err else {
          fatalError("unreachable")
        }
        print("Retrying upload due to error: \(err)")
        self.uploadSyncState()
        return
      }
      guard response.pathLower! == Store.path else {
        print("Retrying upload file conflict")
        self.syncState = .downloading(newItemsIdle: uploading + idle)
        self.downloadLatestContent()
        return
      }

      self.serverState = ServerState(data: input, revision: response.rev)
      guard idle.isEmpty else {
        self.syncState = .uploading(newItemsUploading: idle, newItemsIdle: [])
        self.uploadSyncState()
        return
      }
      self.syncState = .idle
    }
  }
}

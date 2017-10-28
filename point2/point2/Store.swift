//
//  Store.swift
//  point2
//
//  Created by Mikey Lintz on 10/21/17.
//  Copyright © 2017 Mikey Lintz. All rights reserved.
//

import Foundation
import SwiftyDropbox

struct ServerState {
  var data: Data
  var revision: String
}

enum SyncState {
  case uploading(newItemsUploading: [String], newItemsIdle: [String])
  case downloading(newItemsIdle: [String])
  case idle

  fileprivate func contentWithServerData(data: Data) -> String {
    let str = String(data: data, encoding: .utf8)!
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

  private var serverState: ServerState?
  private(set) var syncState: SyncState = .idle {
    didSet {
      delegate!.syncStateDidChange(state: syncState)
    }
  }
  private let filesClient: FilesRoutes

  weak var delegate: StoreDelegate?

  init(filesClient: FilesRoutes) {
    self.filesClient = filesClient
  }

  func downloadLatestContentIfIdle() {
    guard case SyncState.idle = syncState else {
      return
    }

    syncState = .downloading(newItemsIdle: [])
    filesClient.download(path: Store.path).response { response, err in
      switch self.syncState {
      case .downloading:
        break
        // Okay
      default:
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
      self.syncState = .idle
      self.delegate!.contentDidChange(content: self.syncState.contentWithServerData(data: self.serverState!.data))
    }
  }
}

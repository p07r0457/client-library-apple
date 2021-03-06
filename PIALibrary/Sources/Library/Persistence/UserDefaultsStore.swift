//
//  UserDefaultsStore.swift
//  PIALibrary
//
//  Created by Davide De Rosa on 10/2/17.
//  Copyright © 2017 London Trust Media. All rights reserved.
//

import Foundation
import Gloss
import SwiftyBeaver

private let log = SwiftyBeaver.self

class UserDefaultsStore: PlainStore, ConfigurationAccess {
    private struct Entries {
        static let username = "LoggedUsername" // legacy
        
        static let accountInfo = "LoggedAccountInfo" // legacy

        static let lastSignupEmail = "LastSignupEmail"

        static let cachedServers = "CachedServers"

        static let serversConfiguration = "ServersConfiguration"
        
        static let preferredServer = "CurrentRegion" // legacy

        static let pingByServerIdentifier = "PingByServerIdentifier"
        
        static let vpnType = "VPNType"
        
        static let vpnDisconnectsOnSleep = "VPNDisconnectsOnSleep"
        
        static let vpnCustomConfigurationMaps = "VPNCustomConfigurationMaps"

        static let persistentConnection = "PersistentConnection" // legacy

        static let mace = "MACE" // legacy
    }
    
    private let backend: UserDefaults
    
    private let group: String?
    
    private var cachedServersCopy: [Server]?
    
    private var serversConfigurationCopy: ServersBundle.Configuration?
    
    private var pingByServerIdentifier: [String: Int] = [:]
    
    init() {
        backend = UserDefaults.standard
        group = Bundle.main.bundleIdentifier
        loadComplexMaps()
    }

    init(group: String) {
        guard let backend = UserDefaults(suiteName: group) else {
            fatalError("Unable to create UserDefaults in app group '\(group)')")
        }
        self.backend = backend
        self.group = group
        loadComplexMaps()
    }
    
    private func loadComplexMaps() {
        pingByServerIdentifier = backend.dictionary(forKey: Entries.pingByServerIdentifier) as? [String: Int] ?? [:]
    }
    
    deinit {
        backend.synchronize()
    }
    
    // MARK: PlainStore
    
    // MARK: Account

    var publicUsername: String? {
        get {
            return backend.string(forKey: Entries.username)
        }
        set {
            if let username = newValue {
                backend.set(username, forKey: Entries.username)
            } else {
                backend.removeObject(forKey: Entries.username)
            }
        }
    }

    var accountInfo: AccountInfo? {
        get {
            guard let info = backend.dictionary(forKey: Entries.accountInfo) else {
                return nil
            }
            return GlossAccountInfo(json: info)?.parsed
        }
        set {
            if let info = newValue {
                backend.set(info.toJSON(), forKey: Entries.accountInfo)
            } else {
                backend.removeObject(forKey: Entries.accountInfo)
            }
        }
    }
    
    var lastSignupEmail: String? {
        get {
            return backend.string(forKey: Entries.lastSignupEmail)
        }
        set {
            if let email = newValue {
                backend.set(email, forKey: Entries.lastSignupEmail)
            } else {
                backend.removeObject(forKey: Entries.lastSignupEmail)
            }
        }
    }
    
    // MARK: Server

    var cachedServers: [Server] {
        get {
            if let copy = cachedServersCopy {
                return copy
            }
            guard let jsonArray = backend.array(forKey: Entries.cachedServers) as? [JSON] else {
                return []
            }
            return Array<GlossServer>.from(jsonArray: jsonArray)?.map { $0.parsed } ?? []
        }
        set {
            cachedServersCopy = newValue
            backend.set(newValue.toJSONArray() ?? [], forKey: Entries.cachedServers)
        }
    }
    
    var preferredServer: Server? {
        get {
            let identifier = backend.string(forKey: Entries.preferredServer)
            return cachedServers.first { $0.identifier == identifier }
        }
        set {
            backend.set(newValue?.identifier, forKey: Entries.preferredServer)
        }
    }
    
    func ping(forServerIdentifier serverIdentifier: String) -> Int? {
        return pingByServerIdentifier[serverIdentifier]
    }
    
    func setPing(_ ping: Int, forServerIdentifier serverIdentifier: String) {
        pingByServerIdentifier[serverIdentifier] = ping
    }
    
    func serializePings() {
        backend.set(pingByServerIdentifier, forKey: Entries.pingByServerIdentifier)
    }
    
    func clearPings() {
        pingByServerIdentifier.removeAll()
    }
    
    // MARK: VPN
    
    var vpnType: String? {
        get {
            return backend.string(forKey: Entries.vpnType)
        }
        set {
            backend.set(newValue, forKey: Entries.vpnType)
        }
    }
    
    var vpnDisconnectsOnSleep: Bool {
        get {
            return backend.bool(forKey: Entries.vpnDisconnectsOnSleep)
        }
        set {
            backend.set(newValue, forKey: Entries.vpnDisconnectsOnSleep)
        }
    }
    
    var vpnCustomConfigurationMaps: [String: [String : Any]]? {
        get {
            return backend.dictionary(forKey: Entries.vpnCustomConfigurationMaps) as? [String: [String: Any]]
        }
        set {
            backend.set(newValue, forKey: Entries.vpnCustomConfigurationMaps)
        }
    }
    
    // MARK: Preferences

    var isPersistentConnection: Bool? {
        get {
            guard let value = backend.object(forKey: Entries.persistentConnection) as? Bool else {
                return nil
            }
            return value
        }
        set {
            backend.set(newValue, forKey: Entries.persistentConnection)
        }
    }
    
    var mace: Bool? {
        get {
            guard let value = backend.object(forKey: Entries.mace) as? Bool else {
                return nil
            }
            return value
        }
        set {
            backend.set(newValue, forKey: Entries.mace)
        }
    }
    
    // MARK: Lifecycle
    
    func reset() {
        backend.removeObject(forKey: Entries.persistentConnection)
        backend.removeObject(forKey: Entries.mace)
        backend.removeObject(forKey: Entries.vpnType)
        backend.removeObject(forKey: Entries.vpnCustomConfigurationMaps)
    }

    func clear() {
        if let group = group {
            backend.removePersistentDomain(forName: group)
        } else {
            // FIXME: clear standard defaults
        }
    }
}

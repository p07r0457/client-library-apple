//
//  Client+Preferences.swift
//  PIALibrary
//
//  Created by Davide De Rosa on 10/2/17.
//  Copyright © 2017 London Trust Media. All rights reserved.
//

import Foundation
import SwiftyBeaver

private let log = SwiftyBeaver.self

private protocol PreferencesStore: class {
    var preferredServer: Server? { get set }
    
    var isPersistentConnection: Bool { get set }
    
    var mace: Bool { get set }

    var vpnType: String { get set }

    var vpnDisconnectsOnSleep: Bool { get set }
    
    var vpnCustomConfigurations: [String: VPNCustomConfiguration] { get set }

    func vpnCustomConfiguration(for vpnType: String) -> VPNCustomConfiguration?
    
    func setVPNCustomConfiguration(_ customConfiguration: VPNCustomConfiguration, for vpnType: String)
}

private extension PreferencesStore {
    var activeVPNCustomConfiguration: VPNCustomConfiguration? {
        return vpnCustomConfiguration(for: vpnType)
    }

    func load(from source: PreferencesStore) {
        preferredServer = source.preferredServer
        isPersistentConnection = source.isPersistentConnection
        mace = source.mace
        vpnType = source.vpnType
        vpnDisconnectsOnSleep = source.vpnDisconnectsOnSleep
        vpnCustomConfigurations = source.vpnCustomConfigurations
    }
}

extension Client {

    /// The persistent preferences of the client.
    public final class Preferences: PreferencesStore, ConfigurationAccess, DatabaseAccess {

        /// The default preferences (editable).
        public var defaults = Editable()
       
        /**
         Returns an editable object for preferences modification.
         
         - Returns: An `Editable` object for preferences modification.
         */
        public func editable() -> Editable {
            let copy = Editable()
            copy.load(from: self)
            copy.target = self
            return copy
        }
        
        // MARK: PreferencesStore

        /// The preferred `Server`.
        public fileprivate(set) var preferredServer: Server? {
            get {
                return accessedDatabase.plain.preferredServer
            }
            set {
                accessedDatabase.plain.preferredServer = newValue
            }
        }
        
        /// Enables automatic VPN reconnection.
        public fileprivate(set) var isPersistentConnection: Bool {
            get {
                return accessedDatabase.plain.isPersistentConnection ?? defaults.isPersistentConnection
            }
            set {
                accessedDatabase.plain.isPersistentConnection = newValue
            }
        }
        
        /// The MACE option for ad-blocking.
        public fileprivate(set) var mace: Bool {
            get {
                return accessedDatabase.plain.mace ?? defaults.mace
            }
            set {
                accessedDatabase.plain.mace = newValue
            }
        }
        
        /// The type of the current VPN profile. Must be found in `Client.Configuration.availableVPNTypes(...)`.
        ///
        /// - Seealso: `VPNProfile.vpnType`
        /// - Seealso: `Client.Configuration.availableVPNTypes(...)`
        public fileprivate(set) var vpnType: String {
            get {
                return accessedDatabase.plain.vpnType ?? defaults.vpnType
            }
            set {
                accessedDatabase.plain.vpnType = newValue
            }
        }
        
        /// When device sleeps, disconnects from the VPN if `true`.
        public fileprivate(set) var vpnDisconnectsOnSleep: Bool {
            get {
                return accessedDatabase.plain.vpnDisconnectsOnSleep
            }
            set {
                accessedDatabase.plain.vpnDisconnectsOnSleep = newValue
            }
        }
        
        /// A dictionary of custom VPN configurations, mapped by `VPNProfile.vpnType`.
        public fileprivate(set) var vpnCustomConfigurations: [String: VPNCustomConfiguration] {
            get {
//                return accessedDatabase.plain.vpnCustomConfigurationMaps?.map {
//                    let profile = configuration.profile(forVPNType: $0.key)
//                    return profile?.parseCustomConfiguration($0.value)
//                }
                guard let allMaps = accessedDatabase.plain.vpnCustomConfigurationMaps, !allMaps.isEmpty else {
                    return defaults.vpnCustomConfigurations
                }
                var allConfigurations: [String: VPNCustomConfiguration] = [:]
                for (vpnType, map) in allMaps {
                    let profile = configuration.profile(forVPNType: vpnType)
                    guard let configuration = profile?.parsedCustomConfiguration(from: map) ?? defaults.vpnCustomConfiguration(for: vpnType) else {
                        continue
                    }
                    allConfigurations[vpnType] = configuration
                }
                return allConfigurations
            }
            set {
                accessedDatabase.plain.vpnCustomConfigurationMaps = newValue.mapValues { $0.serialized() }
            }
        }

        /**
         Returns the custom VPN configuration for a given `VPNProfile.vpnType`.

         - Parameter vpnType: The VPN profile type.
         - Returns: The associated `VPNCustomConfiguration` or `nil` if none.
         */
        public func vpnCustomConfiguration(for vpnType: String) -> VPNCustomConfiguration? {
            guard let map = accessedDatabase.plain.vpnCustomConfigurationMaps?[vpnType] else {
                return defaults.vpnCustomConfigurations[vpnType]
            }
            let profile = configuration.profile(forVPNType: vpnType)
            return profile?.parsedCustomConfiguration(from: map)
        }
        
        /**
         Sets the custom VPN configuration for a given `VPNProfile.vpnType`.
         
         - Parameter customConfiguration: The `VPNCustomConfiguration` to associate or `nil` if none.
         - Parameter vpnType: The VPN profile type.
         */
        public func setVPNCustomConfiguration(_ customConfiguration: VPNCustomConfiguration, for vpnType: String) {
            var allMaps = accessedDatabase.plain.vpnCustomConfigurationMaps ?? [:]
            allMaps[vpnType] = customConfiguration.serialized()
            accessedDatabase.plain.vpnCustomConfigurationMaps = allMaps
        }
    }
}

// MARK: Editable

extension Client.Preferences {

    /// Provides a means to edit `Client.Preferences` in a buffered way. Changes can be committed or reverted.
    public class Editable: PreferencesStore {
        fileprivate var target: Client.Preferences?
        
        fileprivate init() {
            preferredServer = nil
            isPersistentConnection = true
            mace = false
            vpnType = IPSecProfile.vpnType
            vpnDisconnectsOnSleep = false
            vpnCustomConfigurations = [:]
        }

        /**
         Commits the changes to the preferences.
         */
        public func commit() {
            target?.load(from: self)
        }

        /**
         Resets the preferences to factory defaults.
         
         - Returns: `self`
         - Seealso: `Client.Preferences.defaults`
         */
        @discardableResult public func reset() -> Self {
            guard let target = target else {
                return self
            }
            load(from: target.defaults)
            return self
        }
        
        // MARK: PreferencesStore

        /// :nodoc:
        public var preferredServer: Server?
        
        /// :nodoc:
        public var isPersistentConnection: Bool
        
        /// :nodoc:
        public var mace: Bool
        
        /// :nodoc:
        public var vpnType: String
        
        /// :nodoc:
        public var vpnDisconnectsOnSleep: Bool
        
        /// :nodoc:
        public var vpnCustomConfigurations: [String: VPNCustomConfiguration]

        /// :nodoc:
        public func vpnCustomConfiguration(for vpnType: String) -> VPNCustomConfiguration? {
            return vpnCustomConfigurations[vpnType]
        }
        
        /// :nodoc:
        public func setVPNCustomConfiguration(_ customConfiguration: VPNCustomConfiguration, for vpnType: String) {
            vpnCustomConfigurations[vpnType] = customConfiguration
        }

        // MARK: Required actions

        /**
         Returns the action required to make the pending changes effective for the current VPN profile.

         - Returns: A `VPNAction` or `nil` if no action is required.
         */
        public func requiredVPNAction() -> VPNAction? {
            guard let target = target else {
                return nil
            }
            var queue: [VPNAction] = []
            if (isPersistentConnection != target.isPersistentConnection) {
                queue.append(VPNActionReinstall())
            }
            if (vpnDisconnectsOnSleep != target.vpnDisconnectsOnSleep) {
                queue.append(VPNActionReinstall())
            }
            if (mace != target.mace) {
                queue.append(VPNActionReconnect())
            }
            if !isPreferredServer(equalTo: target.preferredServer) {
                queue.append(VPNActionReinstall())
            }
            if (vpnType != target.vpnType) {
                queue.append(VPNActionDisconnectAndReinstall())
            }
            if let configuration = vpnCustomConfigurations[vpnType],
                let targetConfiguration = target.activeVPNCustomConfiguration,
                !configuration.isEqual(to: targetConfiguration) {
                
                queue.append(VPNActionReinstall())
            }
            return queue.max { $0.priority < $1.priority }
        }
        
        private func isPreferredServer(equalTo server: Server?) -> Bool {
            guard let preferredServer = preferredServer else {
                return (server == nil)
            }
            guard let server = server else {
                return false
            }
            return (preferredServer == server)
        }
        
        /**
         Returns `true` if the VPN needs to reconnect to make the pending changes effective.
         
         - Returns: `true` if the VPN needs reconnection.
         */
        public func suggestsVPNReconnection() -> Bool {
            guard let target = target else {
                return false
            }
            if (mace != target.mace) {
                return true
            }
            if let configuration = vpnCustomConfigurations[vpnType],
                let targetConfiguration = target.activeVPNCustomConfiguration,
                !configuration.isEqual(to: targetConfiguration) {

                return true
            }
            return false
        }
    }
}

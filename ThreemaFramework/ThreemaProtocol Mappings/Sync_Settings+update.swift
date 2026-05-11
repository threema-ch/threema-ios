import ThreemaProtocols

// TODO: Implement (IOS-3869)

extension D2dSync_Settings {
    mutating func updateContactSyncPolicy(syncContacts: Bool) {
        contactSyncPolicy = syncContacts ? .sync : .notSynced
    }
}

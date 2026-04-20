import CocoaLumberjackSwift
import Foundation
import ThreemaProtocols

extension MDMSetup {

    /// MD sync of setting one to one and group call, if MDM parameter 'th_disable_calls' or 'th_disable_group_calls' is
    /// set
    @objc func syncSettingCalls() {
        guard let localBusniessInjector = businessInjector as? BusinessInjector else {
            DDLogError("BusinessInjector is not set")
            return
        }

        guard AppSetup.isCompleted else {
            return
        }
        
        guard localBusniessInjector.userSettings.enableMultiDevice,
              existsMdmKey(MDM_KEY_DISABLE_CALLS) || existsMdmKey(MDM_KEY_DISABLE_GROUP_CALLS) else {
            return
        }

        localBusniessInjector.settingsStoreInternal.syncSettingCalls()
    }

    /// MD sync of MDM parameter 'th_disable_add_contact'
    @objc func sync() {
        guard let localBusniessInjector = businessInjector as? BusinessInjector else {
            DDLogError("BusinessInjector is not set")
            return
        }

        guard localBusniessInjector.userSettings.enableMultiDevice,
              AppSetup.isCompleted
        else {
            return
        }

        _ = TaskManager().add(taskDefinition: TaskDefinitionMdmParameterSync(mdmParameters: mdmParameters()))
    }

    func mdmParameters() -> Sync_MdmParameters {
        var mdmParametersSync = Sync_MdmParameters()
        
        if let externalMdm = getCompanyMDM() {
            if let parameterDisableAddContact = mdmParameterSyncBool(
                key: MDM_KEY_DISABLE_ADD_CONTACT,
                mdmParameters: externalMdm
            ) {
                mdmParametersSync.externalParameters[MDM_KEY_DISABLE_ADD_CONTACT] = parameterDisableAddContact
            }
            
            if let parameterEnforceRemoteSecret = mdmParameterSyncBool(
                key: MDM_KEY_ENABLE_REMOTE_SECRET,
                mdmParameters: externalMdm
            ) {
                mdmParametersSync.externalParameters[MDM_KEY_ENABLE_REMOTE_SECRET] = parameterEnforceRemoteSecret
            }
        }

        if let threemaMdm = getThreemaMDM(),
           let mdmParameters = threemaMdm[MDM_KEY_THREEMA_PARAMS] as? [AnyHashable: Any] {
            if let parameterDisableAddContact = mdmParameterSyncBool(
                key: MDM_KEY_DISABLE_ADD_CONTACT,
                mdmParameters: mdmParameters
            ) {
                mdmParametersSync.threemaParameters[MDM_KEY_DISABLE_ADD_CONTACT] = parameterDisableAddContact
            }
            
            if let parameterEnforceRemoteSecret = mdmParameterSyncBool(
                key: MDM_KEY_ENABLE_REMOTE_SECRET,
                mdmParameters: mdmParameters
            ) {
                mdmParametersSync.threemaParameters[MDM_KEY_ENABLE_REMOTE_SECRET] = parameterEnforceRemoteSecret
            }
        }

        return mdmParametersSync
    }

    private func mdmParameterSyncBool(key: String, mdmParameters: [AnyHashable: Any]) -> Sync_MdmParameters.Parameter? {
        guard let value = mdmParameters[key] as? Bool else {
            return nil
        }

        return Sync_MdmParameters.Parameter.with {
            $0.booleanValue = value
        }
    }
}

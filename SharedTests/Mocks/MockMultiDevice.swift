import ThreemaEssentials

import ThreemaFramework

enum MockMultiDevice {
    static var deviceGroupKeys: DeviceGroupKeys {
        DeviceGroupKeys(
            dgpk: BytesUtility.generateDeviceGroupKey(),
            dgrk: BytesUtility.generateDeviceGroupKey(),
            dgdik: BytesUtility.generateDeviceGroupKey(),
            dgsddk: BytesUtility.generateDeviceGroupKey(),
            dgtsk: BytesUtility.generateDeviceGroupKey(),
            deviceGroupIDFirstByteHex: "a1"
        )
    }

    static var deviceID: Data {
        BytesUtility.generateDeviceGroupKey()
    }
}

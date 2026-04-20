import AVFAudio

extension AVAudioSession.CategoryOptions {
    public static var threemaCategoryOptions: Self = [
        .duckOthers,
        .allowBluetooth,
        .allowBluetoothA2DP,
        .allowAirPlay,
    ]
}

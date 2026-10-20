import libthreemaSwift

extension LocationMessageState {
    init(locationMessageEntity: LocationMessageEntity) {
        self.init(
            latitude: locationMessageEntity.latitude.doubleValue,
            longitude: locationMessageEntity.longitude.doubleValue,
            accuracyM: locationMessageEntity.accuracy?.doubleValue,
            name: locationMessageEntity.poiName ?? String.empty,
            address: locationMessageEntity.poiAddress ?? String.empty
        )
    }
}

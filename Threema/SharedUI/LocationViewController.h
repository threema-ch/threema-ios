//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2023 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

@class LocationMessage;

@interface LocationViewController : UIViewController <MKAnnotation, MKMapViewDelegate>

@property (nonatomic, strong) LocationMessage *locationMessage;

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *mapTypeControl;
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;

/* for MKAnnotation */
@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;

- (IBAction)actionButton:(id)sender;
- (IBAction)mapTypeChanged:(id)sender;
- (IBAction)gotoUserLocationButtonTapped:(id)sender;
- (IBAction)gotoLocationButtonTapped:(id)sender;

- (instancetype)initWithLocationMessage:(LocationMessage *)locationMessage;

@end

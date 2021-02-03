//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2021 Threema GmbH
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

@class PreviewLocationViewController;

@protocol PreviewLocationViewControllerDelegate

- (void)previewLocationController:(PreviewLocationViewController *)controller didChooseToSendCoordinate:(CLLocationCoordinate2D)coordinate accuracy:(CLLocationAccuracy)accuracy poiName:(NSString*)poiName poiAddress:(NSString*)poiAddress;

@end

@interface PreviewLocationViewController : UIViewController <MKMapViewDelegate, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UISearchResultsUpdating, UISearchControllerDelegate, UISearchControllerDelegate>

@property (nonatomic, weak) id<PreviewLocationViewControllerDelegate> delegate;

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UITableView *poiTableView;
@property (weak, nonatomic) IBOutlet UIView *footerView;
@property (weak, nonatomic) CLLocation *pendingLocation;
@property (strong, nonatomic) UISearchController *searchController;

- (IBAction)cancelAction:(id)sender;
- (IBAction)sendAction:(id)sender;

@end

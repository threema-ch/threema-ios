//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2020 Threema GmbH
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

#import "PreviewLocationViewController.h"
#import "UIImageView+WebCache.h"
#import "PoiTableViewCell.h"
#import "UserSettings.h"
#import "PointOfInterest.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
static const CLLocationDegrees kDefaultSpan = 0.01;
static const float kPlacesUpdateInterval = 5.0;

@interface PreviewLocationViewController ()
    @property CLLocationManager *locationManager;
@end

@implementation PreviewLocationViewController {
    CLLocation *lastLocation, *lastLocationPlaces;
    NSMutableArray *curPlaces;
    NSUInteger placesRequestCount;
    NSDate *lastPlacesUpdate;
    BOOL loading;
    NSString *lastSearchText;
    UIBarButtonItem *rightBarButton;
    UIBarButtonItem *leftBarButton;
    UIView *overlayView;
    UIView *lineView;
    UIRefreshControl *refreshControl;
}

- (void)dealloc {
    self.mapView.delegate = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if ([UserSettings sharedUserSettings].enablePoi) {
        [self setRefreshControlTitle:NO];
        
        overlayView = [[UIView alloc] initWithFrame:CGRectMake(0, self.navigationController.navigationBar.frame.size.height, self.view.frame.size.width, self.view.frame.size.height)];
        overlayView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.4];
        overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [overlayView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(overlayViewTapped)]];
        
        leftBarButton = self.navigationItem.leftBarButtonItem;
        rightBarButton = self.navigationItem.rightBarButtonItem;
        
        self.searchController = [[UISearchController alloc]initWithSearchResultsController:nil];
        self.searchController.searchBar.showsScopeBar = NO;
        self.searchController.searchBar.scopeButtonTitles = nil;
        self.searchController.searchBar.delegate = self;
        self.searchController.searchResultsUpdater = self;
        self.searchController.delegate = self;
        self.searchController.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.searchController.searchBar sizeToFit];
        self.searchController.dimsBackgroundDuringPresentation = NO;
        self.searchController.hidesNavigationBarDuringPresentation = false;
        self.definesPresentationContext = YES;
        self.navigationItem.titleView = self.searchController.searchBar;
        
        self.navigationItem.leftBarButtonItem = leftBarButton;
        self.navigationItem.rightBarButtonItem = rightBarButton;
        
        refreshControl = [UIRefreshControl new];
        [refreshControl addTarget:self action:@selector(pulledForRefresh:) forControlEvents:UIControlEventValueChanged];
        self.poiTableView.refreshControl = refreshControl;
        
        self.poiTableView.rowHeight = UITableViewAutomaticDimension;
        self.poiTableView.estimatedRowHeight = 44.0;
    } else {
        CGRect frame = self.mapView.frame;
        frame.size.height = self.poiTableView.frame.origin.y + self.poiTableView.frame.size.height;
        self.mapView.frame = frame;
        
        [self.poiTableView removeFromSuperview];
    }

    [self setupColors];
}

- (void)setupColors {
    [self.view setBackgroundColor:[Colors backgroundLight]];
    
    [Colors updateTableView:self.poiTableView];
    [Colors updateSearchBar:_searchController.searchBar];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateCanSend];
    
    [self.mapView setRegion:MKCoordinateRegionMake(self.mapView.userLocation.coordinate, MKCoordinateSpanMake(kDefaultSpan, kDefaultSpan)) animated:NO];
    
    if (lineView != nil)
        lineView.frame = CGRectMake(0, self.poiTableView.frame.origin.y - 1, self.poiTableView.frame.size.width, 1);
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [self checkLocationAccess];
    
    [self mapView:self.mapView didUpdateUserLocation:self.mapView.userLocation];
    
    [super viewDidAppear:animated];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    lineView.frame = CGRectMake(0, self.poiTableView.frame.origin.y - 1, self.poiTableView.frame.size.width, 1);
}

- (BOOL)shouldAutorotate {
    return YES;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (SYSTEM_IS_IPAD) {
        return UIInterfaceOrientationMaskAll;
    }
    
    return UIInterfaceOrientationMaskAllButUpsideDown;
}


#pragma mark - Private functions

- (void)setRefreshControlTitle:(BOOL)active {
    NSString *refreshText = nil;
    UIFont *font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    if (active) {
        refreshText = NSLocalizedString(@"refreshing", nil);
    } else {
        refreshText = NSLocalizedString(@"pull_to_refresh", nil);
    }
    NSMutableAttributedString *attributedRefreshText = [[NSMutableAttributedString alloc] initWithString:refreshText attributes:@{ NSFontAttributeName: font, NSForegroundColorAttributeName: [Colors fontLight], NSBackgroundColorAttributeName: [UIColor clearColor]}];
    refreshControl.attributedTitle = attributedRefreshText;
}

- (void)checkLocationAccess {
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status == kCLAuthorizationStatusRestricted || status == kCLAuthorizationStatusDenied) {
        [self showLocationAccessAlert];
    } else {
        if (status == kCLAuthorizationStatusNotDetermined) {
            _locationManager = [[CLLocationManager alloc] init];
            [_locationManager requestWhenInUseAuthorization];
        }
    }
}

- (void)showLocationAccessAlert {
    [UIAlertTemplate showAlertWithOwner:self title:NSLocalizedString(@"location_disabled_title", nil) message:NSLocalizedString(@"location_disabled_message", nil) actionOk:nil];
}

- (void)updateCanSend {
    self.navigationItem.rightBarButtonItem.enabled = (self.mapView.userLocation != nil && !(self.mapView.userLocation.coordinate.latitude == 0 && self.mapView.userLocation.coordinate.longitude == 0));
}

- (void)pulledForRefresh:(UIRefreshControl *)sender {
    [self setRefreshControlTitle:YES];
    lastPlacesUpdate = nil;
    [self updatePlacesForLocation:self.mapView.userLocation.location noDelay:NO onCompletion:^{
        [sender endRefreshing];
        [self setRefreshControlTitle:NO];
    }];
}


#pragma mark Map view delegate

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation {
    [self updateCanSend];
    
    if (userLocation == nil)
        return;
    
    /* Determine distance to last location. If greater than 1 km, pan map */
    CLLocationDistance distance = 0;
    if (lastLocation != nil)
        distance = [lastLocation distanceFromLocation:userLocation.location];
    
    if (lastLocation == nil || distance > 1000) {
        MKCoordinateRegion region = MKCoordinateRegionMake(userLocation.coordinate, MKCoordinateSpanMake(kDefaultSpan, kDefaultSpan));
        [mapView setRegion:region animated:(lastLocation != nil)];
        lastLocation = userLocation.location;
    }
    
    /* Determine distance separately for places reload */
    distance = 0;
    if (lastLocationPlaces != nil)
        distance = [lastLocationPlaces distanceFromLocation:userLocation.location];
    
    if (lastLocationPlaces == nil || distance > 20) {
        lastLocationPlaces = userLocation.location;
        [self updatePlacesForLocation:lastLocationPlaces noDelay:NO onCompletion:nil];
    }
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
    if (![view.annotation isKindOfClass:[PointOfInterest class]])
        return;
    
    PointOfInterest *poi = view.annotation;
    [self.delegate previewLocationController:self didChooseToSendCoordinate:CLLocationCoordinate2DMake(poi.latitude, poi.longitude) accuracy:0 poiName:poi.name poiAddress:poi.address];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (curPlaces.count == 0)
        return;
    
    PointOfInterest *poi = [curPlaces objectAtIndex:indexPath.row];
    [self.delegate previewLocationController:self didChooseToSendCoordinate:CLLocationCoordinate2DMake(poi.latitude, poi.longitude) accuracy:0 poiName:poi.name poiAddress:poi.address];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark Table view data source

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if ([cell isKindOfClass:[UITableViewCell class]]) {
        [Colors updateTableViewCell:cell];
    }
    
    if ([cell isKindOfClass:[PoiTableViewCell class]]) {
        [((PoiTableViewCell *)cell).addressLabel setTextColor:[Colors fontLight]];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.poiTableView) {
        if (curPlaces.count == 0)
            return 1;
        else
            return curPlaces.count;
    } else {
        /* search bar */
        return 0;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

-(CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.poiTableView) {
        if (curPlaces.count == 0) {
            if (loading) {
                static NSString *CellIdentifier = @"SpinnerCell";
                return [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            } else if (_searchController.searchBar.text.length == 0) {
                static NSString *CellIdentifier = @"EnterQueryCell";
                return [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            } else {
                static NSString *CellIdentifier = @"NoPlacesFoundCell";
                return [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            }
        } else {
            static NSString *CellIdentifier = @"PoiCell";
            
            PoiTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            
            PointOfInterest *poi = [curPlaces objectAtIndex:indexPath.row];
            cell.nameLabel.text = poi.name;
            cell.addressLabel.text = poi.address;
            
            return cell;
        }
    } else {
        /* search bar */
        return nil;
    }
}


#pragma mark - Search controller delegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    NSString *searchText = searchBar.text;
    DDLogVerbose(@"search: %@", searchBar.text);
    [_searchController setActive:NO];
    _searchController.searchBar.text = searchText;
    lastPlacesUpdate = nil;
    lastSearchText = searchText;
    [self updatePlacesForLocation:self.mapView.userLocation.location noDelay:NO onCompletion:nil];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    DDLogVerbose(@"text changed: %@, active: %d", searchBar.text, _searchController.active);
    
    if (searchText.length == 0 && ![lastSearchText isEqualToString:searchText]) {
        lastPlacesUpdate = nil;
        lastSearchText = searchText;
        [self updatePlacesForLocation:self.mapView.userLocation.location noDelay:NO onCompletion:nil];
    }
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    DDLogVerbose(@"searchDisplayControllerWillBeginSearch");
    
    if (_searchController.active && searchBar.text.length > 0)
        [self.view addSubview:overlayView];
    else
        [overlayView removeFromSuperview];
    
    [self.navigationItem setRightBarButtonItem:nil animated:YES];
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    DDLogVerbose(@"searchDisplayControllerWillEndSearch");
    [overlayView removeFromSuperview];
    [self.navigationItem setRightBarButtonItem:rightBarButton animated:YES];
    [self.navigationItem setLeftBarButtonItem:leftBarButton animated:YES];
}

-(void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    if (searchController.searchBar.text.length == 0 && ![lastSearchText isEqualToString:searchController.searchBar.text]) {
        lastPlacesUpdate = nil;
        lastSearchText = searchController.searchBar.text;
        [self updatePlacesForLocation:self.mapView.userLocation.location noDelay:NO onCompletion:nil];
    }
    
    if (searchController.active && searchController.searchBar.text.length > 0)
        [self.view addSubview:overlayView];
    else
        [overlayView removeFromSuperview];
}

- (void)overlayViewTapped {
    _searchController.active = NO;
}


#pragma mark - IBActions

- (IBAction)cancelAction:(id)sender {
    if (_searchController.active)
        [_searchController setActive:NO];
    else
        [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)sendAction:(id)sender {
    if (self.mapView.userLocation != nil && !(self.mapView.userLocation.coordinate.latitude == 0 && self.mapView.userLocation.coordinate.longitude == 0))
        [self.delegate previewLocationController:self didChooseToSendCoordinate:self.mapView.userLocation.coordinate accuracy:self.mapView.userLocation.location.horizontalAccuracy poiName:nil poiAddress:nil];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)updatePlacesForLocation:(CLLocation*)location noDelay:(BOOL)noDelay onCompletion:(void(^)(void))onCompletion {
    if (location == nil || (fabs(location.coordinate.latitude) < 0.000001 && fabs(location.coordinate.longitude) < 0.000001)) {
        if (onCompletion != nil)
            onCompletion();
        return;
    }
    
    DDLogVerbose(@"updatePlacesForLocation: %@, loading: %d", location, loading);
    
    if (loading || (lastPlacesUpdate != nil && [lastPlacesUpdate timeIntervalSinceNow] > -kPlacesUpdateInterval)) {
        /* Another update is already in progress or was completed a short time ago. Check again in a moment. */
        DDLogVerbose(@"Already loading or loaded in the past %.1f seconds - %@", kPlacesUpdateInterval, noDelay ? @"ignoring" : @"delaying");
        
        if (!noDelay) {
            self.pendingLocation = location;
            
            /* use weak reference to self to avoid retain cycle that will keep us from not using location services anymore */
            __weak PreviewLocationViewController *wself = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kPlacesUpdateInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [wself updatePlacesForLocation:wself.pendingLocation noDelay:YES onCompletion:onCompletion];
                wself.pendingLocation = nil;
            });
        } else {
            if (onCompletion != nil)
                onCompletion();
        }
        
        return;
    }
    
    lastPlacesUpdate = [NSDate date];
    
    double radius = MAX(50, MAX(location.horizontalAccuracy, location.verticalAccuracy) * 2);
    if (_searchController.searchBar.text.length > 0)
        radius = 1000;
    
    placesRequestCount++;
    loading = YES;
    NSUInteger lastPlacesRequestCount = placesRequestCount;
    
    if ([UserSettings sharedUserSettings].enablePoi) {
        [self.poiTableView reloadData];
        
        if (_searchController.searchBar.text.length > 0) {
            MKLocalSearchRequest *searchRequest = [[MKLocalSearchRequest alloc] init];
            searchRequest.naturalLanguageQuery = _searchController.searchBar.text;
            searchRequest.region = self.mapView.region;
            MKLocalSearch *localSearch = [[MKLocalSearch alloc] initWithRequest:searchRequest];
            [localSearch startWithCompletionHandler:^(MKLocalSearchResponse * _Nullable response, NSError * _Nullable error) {
                if (lastPlacesRequestCount < placesRequestCount) {
                    DDLogInfo(@"Discarding old result from concurrent request");
                    return;
                }
                
                if (curPlaces != nil) {
                    [self.mapView removeAnnotations:curPlaces];
                }
                curPlaces = [[NSMutableArray alloc] init];
                for (MKMapItem *mapItem in response.mapItems) {                
                    PointOfInterest *poi = [[PointOfInterest alloc] init];
                    poi.name = mapItem.placemark.name;
                    poi.address = [self formatAddressForPlacemark:mapItem.placemark];
                    poi.latitude = mapItem.placemark.coordinate.latitude;
                    poi.longitude = mapItem.placemark.coordinate.longitude;
                    [curPlaces addObject:poi];
                }
                [self.mapView addAnnotations:curPlaces];
                loading = NO;
                
                [self.poiTableView reloadData];
                [self.poiTableView setContentOffset:CGPointZero animated:YES];
                
                if (onCompletion != nil)
                    onCompletion();
            }];
        } else {
            loading = NO;
            if (onCompletion != nil)
                onCompletion();
        }
    }
}

- (NSString*)formatAddressForPlacemark:(MKPlacemark*)placemark {
    NSMutableString *address = [[NSMutableString alloc] initWithString:@""];
    if (placemark.thoroughfare != nil && placemark.subThoroughfare != nil) {
        if ([[NSLocale currentLocale].languageCode isEqualToString:@"de"]) {
            [address appendString:[NSString stringWithFormat:@"%@ %@", placemark.thoroughfare, placemark.subThoroughfare]];
        } else if ([[NSLocale currentLocale].languageCode isEqualToString:@"fr"]) {
            [address appendString:[NSString stringWithFormat:@"%@, %@", placemark.subThoroughfare, placemark.thoroughfare]];
        } else {
            [address appendString:[NSString stringWithFormat:@"%@ %@", placemark.subThoroughfare, placemark.thoroughfare]];
        }
    }
    else if (placemark.thoroughfare != nil) {
        [address appendString:placemark.thoroughfare];
    }
    else if (placemark.subThoroughfare != nil) {
        [address appendString:placemark.subThoroughfare];
    }
    
    if (placemark.postalCode != nil || placemark.locality != nil) {
        if (address.length > 0) {
            [address appendString:@", "];
        }
        
        if (placemark.postalCode != nil) {
            [address appendString:[NSString stringWithFormat:@"%@ ", placemark.postalCode]];
        }
        
        if (placemark.locality != nil) {
            [address appendString:placemark.locality];
        }
    }
    return address;
    
}

@end

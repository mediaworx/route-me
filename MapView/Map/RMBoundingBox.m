//
// Created by Kai Widmann on 11.03.14.
//

#import "RMBoundingBox.h"
#import "RMGlobalConstants.h"

@implementation RMBoundingBox {
}

@synthesize southWest = _southWest;
@synthesize northEast = _northEast;

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self initDefaultBoundingBox];
    }
    return self;
}


- (void)initDefaultBoundingBox
{
    _southWest.latitude = kRMMaxLatitude;
    _southWest.longitude = kRMMaxLongitude;
    _northEast.latitude = kRMMinLatitude;
    _northEast.longitude = kRMMinLongitude;
}


- (instancetype)initWithSouthWest:(CLLocationCoordinate2D)southWest northEast:(CLLocationCoordinate2D)northEast
{
    self = [super init];
    if (self) {
        self.southWest = southWest;
        self.northEast = northEast;
    }

    return self;
}


+ (instancetype)boundingBox
{
    return [[[self alloc] init] autorelease];
}

+ (instancetype)boundingBoxWithSouthWest:(CLLocationCoordinate2D)southWest northEast:(CLLocationCoordinate2D)northEast
{
    return [[[self alloc] initWithSouthWest:southWest northEast:northEast] autorelease];
}

- (void)addCoordinate:(CLLocationCoordinate2D)coordinate
{
    CLLocationDegrees latitude = coordinate.latitude;
    CLLocationDegrees longitude = coordinate.longitude;

    // POIs outside of the world...
    if (latitude < kRMMinLatitude || latitude > kRMMaxLatitude || longitude < kRMMinLongitude || longitude > kRMMaxLongitude) {
        return;
    }

    // this is known to have issues at the poles and at longitudes around 180/-180, but for GPSies it's ok for now
    self.northEast = CLLocationCoordinate2DMake(
            fmax(self.northEast.latitude, latitude),
            fmax(self.northEast.longitude, longitude)
    );
    self.southWest = CLLocationCoordinate2DMake(
            fmin(self.southWest.latitude, latitude),
            fmin(self.southWest.longitude, longitude)
    );
}

- (void)reset
{
    [self initDefaultBoundingBox];
}

@end
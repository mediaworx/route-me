//
// Created by Kai Widmann on 02.10.14.
//

#import "RMCoordinate.h"


@implementation RMCoordinate {

}
- (instancetype)initWithLatitude:(double)latitude longitude:(double)longitude
{
    self = [super init];
    if (self) {
        self.latitude = latitude;
        self.longitude = longitude;
    }

    return self;
}

+ (instancetype)coordinateWithLatitude:(double)latitude longitude:(double)longitude
{
    return [[[self alloc] initWithLatitude:latitude longitude:longitude] autorelease];
}

+ (instancetype)coordinateWithCLLocationCoordinate2D:(CLLocationCoordinate2D)coordinate
{
    return [[[self alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude] autorelease];
}

- (CLLocationCoordinate2D)locationCoordinate2D
{
    return CLLocationCoordinate2DMake(self.latitude, self.longitude);
}

@end
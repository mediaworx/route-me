//
// Created by Kai Widmann on 11.03.14.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>


@interface RMBoundingBox : NSObject
@property (readwrite) CLLocationCoordinate2D southWest;
@property (readwrite) CLLocationCoordinate2D northEast;

- (instancetype)initWithSouthWest:(CLLocationCoordinate2D)southWest northEast:(CLLocationCoordinate2D)northEast;

+ (instancetype)boundingBox;
+ (instancetype)boundingBoxWithSouthWest:(CLLocationCoordinate2D)southWest northEast:(CLLocationCoordinate2D)northEast;

- (void)addCoordinate:(CLLocationCoordinate2D)coordinate;

- (void)reset;

@end
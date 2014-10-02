//
// Created by Kai Widmann on 02.10.14.
//

#import <Foundation/Foundation.h>


@interface RMCoordinate : NSObject

@property (nonatomic, assign) double latitude;
@property (nonatomic, assign) double longitude;
@property (nonatomic, assign, readonly) CLLocationCoordinate2D locationCoordinate2D;

- (instancetype)initWithLatitude:(double)latitude longitude:(double)longitude;

+ (instancetype)coordinateWithLatitude:(double)latitude longitude:(double)longitude;
+ (instancetype)coordinateWithCLLocationCoordinate2D:(CLLocationCoordinate2D)coordinate;


@end
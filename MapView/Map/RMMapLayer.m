//
//  RMMapLayer.m
//
// Copyright (c) 2008-2013, Route-Me Contributors
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice, this
//   list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#import "RMMapLayer.h"
#import "RMPixel.h"

#define kRMMapLayerTypeKey @"mlt"

@implementation RMMapLayer

@synthesize annotation;
@synthesize projectedLocation;
@synthesize enableDragging;
@synthesize enableLongPress;
@synthesize userInfo;
@synthesize canShowCallout;
@synthesize calloutOffset;
@synthesize leftCalloutAccessoryView;
@synthesize rightCalloutAccessoryView;

- (id)init
{
	if (!(self = [super init]))
		return nil;

    self.annotation = nil;
    self.enableDragging = NO;
    self.enableLongPress = NO;
    self.calloutOffset = CGPointZero;
    [self setMapLayerType:kRMMapLayerTypeGeneric];

	return self;
}

- (id)initWithLayer:(id)layer
{
    if (!(self = [super initWithLayer:layer]))
        return nil;

    self.annotation = nil;
    self.userInfo = nil;
    self.calloutOffset = CGPointZero;

    return self;
}

- (void)setMapLayerType:(NSString *)mapLayerType
{
    [RMMapLayer setMapLayerType:mapLayerType forLayer:self];
}


+ (void)setMapLayerType:(NSString *)mapLayerType forLayer:(CALayer *)layer
{
    [layer setValue:mapLayerType forKey:kRMMapLayerTypeKey];
}

- (NSString *)getMapLayerType
{
    return [RMMapLayer getMapLayerTypeForLayer:self];
}

+ (NSString *)getMapLayerTypeForLayer:(CALayer *)layer
{
    NSString *type = (NSString *)[layer valueForKey:kRMMapLayerTypeKey];
    if (!type && layer.superlayer) {
        type = (NSString *)[layer.superlayer valueForKey:kRMMapLayerTypeKey];
    }
    return type;
}


- (void)addSublayer:(CALayer *)layer withMapLayerType:(NSString *)mapLayerType
{
    [RMMapLayer setMapLayerType:mapLayerType forLayer:layer];
    [self addSublayer:layer];
}


- (void)dealloc
{
    self.annotation = nil;
    self.userInfo = nil;
    [super dealloc];
}

- (void)setPosition:(CGPoint)position animated:(BOOL)animated
{
    [self setPosition:position];
}

/// return nil for certain animation keys to block core animation
//- (id <CAAction>)actionForKey:(NSString *)key
//{
//    if ([key isEqualToString:@"position"] || [key isEqualToString:@"bounds"])
//        return nil;
//    else
//        return [super actionForKey:key];
//}

@end

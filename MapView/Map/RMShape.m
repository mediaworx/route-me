///
//  RMShape.m
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

#import "RMShape.h"
#import "RMProjection.h"
#import "RMMapView.h"
#import "RMAnnotation.h"
#import "RMCoordinate.h"

@interface RMShape()
@property (nonatomic, strong) CAShapeLayer *shapeLayer;
@property (nonatomic, strong) CAShapeLayer *hitTestLayer;
@property (nonatomic, strong) UIBezierPath *bezierPath;
@property (nonatomic, strong) UIBezierPath *scaledPath;
@property (nonatomic, strong) UIBezierPath *hitTestTargetPath;
@property (nonatomic, strong) NSMutableArray *points;
@property (nonatomic, weak) RMMapView *mapView;
@end

@implementation RMShape
{
    BOOL _isFirstPoint;
    BOOL _ignorePathUpdates;
    BOOL _closed;
    float _lastScale;

    CGRect _nonClippedBounds;
    CGRect _previousBounds;

    float _hitTestTolerance;
}

#define kDefaultLineWidth 2.0

- (id)initWithView:(RMMapView *)aMapView
{
    if (!(self = [super init]))
        return nil;

    _mapView = aMapView;
    _closed = NO;

    _bezierPath = [UIBezierPath new];
    _scaledPath = nil;
    _hitTestTargetPath = nil;
    _lineWidth = kDefaultLineWidth;
    _hitTestTolerance = kDefaultLineWidth;
    _ignorePathUpdates = NO;

    _shapeLayer = [CAShapeLayer new];
    _shapeLayer.rasterizationScale = [[UIScreen mainScreen] scale];
    _shapeLayer.lineWidth = _lineWidth;
    _shapeLayer.lineCap = kCALineCapButt;
    _shapeLayer.lineJoin = kCALineJoinMiter;
    _shapeLayer.strokeColor = [UIColor blackColor].CGColor;
    _shapeLayer.fillColor = [UIColor clearColor].CGColor;
    _shapeLayer.shadowRadius = 0.0;
    _shapeLayer.shadowOpacity = 0.0;
    _shapeLayer.shadowOffset = CGSizeMake(0, 0);
    [self addSublayer:_shapeLayer];

    _pathBoundingBox = CGRectZero;
    _nonClippedBounds = CGRectZero;
    _previousBounds = CGRectZero;
    _lastScale = 0.0;

    self.masksToBounds = NO;

    _scaleLineWidth = NO;
    _scaleLineDash = NO;
    _isFirstPoint = YES;

    _points = [NSMutableArray array];

    [(id)self setValue:[[UIScreen mainScreen] valueForKey:@"scale"] forKey:@"contentsScale"];

    return self;
}

- (void)initHitTestLayer
{
    _hitTestLayer = [CAShapeLayer new];
    _hitTestLayer.rasterizationScale = [[UIScreen mainScreen] scale];
    _hitTestLayer.lineWidth = 2.0;
    _hitTestLayer.lineCap = kCALineCapRound;
    _hitTestLayer.lineJoin = kCALineJoinRound;
    _hitTestLayer.strokeColor = [UIColor clearColor].CGColor;
    _hitTestLayer.fillColor = CGColorCreateCopyWithAlpha(_shapeLayer.strokeColor, 0.2);
    _hitTestLayer.shadowRadius = 0.0;
    _hitTestLayer.shadowOpacity = 0.0;
    _hitTestLayer.shadowOffset = CGSizeMake(0, 0);
}


- (void)dealloc
{
    _mapView = nil;
    _bezierPath = nil;
    _scaledPath = nil;
    _hitTestTargetPath = nil;
    _shapeLayer = nil;
    _hitTestLayer = nil;
    _points = nil;
}

- (id <CAAction>)actionForKey:(NSString *)key
{
    return nil;
}

#pragma mark -

- (void)recalculateGeometryAnimated:(BOOL)animated
{
    if (_ignorePathUpdates)
        return;

    float scale = 1.0f / (float)[_mapView metersPerPixel];

    // we have to calculate the scaledLineWidth even if scalling did not change
    // as the lineWidth might have changed
    float scaledLineWidth;

    if (_scaleLineWidth)
        scaledLineWidth = _lineWidth * scale;
    else
        scaledLineWidth = _lineWidth;

    _shapeLayer.lineWidth = scaledLineWidth;

    if (_lineDashLengths)
    {
        if (_scaleLineDash)
        {
            NSMutableArray *scaledLineDashLengths = [NSMutableArray array];

            for (NSNumber *lineDashLength in _lineDashLengths)
            {
                [scaledLineDashLengths addObject:[NSNumber numberWithFloat:lineDashLength.floatValue * scale]];
            }

            _shapeLayer.lineDashPattern = scaledLineDashLengths;
        }
        else
        {
            _shapeLayer.lineDashPattern = _lineDashLengths;
        }
    }

    // we are about to overwrite nonClippedBounds, therefore we save the old value
    CGRect previousNonClippedBounds = _nonClippedBounds;

    if (scale != _lastScale)
    {
        _lastScale = scale;

        CGAffineTransform scaling = CGAffineTransformMakeScale(scale, scale);
        _scaledPath = [_bezierPath copy];
        [_scaledPath applyTransform:scaling];

        if (animated)
        {
            CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"path"];
            animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            animation.repeatCount = 0;
            animation.autoreverses = NO;
            animation.fromValue = (id) _shapeLayer.path;
            animation.toValue = (id) _scaledPath.CGPath;
            [_shapeLayer addAnimation:animation forKey:@"animatePath"];
        }

        _shapeLayer.path = _scaledPath.CGPath;

        // calculate the bounds of the scaled path
        CGRect boundsInMercators = _scaledPath.bounds;
        _nonClippedBounds = CGRectInset(boundsInMercators, -scaledLineWidth - (2 * _shapeLayer.shadowRadius), -scaledLineWidth - (2 * _shapeLayer.shadowRadius));
    }

    // if the path is not scaled, nonClippedBounds stay the same as in the previous invokation

    // Clip bound rect to screen bounds.
    // If bounds are not clipped, they won't display when you zoom in too much.

    CGRect screenBounds = [_mapView bounds];

    // we start with the non-clipped bounds and clip them
    CGRect clippedBounds = _nonClippedBounds;

    float offset;
    const float outset = 150.0f; // provides a buffer off screen edges for when path is scaled or moved

    CGPoint newPosition = self.annotation.position;

//    RMLog(@"x:%f y:%f screen bounds: %f %f %f %f", newPosition.x, newPosition.y,  screenBounds.origin.x, screenBounds.origin.y, screenBounds.size.width, screenBounds.size.height);

    // Clip top
    offset = newPosition.y + clippedBounds.origin.y - screenBounds.origin.y + outset;
    if (offset < 0.0f)
    {
        clippedBounds.origin.y -= offset;
        clippedBounds.size.height += offset;
    }

    // Clip left
    offset = newPosition.x + clippedBounds.origin.x - screenBounds.origin.x + outset;
    if (offset < 0.0f)
    {
        clippedBounds.origin.x -= offset;
        clippedBounds.size.width += offset;
    }

    // Clip bottom
    offset = newPosition.y + clippedBounds.origin.y + clippedBounds.size.height - screenBounds.origin.y - screenBounds.size.height - outset;
    if (offset > 0.0f)
    {
        clippedBounds.size.height -= offset;
    }

    // Clip right
    offset = newPosition.x + clippedBounds.origin.x + clippedBounds.size.width - screenBounds.origin.x - screenBounds.size.width - outset;
    if (offset > 0.0f)
    {
        clippedBounds.size.width -= offset;
    }

    if (animated)
    {
        CABasicAnimation *positionAnimation = [CABasicAnimation animationWithKeyPath:@"position"];
        positionAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        positionAnimation.repeatCount = 0;
        positionAnimation.autoreverses = NO;
        positionAnimation.fromValue = [NSValue valueWithCGPoint:self.position];
        positionAnimation.toValue = [NSValue valueWithCGPoint:newPosition];
        [self addAnimation:positionAnimation forKey:@"animatePosition"];
    }

    super.position = newPosition;

    // bounds are animated non-clipped but set with clipping

    CGPoint previousNonClippedAnchorPoint = CGPointMake(-previousNonClippedBounds.origin.x / previousNonClippedBounds.size.width,
                                                        -previousNonClippedBounds.origin.y / previousNonClippedBounds.size.height);
    CGPoint nonClippedAnchorPoint = CGPointMake(-_nonClippedBounds.origin.x / _nonClippedBounds.size.width,
                                                -_nonClippedBounds.origin.y / _nonClippedBounds.size.height);
    CGPoint clippedAnchorPoint = CGPointMake(-clippedBounds.origin.x / clippedBounds.size.width,
                                             -clippedBounds.origin.y / clippedBounds.size.height);

    if (animated)
    {
        CABasicAnimation *boundsAnimation = [CABasicAnimation animationWithKeyPath:@"bounds"];
        boundsAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        boundsAnimation.repeatCount = 0;
        boundsAnimation.autoreverses = NO;
        boundsAnimation.fromValue = [NSValue valueWithCGRect:previousNonClippedBounds];
        boundsAnimation.toValue = [NSValue valueWithCGRect:_nonClippedBounds];
        [self addAnimation:boundsAnimation forKey:@"animateBounds"];
    }

    self.bounds = clippedBounds;
    _previousBounds = clippedBounds;

    // anchorPoint is animated non-clipped but set with clipping
    if (animated)
    {
        CABasicAnimation *anchorPointAnimation = [CABasicAnimation animationWithKeyPath:@"anchorPoint"];
        anchorPointAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        anchorPointAnimation.repeatCount = 0;
        anchorPointAnimation.autoreverses = NO;
        anchorPointAnimation.fromValue = [NSValue valueWithCGPoint:previousNonClippedAnchorPoint];
        anchorPointAnimation.toValue = [NSValue valueWithCGPoint:nonClippedAnchorPoint];
        [self addAnimation:anchorPointAnimation forKey:@"animateAnchorPoint"];
    }

    self.anchorPoint = clippedAnchorPoint;

    if (self.annotation && [_points count])
    {
        self.annotation.coordinate = ((RMCoordinate *)[_points objectAtIndex:0]).locationCoordinate2D;
        [self.annotation setBoundingBoxFromRMCoordinates:_points];
    }
}

#pragma mark -


- (void)addCurveToProjectedPoint:(RMProjectedPoint)point controlPoint1:(RMProjectedPoint)controlPoint1 controlPoint2:(RMProjectedPoint)controlPoint2 withDrawing:(BOOL)isDrawing
{
    if (isnan(point.x) || isnan(point.y) || isinf(point.x) || isinf(point.y)) {
        RMLog(@"RMShape.addCurveToProjectedPoint 1: Error adding projected point %.5f, %.5f", point.x, point.y);
        return;
    }
    CLLocationCoordinate2D coordinate = [_mapView projectedPointToCoordinate:point];
    [_points addObject:[RMCoordinate coordinateWithCLLocationCoordinate2D:coordinate]];

    if (_isFirstPoint)
    {
        _isFirstPoint = FALSE;
        projectedLocation = point;

        self.position = [_mapView projectedPointToPixel:projectedLocation];

        [_bezierPath moveToPoint:CGPointMake(0.0f, 0.0f)];
    }
    else
    {
        point.x = point.x - projectedLocation.x;
        point.y = point.y - projectedLocation.y;

        if (isDrawing)
        {
            if (controlPoint1.x == (double)INFINITY && controlPoint2.x == (double)INFINITY)
            {
                [_bezierPath addLineToPoint:CGPointMake(point.x, -point.y)];
            }
            else if (controlPoint2.x == (double)INFINITY)
            {
                controlPoint1.x = controlPoint1.x - projectedLocation.x;
                controlPoint1.y = controlPoint1.y - projectedLocation.y;

                [_bezierPath addQuadCurveToPoint:CGPointMake(point.x, -point.y)
                                   controlPoint:CGPointMake(controlPoint1.x, -controlPoint1.y)];
            }
            else
            {
                controlPoint1.x = controlPoint1.x - projectedLocation.x;
                controlPoint1.y = controlPoint1.y - projectedLocation.y;
                controlPoint2.x = controlPoint2.x - projectedLocation.x;
                controlPoint2.y = controlPoint2.y - projectedLocation.y;

                [_bezierPath addCurveToPoint:CGPointMake(point.x, -point.y)
                              controlPoint1:CGPointMake(controlPoint1.x, -controlPoint1.y)
                              controlPoint2:CGPointMake(controlPoint2.x, -controlPoint2.y)];
            }
        }
        else
        {
            [_bezierPath moveToPoint:CGPointMake(point.x, -point.y)];
        }

        _lastScale = 0.0;
        [self recalculateGeometryAnimated:NO];
    }

    [self setNeedsDisplay];
}

- (void)moveToProjectedPoint:(RMProjectedPoint)projectedPoint
{
    [self addCurveToProjectedPoint:projectedPoint
                     controlPoint1:RMProjectedPointMake((double)INFINITY, (double)INFINITY)
                     controlPoint2:RMProjectedPointMake((double)INFINITY, (double)INFINITY)
                       withDrawing:NO];
}

- (void)moveToScreenPoint:(CGPoint)point
{
    RMProjectedPoint mercator = [_mapView pixelToProjectedPoint:point];
    [self moveToProjectedPoint:mercator];
}

- (void)moveToCoordinate:(CLLocationCoordinate2D)coordinate
{
    RMProjectedPoint mercator = [[_mapView projection] coordinateToProjectedPoint:coordinate];
    [self moveToProjectedPoint:mercator];
}

- (void)addLineToProjectedPoint:(RMProjectedPoint)projectedPoint
{
    [self addCurveToProjectedPoint:projectedPoint
                     controlPoint1:RMProjectedPointMake((double)INFINITY, (double)INFINITY)
                     controlPoint2:RMProjectedPointMake((double)INFINITY, (double)INFINITY)
                       withDrawing:YES];
}

- (void)addLineToScreenPoint:(CGPoint)point
{
    RMProjectedPoint mercator = [_mapView pixelToProjectedPoint:point];
    [self addLineToProjectedPoint:mercator];
}

- (void)addLineToCoordinate:(CLLocationCoordinate2D)coordinate
{
    RMProjectedPoint mercator = [[_mapView projection] coordinateToProjectedPoint:coordinate];
    [self addLineToProjectedPoint:mercator];
}

- (void)addCurveToCoordinate:(CLLocationCoordinate2D)coordinate controlCoordinate1:(CLLocationCoordinate2D)controlCoordinate1 controlCoordinate2:(CLLocationCoordinate2D)controlCoordinate2
{
    RMProjectedPoint projectedPoint = [[_mapView projection] coordinateToProjectedPoint:coordinate];

    RMProjectedPoint controlProjectedPoint1 = [[_mapView projection] coordinateToProjectedPoint:controlCoordinate1];
    RMProjectedPoint controlProjectedPoint2 = [[_mapView projection] coordinateToProjectedPoint:controlCoordinate2];

    [self addCurveToProjectedPoint:projectedPoint
            controlProjectedPoint1:controlProjectedPoint1
            controlProjectedPoint2:controlProjectedPoint2];
}

- (void)addQuadCurveToCoordinate:(CLLocationCoordinate2D)coordinate controlCoordinate:(CLLocationCoordinate2D)controlCoordinate
{
    RMProjectedPoint projectedPoint = [[_mapView projection] coordinateToProjectedPoint:coordinate];

    RMProjectedPoint controlProjectedPoint = [[_mapView projection] coordinateToProjectedPoint:controlCoordinate];

    [self addQuadCurveToProjectedPoint:projectedPoint
                 controlProjectedPoint:controlProjectedPoint];
}

- (void)addCurveToProjectedPoint:(RMProjectedPoint)projectedPoint controlProjectedPoint1:(RMProjectedPoint)controlProjectedPoint1 controlProjectedPoint2:(RMProjectedPoint)controlProjectedPoint2
{
    [self addCurveToProjectedPoint:projectedPoint
                     controlPoint1:controlProjectedPoint1
                     controlPoint2:controlProjectedPoint2
                       withDrawing:YES];
}

- (void)addQuadCurveToProjectedPoint:(RMProjectedPoint)projectedPoint controlProjectedPoint:(RMProjectedPoint)controlProjectedPoint
{
    [self addCurveToProjectedPoint:projectedPoint
                     controlPoint1:controlProjectedPoint
                     controlPoint2:RMProjectedPointMake((double)INFINITY, (double)INFINITY)
                       withDrawing:YES];
}

- (void)performBatchOperations:(void (^)(RMShape *aShape))block
{
    _ignorePathUpdates = YES;
    block(self);
    _ignorePathUpdates = NO;

    _lastScale = 0.0;
    [self recalculateGeometryAnimated:NO];
}

- (void)clear
{
    [_bezierPath removeAllPoints];
    [_hitTestTargetPath removeAllPoints];
    [_points removeAllObjects];
    _isFirstPoint = YES;
    _hitTestTargetPath = nil;
    _usesHitTestTolerance = NO;
}

#pragma mark - Shape hit test

// Old method
- (BOOL)containsPoint:(CGPoint)thePoint
{
    return CGPathContainsPoint(_shapeLayer.path, nil, thePoint, [_shapeLayer.fillRule isEqualToString:kCAFillRuleEvenOdd]);
}

- (BOOL)shapeContainsPoint:(CGPoint)point
{
    CGPoint testPoint = [self convertPoint:point fromLayer:self.mapView.layer];
    if (_hitTestTargetPath) {
        return [_hitTestTargetPath containsPoint:testPoint];
    }
    return CGPathContainsPoint(_shapeLayer.path, nil, testPoint, [_shapeLayer.fillRule isEqualToString:kCAFillRuleEvenOdd]);
}

- (CAShapeLayer *)shapeHitTest:(CGPoint)point
{
    if ([self shapeContainsPoint:point]) {
        return _shapeLayer;
    }
    return nil;
}

- (void)prepareShapeHitTestWithTolerance:(float)tolerance
{
    _hitTestTolerance = tolerance;
    [self updateHitTestPath];
    _usesHitTestTolerance = YES;
}

- (void)updateHitTestPath
{
    CGPathRef targetPath = CGPathCreateCopyByStrokingPath(
            _shapeLayer.path,
            NULL,
            fmaxf(_lineWidth, _hitTestTolerance),
            kCGLineCapRound,
            kCGLineJoinRound,
            _bezierPath.miterLimit);

    if (targetPath == NULL) {
        return;
    }

    _hitTestTargetPath = [UIBezierPath bezierPathWithCGPath:targetPath];
    _hitTestLayer.path = _hitTestTargetPath.CGPath;
    CGPathRelease(targetPath);
}

- (void)showHitTestArea
{
    if (!_hitTestLayer) {
        [self initHitTestLayer];
    }
    if (!self.hitTestAreaVisible) {
        // always make sure the layer uses the current path
        _hitTestLayer.path = _hitTestTargetPath.CGPath;
        [self insertSublayer:_hitTestLayer below:_shapeLayer];
        _hitTestAreaVisible = YES;
    }
}

- (void)hideHitTestArea
{
    if (self.hitTestAreaVisible) {
        [_hitTestLayer removeFromSuperlayer];
        _hitTestAreaVisible = NO;
    }
}


#pragma mark - Accessors

- (void)closePath
{
    if ([_points count]) {
        CLLocationCoordinate2D locationCoordinate2D = ((RMCoordinate *)[_points objectAtIndex:0]).locationCoordinate2D;
        [self addLineToCoordinate:locationCoordinate2D];
        _closed = YES;
    }
}

- (void)setLineWidth:(float)newLineWidth
{
    _lineWidth = newLineWidth;

    _lastScale = 0.0;
    [self recalculateGeometryAnimated:NO];
}

- (NSString *)lineCap
{
    return _shapeLayer.lineCap;
}

- (void)setLineCap:(NSString *)newLineCap
{
    _shapeLayer.lineCap = newLineCap;
    [self setNeedsDisplay];
}

- (NSString *)lineJoin
{
    return _shapeLayer.lineJoin;
}

- (void)setLineJoin:(NSString *)newLineJoin
{
    _shapeLayer.lineJoin = newLineJoin;
    [self setNeedsDisplay];
}

- (UIColor *)lineColor
{
    return [UIColor colorWithCGColor:_shapeLayer.strokeColor];
}

- (void)setLineColor:(UIColor *)aLineColor
{
    if (_shapeLayer.strokeColor != aLineColor.CGColor)
    {
        _shapeLayer.strokeColor = aLineColor.CGColor;
        _hitTestLayer.fillColor = CGColorCreateCopyWithAlpha(_shapeLayer.strokeColor, 0.2);
        [self setNeedsDisplay];
    }
}

- (UIColor *)fillColor
{
    return [UIColor colorWithCGColor:_shapeLayer.fillColor];
}

- (void)setFillColor:(UIColor *)aFillColor
{
    if (_shapeLayer.fillColor != aFillColor.CGColor)
    {
        _shapeLayer.fillColor = aFillColor.CGColor;
        [self setNeedsDisplay];
    }
}

- (CGFloat)shadowBlur
{
    return _shapeLayer.shadowRadius;
}

- (void)setShadowBlur:(CGFloat)blur
{
    _shapeLayer.shadowRadius = blur;
    [self setNeedsDisplay];
}

- (CGSize)shadowOffset
{
    return _shapeLayer.shadowOffset;
}

- (void)setShadowOffset:(CGSize)offset
{
    _shapeLayer.shadowOffset = offset;
    [self setNeedsDisplay];
}

- (BOOL)enableShadow
{
    return (_shapeLayer.shadowOpacity > 0);
}

- (void)setEnableShadow:(BOOL)flag
{
    _shapeLayer.shadowOpacity   = (flag ? 1.0 : 0.0);
    _shapeLayer.shouldRasterize = ! flag;
    [self setNeedsDisplay];
}

- (NSString *)fillRule
{
    return _shapeLayer.fillRule;
}

- (void)setFillRule:(NSString *)fillRule
{
    _shapeLayer.fillRule = fillRule;
}

- (CGFloat)lineDashPhase
{
    return _shapeLayer.lineDashPhase;
}

- (void)setLineDashPhase:(CGFloat)dashPhase
{
    _shapeLayer.lineDashPhase = dashPhase;
}

- (void)setPosition:(CGPoint)newPosition animated:(BOOL)animated
{
    if (CGPointEqualToPoint(newPosition, super.position) && CGRectEqualToRect(self.bounds, _previousBounds))
        return;

    [self recalculateGeometryAnimated:animated];
}

- (void)setAnnotation:(RMAnnotation *)newAnnotation
{
    super.annotation = newAnnotation;
    [self recalculateGeometryAnimated:NO];
}

@end

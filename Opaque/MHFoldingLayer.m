//
//  MHFoldingLayer.m
//  Opaque
//
//  Created by Michael Margolis on 2/15/12.
//  Copyright (c) 2012 Massive Health. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and 
//  associated documentation files (the "Software"), to deal in the Software without restriction, 
//  including without limitation the rights to use, copy, modify, merge, publish, distribute, 
//  sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or 
//  substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
//  BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE 
//  AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
//  DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "MHFoldingLayer.h"

@interface MHFoldingLayer ()

@property (nonatomic, strong) CALayer* topHalfLayer;
@property (nonatomic, strong) CALayer* bottomHalfLayer;
@property (nonatomic, strong) CATextLayer *topTextLayer;
@property (nonatomic, strong) CATextLayer *bottomTextLayer;
@property (nonatomic, strong) CALayer *lineLayer;
@end

@implementation MHFoldingLayer

@synthesize fullHeight = _fullHeight;
@synthesize color = _color;
@synthesize layerStyle = _transitionStyle;
@synthesize title = _title;

@synthesize topHalfLayer = _topHalfLayer;
@synthesize bottomHalfLayer = _bottomHalfLayer;
@synthesize topTextLayer = _topTextLayer;
@synthesize bottomTextLayer = _bottomTextLayer;
@synthesize lineLayer = _lineLayer;

- (id)init
{
    self = [super init];
    
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = -1/200.0;
    self.sublayerTransform = transform;
    
    self.topHalfLayer = [CALayer layer];
    self.topHalfLayer.anchorPoint = CGPointMake(0.5,1);
    [self addSublayer:self.topHalfLayer];
    
    self.bottomHalfLayer = [CALayer layer];
    self.bottomHalfLayer.anchorPoint = CGPointMake(0.5,0);
    [self addSublayer:self.bottomHalfLayer];

    // If we wanted to get fancier we could render all subviews into a CGImage
    // and use that as the contents of both layers with a contentsRect.
    // This would allow for arbitrarily complex folding view/layer hierarchies
    CGFloat y = 18.0;
    CGFloat textHeight = 30.0;
    self.topTextLayer = [CATextLayer layer];
    self.topTextLayer.string = nil;
    self.topTextLayer.fontSize = 20;
    self.topTextLayer.font = CGFontCreateWithFontName(CFSTR("HelveticaNeue-Bold"));
    self.topTextLayer.contentsScale = [[UIScreen mainScreen] scale];
    self.topTextLayer.frame = CGRectMake(20,y,300,textHeight);
    [self.topHalfLayer addSublayer:self.topTextLayer];

    self.bottomTextLayer = [CATextLayer layer];
    self.bottomTextLayer.string = nil;
    self.bottomTextLayer.fontSize = self.topTextLayer.fontSize;
    self.bottomTextLayer.font = self.topTextLayer.font;
    self.bottomTextLayer.contentsScale = self.topTextLayer.contentsScale;
    self.bottomTextLayer.frame = CGRectMake(20,0,300,textHeight);
    self.bottomTextLayer.contentsRect = CGRectMake(0,(textHeight - y)/textHeight,1,1);
    self.bottomTextLayer.rasterizationScale = self.bottomTextLayer.contentsScale;
    [self.bottomHalfLayer addSublayer:self.bottomTextLayer];
    
    self.lineLayer = [CALayer layer];
    self.lineLayer.backgroundColor = [UIColor colorWithWhite:0 alpha:0.2].CGColor;
    self.lineLayer.delegate = self;
    self.lineLayer.zPosition = 1;
    [self addSublayer:self.lineLayer];
    
    return self;
}

- (void)dealloc
{
    self.topHalfLayer.delegate = nil;
    self.bottomHalfLayer.delegate = nil;
    self.lineLayer.delegate = nil;
}

- (void)setDelegate:(id)delegate
{
    [super setDelegate:delegate];
    self.topHalfLayer.delegate = delegate;
    self.bottomHalfLayer.delegate = delegate;
}

- (void)setColor:(UIColor *)color
{
    _color = color;    
    [self setNeedsLayout];
}

- (void)setTitle:(NSString *)title
{
    _title = title;
    
    // These can be attributed strings if we wanted but this example uses vanilla strings
    self.topTextLayer.string = title;
    self.bottomTextLayer.string = title;    
}

- (id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
    // Never animate the line around, it should always stick to the bottom
    if ( layer == self.lineLayer )
        return (id)[NSNull null];
    
    return nil;
}

- (void)layoutSublayers
{
    [super layoutSublayers];

    CGSize size = self.bounds.size;   
    
    // Configure the layer bounds and midpoints
    CGRect halfRect = CGRectMake(0,0,size.width, 0.5 * self.fullHeight);
    self.topHalfLayer.bounds = halfRect;
    self.bottomHalfLayer.bounds = halfRect;
    CGPoint midPoint = CGPointMake(0.5 * size.width, 0.5 * size.height);    
    self.topHalfLayer.position = midPoint;
    self.bottomHalfLayer.position = midPoint;
    
    // Update the colors
    // If these layers had contents (images, etc) we would want to have an additional transparent 
    // layer with alpha that darkened everything instead of mutating the color.
    CGFloat h,s,b,a;
    CGFloat f = 1 - self.bounds.size.height / self.fullHeight;    
    [self.color getHue:&h saturation:&s brightness:&b alpha:&a];    
    CGFloat tb = b * ( 1 - f * 0.35 ); // scale from 100% - 65% brightness
    CGFloat bb = b * ( 1 - f * 0.15 ); // scale from 100% - 85% brightness
    UIColor *topColor = [UIColor colorWithHue:h saturation:s brightness:tb alpha:a];
    UIColor *bottomColor  = [UIColor colorWithHue:h saturation:s brightness:bb alpha:a];    
    if ( self.layerStyle == MHLayerStyleFoldUp )
        topColor = bottomColor;
    else if ( self.layerStyle == MHLayerStyleFoldBack || self.layerStyle == MHLayerStyleFlat )
        bottomColor = topColor;
    
    self.topHalfLayer.backgroundColor = topColor.CGColor;
    self.bottomHalfLayer.backgroundColor = bottomColor.CGColor;    
    
    self.lineLayer.frame = CGRectMake(0,size.height-1, size.width, 1);
    
    // We are totally done if we have no transition style
    if ( self.layerStyle == MHLayerStyleFlat )
        return;
    
    // All three transition styles share the same exact math. The only difference is if we
    // reflect the top or bottom angle to create a plane on the top, plane on the bottom, 
    // or two planes intersecting each other. 
    CGFloat l = 0.5 * self.fullHeight;
    CGFloat y = 0.5 * self.bounds.size.height;
    CGFloat theta = acosf(y/l);
    CGFloat z = l * sinf(theta);    
    CGFloat topAngle = theta;
    CGFloat bottomAngle = theta;
    
    if ( self.layerStyle == MHLayerStylePinch )
    {
        topAngle *= -1;
    }
    else if ( self.layerStyle == MHLayerStyleFoldUp )
    {
        topAngle *= -1;
        bottomAngle *= -1;
    }
    
    CATransform3D transform = CATransform3DMakeTranslation(0.0, 0.0, -z);
    self.topHalfLayer.transform = CATransform3DRotate(transform, topAngle, 1.0, 0.0, 0.0);
    self.bottomHalfLayer.transform = CATransform3DRotate(transform, bottomAngle, 1.0, 0.0, 0.0);
}

@end

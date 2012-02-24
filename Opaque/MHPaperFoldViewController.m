//
//  MHPaperFoldViewController.m
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

#import "MHPaperFoldViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "MHFoldingLayer.h"

@interface MHPaperFoldViewController ()

@property (nonatomic, strong) UIView *topHalfView;
@property (nonatomic, strong) UIView *bottomHalfView;
@property (nonatomic, strong) UIView *containerView;

@property (nonatomic, strong) CALayer *listLayer;
@property (nonatomic, strong) MHFoldingLayer *currentLayer;

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) NSMutableArray *foldingLayers;
@property (nonatomic, strong) UIPinchGestureRecognizer *pinchRecognizer;

- (MHFoldingLayer*)foldingLayerWithFrame:(CGRect)frame;
- (void)updateLayerColors;
- (void)updateLayerTransitionStyles;
- (UIColor*)layerColorForIndex:(int)index count:(int)count;

@end

#define kFoldingLayerHeight 60
#define kFoldingLayerWidth 320
#define kFoldingLayerCount 7

@implementation MHPaperFoldViewController

@synthesize topHalfView = _topHalfView;
@synthesize bottomHalfView = _bottomHalfView;
@synthesize containerView = _containerView;
@synthesize foldingLayers = _foldingLayers;
@synthesize currentLayer = _currentLayer;
@synthesize scrollView = _scrollView;
@synthesize pinchRecognizer = _pinchRecognizer;
@synthesize listLayer = _listLayer;

- (id)init
{
    self = [super init];
    self.foldingLayers = [NSMutableArray array];
    return self;
}

- (void)viewDidLoad
{
    self.view.backgroundColor = [UIColor blackColor];
    
    // Our list is not a tableview, it is a scroll view full of CALayers
    CGRect scrollFrame = self.view.frame;
    scrollFrame.origin = CGPointZero;
    self.scrollView = [[UIScrollView alloc] initWithFrame:scrollFrame];
    self.scrollView.userInteractionEnabled = YES;
    self.scrollView.bounces = YES;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.delegate = self;
    
    [self.view addSubview:self.scrollView];
    
    // Set up and layout a bunch of layers
    CGFloat y = 0;
    NSArray *titles = [NSArray arrayWithObjects:@"Go to the store", @"Implement Clear-like demo", 
                       @"And another thing…", @"Mostly Harmless", @"Marvin, the Paranoid Android", @"Zaphod Beeblebrox", @"Massive Health", nil];
    
    for ( int i = 0; i < kFoldingLayerCount; i++ )
    {
        MHFoldingLayer *foldingLayer = [self foldingLayerWithFrame:CGRectMake(0,y,kFoldingLayerWidth,kFoldingLayerHeight)];
        foldingLayer.title = [titles objectAtIndex:i];
        y+= foldingLayer.frame.size.height;

        [self.scrollView.layer addSublayer:foldingLayer];
        [self.foldingLayers addObject:foldingLayer];
    }
    
    [self updateLayerColors];
    
    // Configure our gesture recognizers. 
    // Avoid creating a second pan gesture recognizer, use the scrollview's preexisting one.
    [self.scrollView.panGestureRecognizer addTarget:self action:@selector(panHandler:)];    
    self.pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchHandler:)];
    [self.scrollView addGestureRecognizer:self.pinchRecognizer];
    
    [super viewDidLoad];
}

- (void)dealloc
{
    [self.pinchRecognizer removeTarget:nil action:nil];    
    [self.pinchRecognizer.view removeGestureRecognizer:self.pinchRecognizer];
    
    [self.scrollView.panGestureRecognizer removeTarget:self action:@selector(panHandler:)];
    
    for ( MHFoldingLayer *layer in self.foldingLayers )
    {
        layer.delegate = nil;
        [layer removeFromSuperlayer];
    }
}

- (MHFoldingLayer*)layerAtPoint:(CGPoint)point
{
    for ( MHFoldingLayer *layer in self.foldingLayers )
        if ( CGRectContainsPoint(layer.frame, point ) )
            return layer;
    
    return nil;
}

// This function is a bit too large as it handles all possible drag and pan states
// A future version would probably move all of the layout code into a CALayer subclass or layout manager
// This version just uses the scale of the pinch rather than tracking the individual finger movements
- (void)handleGesture:(UIGestureRecognizer*)gesture withPinch:(BOOL)pinch andScale:(float)scale
{
    BOOL ended = NO;
    
    switch ( gesture.state )
    {
        case UIGestureRecognizerStateBegan:
        {
            // Handle the easier case of panning first            
            if ( !pinch )
            {
                // Don't create a new layer if we are scrolling up
                if ( self.scrollView.contentOffset.y > 0 )
                    break;
                
                self.currentLayer = [self foldingLayerWithFrame:CGRectMake(0,0,kFoldingLayerWidth,0)];                
                self.currentLayer.delegate = self;
                self.currentLayer.layerStyle = MHLayerStyleFoldBack;
                [self.scrollView.layer insertSublayer:self.currentLayer atIndex:0];
                [self.foldingLayers insertObject:self.currentLayer atIndex:0];
                self.currentLayer.color = [self layerColorForIndex:0 count:self.foldingLayers.count];
                break;
            }
            
            // Pinching
            CGPoint firstTouch = [gesture locationOfTouch:0 inView:self.view];
            CGPoint secondTouch = [gesture locationOfTouch:1 inView:self.view]; 
            CGPoint midPoint = CGPointMake(0.5 * ( firstTouch.x + secondTouch.x), 0.5 * ( firstTouch.y + secondTouch.y ) );
            midPoint.y += self.scrollView.contentOffset.y; // We may be further down the list
            
            MHFoldingLayer *layer = [self layerAtPoint:midPoint];
            if ( layer == nil )
                return;
            
            if ( scale < 1 )
            {
                self.currentLayer = layer;
                [self.currentLayer setValue:[NSNumber numberWithBool:NO] forKey:@"creating"];
                break;
            }
            
            self.currentLayer = [self foldingLayerWithFrame:CGRectMake(0,CGRectGetMaxY(layer.frame),kFoldingLayerWidth,0)];
            
            [self.currentLayer setValue:[NSNumber numberWithBool:YES] forKey:@"creating"];
            
            // If the pinch is in the top half of the layer, create the cell above it. Else, below.
            int layerIndex = [self.foldingLayers indexOfObject:layer];
            if ( midPoint.y < CGRectGetMidY(layer.frame) )
                layerIndex--;
            
            [self.scrollView.layer insertSublayer:self.currentLayer atIndex:layerIndex+1];
            [self.foldingLayers insertObject:self.currentLayer atIndex:layerIndex+1];
            
            self.currentLayer.color = [self layerColorForIndex:layerIndex count:self.foldingLayers.count];
            
            if ( self.currentLayer == [self.foldingLayers lastObject] )
                self.currentLayer.layerStyle = MHLayerStyleFoldUp;
            
            break;
        }
            
        case UIGestureRecognizerStateChanged:
        {
            if ( !self.currentLayer )
                break;
            
            CGFloat frameScale = scale;                        
            
            BOOL creating = [[self.currentLayer valueForKey:@"creating"] boolValue];
            if ( pinch && creating )
                frameScale = fmaxf(frameScale - 1, 0);
            
            frameScale = fminf(frameScale, 1.0);
            
            // Animate in a cell instead of pulling the scrollview down        
            if ( !pinch && ( frameScale > 0.0 && frameScale < 1.0 ) )
                self.scrollView.contentOffset = CGPointZero;                
            
            frameScale = fmaxf(frameScale, 0);
            
            CGRect frame = self.currentLayer.frame;
            frame.size.height = self.currentLayer.fullHeight * frameScale;
            self.currentLayer.frame = frame;
            
            break;
        }
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
        {   
            if ( !self.currentLayer )
                break;
            
            ended = YES;
            CGRect endFrame = self.currentLayer.frame;
            CGFloat height = self.currentLayer.frame.size.height;
            endFrame.size.height = 0;
            
            if ( height / self.currentLayer.fullHeight < 0.75 )
                [self.currentLayer setValue:[NSNumber numberWithBool:YES] forKey:@"toRemove"];
            else
                endFrame.size.height = self.currentLayer.fullHeight;
            
            self.currentLayer.frame = endFrame;            
            
            break;
        }
            
        default:
            NSLog(@"Unexpected gesture recognizer %@ state %d", gesture, gesture.state);
    }
    
    
    CGFloat y = 0;
    BOOL creating = [[self.currentLayer valueForKey:@"creating"] boolValue];    
    
    [CATransaction begin];
    
    if ( ended ) {    
        [CATransaction setCompletionBlock:^{
            
            // Update our scrollview's content size
            CALayer *lastLayer = [self.foldingLayers lastObject];
            CGSize contentSize = CGSizeZero;
            if ( lastLayer )
                contentSize = CGSizeMake(self.scrollView.frame.size.width, CGRectGetMaxY(lastLayer.frame));
            
            self.scrollView.contentSize = contentSize;
            
            if ( creating && contentSize.height > CGRectGetMaxY(self.scrollView.bounds) )
                [self.scrollView flashScrollIndicators];               
        }];
    }
    
    for ( MHFoldingLayer *layer in self.foldingLayers )
    {   
        CGRect frame = layer.frame;
        if ( pinch && layer == self.currentLayer && scale > 1 && gesture.state == UIGestureRecognizerStateChanged )
        {
            if ( creating )
                scale = fmaxf(scale - 1, 0);
            
            CGFloat dy = layer.fullHeight * scale;
            if ( creating && scale < 1 )
                frame.origin.y = y;
            else
                frame.origin.y = y + 0.5 * (dy - layer.fullHeight );
            
            layer.frame = frame;
            y += dy;
        }
        else
        {
            frame.origin.y = y;
            layer.frame = frame;
            y += frame.size.height;
        }        
    }
    
    if ( ended )
    {
        if ( [self.currentLayer valueForKey:@"toRemove"] )
            [self.foldingLayers removeObject:self.currentLayer];
        
        [self.currentLayer setValue:[NSNumber numberWithBool:NO] forKey:@"creating"];
        self.currentLayer = nil;
        
        [self updateLayerColors];
        [self updateLayerTransitionStyles];        
    }
    
    [CATransaction commit];
}

- (void)panHandler:(UIPanGestureRecognizer*)pan
{
    CGFloat translation = [pan translationInView:pan.view].y;
    CGFloat scale = translation / self.currentLayer.fullHeight;
    
    [self handleGesture:pan withPinch:NO andScale:scale];    
}

- (void)pinchHandler:(UIPinchGestureRecognizer*)pinch
{
    if ( pinch.state == UIGestureRecognizerStateChanged && pinch.numberOfTouches < 2 )
    {
        // Cancel the pinch if the user lifts a finger and we only have a single touch
        pinch.enabled = NO;
        pinch.enabled = YES;
        return;
    }
    
    [self handleGesture:pinch withPinch:YES andScale:pinch.scale];
}

- (MHFoldingLayer*)foldingLayerWithFrame:(CGRect)frame
{
    MHFoldingLayer *foldingLayer = [MHFoldingLayer layer];
    
    foldingLayer.frame = frame; 
    foldingLayer.fullHeight = foldingLayer.frame.size.height;
    if ( foldingLayer.fullHeight == 0 )
        foldingLayer.fullHeight = kFoldingLayerHeight;
    
    foldingLayer.title = @"Massive Health";    
    foldingLayer.layerStyle = MHLayerStylePinch;
    foldingLayer.delegate = self;
    
    return foldingLayer;
}

- (UIColor*)layerColorForIndex:(int)index count:(int)count
{
    // Values derived from the Heat Map theme in Clear
    CGFloat sr = 217.0/255.0, sg = 0.0, sb = 22.0/255.0;
    CGFloat er = 234.0/255.0, eg = 175.0/255.0 , eb = 28.0/255.0;
    
    int cutoff = 7;
    CGFloat delta = 1.0 / cutoff;
    if ( count > cutoff )
        delta = 1.0 / count;
    else
        count = cutoff;
    
    CGFloat s = delta * (count - index);
    CGFloat e = delta * index;
    
    CGFloat red = sr * s + er * e;
    CGFloat green = sg * s + eg * e;
    CGFloat blue = sb * s + eb * e;
    return [UIColor colorWithRed:red green:green blue:blue alpha:1];
}

- (void)updateLayerColors
{
    for ( int i = 0; i < self.foldingLayers.count; i++ )
    {
        MHFoldingLayer *layer = [self.foldingLayers objectAtIndex:i];
        layer.color = [self layerColorForIndex:i count:self.foldingLayers.count];
    }
}

- (void)updateLayerTransitionStyles
{
    // Now that we are done, reset all of the transition styles
    for ( int layerIndex = 0; layerIndex < self.foldingLayers.count; layerIndex++ )
    {
        MHFoldingLayer *layer = [self.foldingLayers objectAtIndex:layerIndex];
        
        if ( layerIndex == 0 )
            layer.layerStyle = MHLayerStyleFoldBack;
        else if ( layerIndex == self.foldingLayers.count - 1 )
            layer.layerStyle = MHLayerStyleFoldUp;
        else 
            layer.layerStyle = MHLayerStylePinch;
    }
}

#pragma mark - CALayer Animation Delegate

- (id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
    UIPanGestureRecognizer *pan = self.scrollView.panGestureRecognizer;
    UIPinchGestureRecognizer *pinch = self.pinchRecognizer;
    
    // Set up an animation delegate when we are removing a layer so we can remove it from the
    // view hierarchy when it is done
    if ( [layer valueForKey:@"toRemove"] )
    {
        CABasicAnimation *animation = [CABasicAnimation animation]; 
        if ( [event isEqualToString:@"bounds"] )
            animation.delegate = self;
        return animation;
    }
    
    // Don't allow core animation to animate while dragging, otherwise it gets all
    // wibbly-wobbly timey-wimey and interpolates through the wrong rotated plane.
    if ( pan.state == UIGestureRecognizerStateChanged || pan.state == UIGestureRecognizerStateBegan )
        return (id)[NSNull null];
    
    if ( pinch.state == UIGestureRecognizerStateChanged || pinch.state == UIGestureRecognizerStateBegan )
        return (id)[NSNull null];
    
    return nil;
}

#pragma mark - CAAnimationDelegate

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    // Remove any sublayers marked for removal
    NSMutableArray *layersToDelete = [NSMutableArray array];
    for ( CALayer *layer in self.scrollView.layer.sublayers )
        if ( [[layer valueForKey:@"toRemove"] boolValue] )
            [layersToDelete addObject:layer];
    
    for ( CALayer *layer in layersToDelete )
        [layer removeFromSuperlayer];
}

@end

//
// Created by Sidharth Juyal on 13/05/2021.
// Copyright © 2021 ___ORGANIZATIONNAME___. All rights reserved.
// 

#import "CubeView.h"
#import <Metal/Metal.h>
#import "Renderer.h"

@implementation CubeView
{
  Renderer *_renderer;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
  self = [super initWithCoder:coder];
  if (self) {
    [self setup];
  }
  return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    [self setup];
  }
  return self;
}

- (void)setup
{
  self.device = MTLCreateSystemDefaultDevice();
  self.backgroundColor = UIColor.whiteColor;

  _renderer = [[Renderer alloc] initWithMetalKitView:self];
  [_renderer mtkView:self drawableSizeWillChange:self.bounds.size];
  self.delegate = _renderer;

  [self _randomizeColor];
}

- (void)setScrollOffset:(CGPoint)scrollOffset
{
  _renderer.contentOffset = scrollOffset.x;
}

- (void)_randomizeColor
{
  CGFloat hue = arc4random() / (CGFloat)UINT32_MAX;
  UIColor *clearColor = [UIColor colorWithHue:hue saturation:0.7 brightness:0.8 alpha:1];
  CGFloat r, g, b, a;
  [clearColor getRed:&r green:&g blue:&b alpha:&a];
  _renderer.clearColor = MTLClearColorMake(r, g, b, a);
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  [self _randomizeColor];
}

@end

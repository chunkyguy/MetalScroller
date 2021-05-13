//
// Created by Sidharth Juyal on 13/05/2021.
// Copyright © 2021 ___ORGANIZATIONNAME___. All rights reserved.
// 

#import <MetalKit/MetalKit.h>

// Our platform independent renderer class.   Implements the MTKViewDelegate protocol which
//   allows it to accept per-frame update and drawable resize callbacks.
@interface Renderer : NSObject <MTKViewDelegate>

-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;
@property (nonatomic) float contentOffset;
@property (nonatomic) MTLClearColor clearColor;
@end


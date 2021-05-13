//
// Created by Sidharth Juyal on 13/05/2021.
// Copyright © 2021 ___ORGANIZATIONNAME___. All rights reserved.
// 

#import <simd/simd.h>
#import <ModelIO/ModelIO.h>
#import "Renderer.h"
#import "ShaderTypes.h"

#define kCubeCount 3
#define kMinX -2.0
#define kMaxX 10.0

@implementation Renderer
{
  id <MTLDevice> _device;
  id <MTLCommandQueue> _commandQueue;

  id <MTLBuffer> _dynamicUniformBuffer;
  id <MTLRenderPipelineState> _pipelineState;
  id <MTLDepthStencilState> _depthState;
  id <MTLTexture> _colorMap;
  MTLVertexDescriptor *_mtlVertexDescriptor;

  matrix_float4x4 _projectionMatrix;

  float _rotation[kCubeCount];

  MTKMesh *_mesh;
}

-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;
{
  self = [super init];
  if(self)
  {
    _clearColor = MTLClearColorMake(0, 0, 0, 1);
    _contentOffset = 0;
    _device = view.device;
    [self _loadMetalWithView:view];
    [self _loadAssets];
  }

  return self;
}

- (void)_loadMetalWithView:(nonnull MTKView *)view;
{
  /// Load Metal state objects and initialize renderer dependent view properties

  view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
  view.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
  view.sampleCount = 1;

  _mtlVertexDescriptor = [[MTLVertexDescriptor alloc] init];

  _mtlVertexDescriptor.attributes[VertexAttributePosition].format = MTLVertexFormatFloat3;
  _mtlVertexDescriptor.attributes[VertexAttributePosition].offset = 0;
  _mtlVertexDescriptor.attributes[VertexAttributePosition].bufferIndex = BufferIndexMeshPositions;

  _mtlVertexDescriptor.attributes[VertexAttributeTexcoord].format = MTLVertexFormatFloat2;
  _mtlVertexDescriptor.attributes[VertexAttributeTexcoord].offset = 0;
  _mtlVertexDescriptor.attributes[VertexAttributeTexcoord].bufferIndex = BufferIndexMeshGenerics;

  _mtlVertexDescriptor.layouts[BufferIndexMeshPositions].stride = 12;
  _mtlVertexDescriptor.layouts[BufferIndexMeshPositions].stepRate = 1;
  _mtlVertexDescriptor.layouts[BufferIndexMeshPositions].stepFunction = MTLVertexStepFunctionPerVertex;

  _mtlVertexDescriptor.layouts[BufferIndexMeshGenerics].stride = 8;
  _mtlVertexDescriptor.layouts[BufferIndexMeshGenerics].stepRate = 1;
  _mtlVertexDescriptor.layouts[BufferIndexMeshGenerics].stepFunction = MTLVertexStepFunctionPerVertex;

  id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];

  id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];

  id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];

  MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
  pipelineStateDescriptor.label = @"MyPipeline";
  pipelineStateDescriptor.sampleCount = view.sampleCount;
  pipelineStateDescriptor.vertexFunction = vertexFunction;
  pipelineStateDescriptor.fragmentFunction = fragmentFunction;
  pipelineStateDescriptor.vertexDescriptor = _mtlVertexDescriptor;
  pipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;
  pipelineStateDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat;
  pipelineStateDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat;

  NSError *error = NULL;
  _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
  if (!_pipelineState)
  {
    NSLog(@"Failed to created pipeline state, error %@", error);
  }

  MTLDepthStencilDescriptor *depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
  depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
  depthStateDesc.depthWriteEnabled = YES;
  _depthState = [_device newDepthStencilStateWithDescriptor:depthStateDesc];

  _dynamicUniformBuffer = [_device newBufferWithLength:sizeof(Uniforms)
                                               options:MTLResourceStorageModeShared];

  _dynamicUniformBuffer.label = @"UniformBuffer";

  _commandQueue = [_device newCommandQueue];
}

- (void)_loadAssets
{
  /// Load assets into metal objects

  NSError *error;

  MTKMeshBufferAllocator *metalAllocator = [[MTKMeshBufferAllocator alloc]
                                            initWithDevice: _device];

  MDLMesh *mdlMesh = [MDLMesh newBoxWithDimensions:(vector_float3){2, 2, 2}
                                          segments:(vector_uint3){2, 2, 2}
                                      geometryType:MDLGeometryTypeTriangles
                                     inwardNormals:NO
                                         allocator:metalAllocator];

  MDLVertexDescriptor *mdlVertexDescriptor =
  MTKModelIOVertexDescriptorFromMetal(_mtlVertexDescriptor);

  mdlVertexDescriptor.attributes[VertexAttributePosition].name  = MDLVertexAttributePosition;
  mdlVertexDescriptor.attributes[VertexAttributeTexcoord].name  = MDLVertexAttributeTextureCoordinate;

  mdlMesh.vertexDescriptor = mdlVertexDescriptor;

  _mesh = [[MTKMesh alloc] initWithMesh:mdlMesh
                                 device:_device
                                  error:&error];

  if(!_mesh || error)
  {
    NSLog(@"Error creating MetalKit mesh %@", error.localizedDescription);
  }

  MTKTextureLoader* textureLoader = [[MTKTextureLoader alloc] initWithDevice:_device];

  NSDictionary *textureLoaderOptions =
  @{
    MTKTextureLoaderOptionTextureUsage       : @(MTLTextureUsageShaderRead),
    MTKTextureLoaderOptionTextureStorageMode : @(MTLStorageModePrivate)
  };

  _colorMap = [textureLoader newTextureWithName:@"ColorMap"
                                    scaleFactor:1.0
                                         bundle:nil
                                        options:textureLoaderOptions
                                          error:&error];

  if(!_colorMap || error)
  {
    NSLog(@"Error creating texture %@", error.localizedDescription);
  }
}

- (void)drawCubeAtIndex:(int)idx inView:(nonnull MTKView *)view
{
  /// Update any game state before encoding renderint commands to our drawable
  Uniforms * uniforms = (Uniforms*)_dynamicUniformBuffer.contents;
  uniforms->projectionMatrix = _projectionMatrix;


  float cubeOffset = (idx)/(float)(kCubeCount - 1);
  float cubeX = kMinX + cubeOffset * (kMaxX - kMinX);
  vector_float3 rotationAxis = {
    (idx == 0) ? 1 : 0,
    (idx == 1) ? 1 : 0,
    (idx == 2) ? 1 : 0
  };
  matrix_float4x4 cubeRotate = matrix4x4_rotation(_rotation[idx], rotationAxis);;
  matrix_float4x4 cubeTranslate = matrix4x4_translation(cubeX, 0.0, 0.0);

  matrix_float4x4 modelMatrix = matrix_multiply(cubeTranslate, cubeRotate);

  float viewOffset = _contentOffset/view.bounds.size.width;
  float viewX = (kMinX + viewOffset * (kMaxX - kMinX)) * -1; //
  matrix_float4x4 viewMatrix = matrix4x4_translation(viewX, 0.0, -8.0);

  uniforms->modelViewMatrix = matrix_multiply(viewMatrix, modelMatrix);

  _rotation[idx] += .01;

  id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
  commandBuffer.label = @"MyCommand";

  /// Delay getting the currentRenderPassDescriptor until absolutely needed. This avoids
  ///   holding onto the drawable and blocking the display pipeline any longer than necessary
  MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
  if (idx == 0) {
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDescriptor.colorAttachments[0].clearColor = _clearColor;
  } else {
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
  }
  renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

  /// Final pass rendering code here

  id <MTLRenderCommandEncoder> renderEncoder =
  [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
  renderEncoder.label = @"MyRenderEncoder";

  [renderEncoder pushDebugGroup:@"DrawBox"];

  [renderEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
  [renderEncoder setCullMode:MTLCullModeBack];
  [renderEncoder setRenderPipelineState:_pipelineState];
  [renderEncoder setDepthStencilState:_depthState];

  [renderEncoder setVertexBuffer:_dynamicUniformBuffer
                          offset:0
                         atIndex:BufferIndexUniforms];

  [renderEncoder setFragmentBuffer:_dynamicUniformBuffer
                            offset:0
                           atIndex:BufferIndexUniforms];

  for (NSUInteger bufferIndex = 0; bufferIndex < _mesh.vertexBuffers.count; bufferIndex++)
  {
    MTKMeshBuffer *vertexBuffer = _mesh.vertexBuffers[bufferIndex];
    if((NSNull*)vertexBuffer != [NSNull null])
    {
      [renderEncoder setVertexBuffer:vertexBuffer.buffer
                              offset:vertexBuffer.offset
                             atIndex:bufferIndex];
    }
  }

  [renderEncoder setFragmentTexture:_colorMap
                            atIndex:TextureIndexColor];

  for(MTKSubmesh *submesh in _mesh.submeshes)
  {
    [renderEncoder drawIndexedPrimitives:submesh.primitiveType
                              indexCount:submesh.indexCount
                               indexType:submesh.indexType
                             indexBuffer:submesh.indexBuffer.buffer
                       indexBufferOffset:submesh.indexBuffer.offset];
  }

  [renderEncoder popDebugGroup];

  [renderEncoder endEncoding];

  if (idx == (kCubeCount - 1)) {
    [commandBuffer presentDrawable:view.currentDrawable];
  }

  [commandBuffer commit];
  [commandBuffer waitUntilCompleted];
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
  /// Per frame updates here
  for (int idx = 0; idx < kCubeCount; ++idx) {
    [self drawCubeAtIndex:idx inView:view];
  }
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
  /// Respond to drawable size or orientation changes here

  float aspect = size.width / (float)size.height;
  _projectionMatrix = matrix_perspective_right_hand(65.0f * (M_PI / 180.0f), aspect, 0.1f, 100.0f);
}

#pragma mark Matrix Math Utilities

matrix_float4x4 matrix4x4_translation(float tx, float ty, float tz)
{
  return (matrix_float4x4) {{
    { 1,   0,  0,  0 },
    { 0,   1,  0,  0 },
    { 0,   0,  1,  0 },
    { tx, ty, tz,  1 }
  }};
}

static matrix_float4x4 matrix4x4_rotation(float radians, vector_float3 axis)
{
  axis = vector_normalize(axis);
  float ct = cosf(radians);
  float st = sinf(radians);
  float ci = 1 - ct;
  float x = axis.x, y = axis.y, z = axis.z;

  return (matrix_float4x4) {{
    { ct + x * x * ci,     y * x * ci + z * st, z * x * ci - y * st, 0},
    { x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0},
    { x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0},
    {                   0,                   0,                   0, 1}
  }};
}

matrix_float4x4 matrix_perspective_right_hand(float fovyRadians, float aspect, float nearZ, float farZ)
{
  float ys = 1 / tanf(fovyRadians * 0.5);
  float xs = ys / aspect;
  float zs = farZ / (nearZ - farZ);

  return (matrix_float4x4) {{
    { xs,   0,          0,  0 },
    {  0,  ys,          0,  0 },
    {  0,   0,         zs, -1 },
    {  0,   0, nearZ * zs,  0 }
  }};
}

@end

# MetalScroller
Metal with OpenGL

About mixing `UIScrollView` with `MTKView`. This is the trick I learned from [WWDC 2012 Enhancing User Experience with Scroll Views](https://developer.apple.com/videos/play/wwdc2012/223/) session that talks about mixing `UIScrollView` with OpenGL. The idea is to simply use the `MTKView` to render whatever metal content we would like and then use the `UIScrollView` to provide with the scrolling effect. The benefit of using `UIScrollView` is that we get exactly the same dragging and bounciness behavior that iOS users expect. 

So, for example let's say we have a `MTKView` that renders 3 cubes on screen and at any given time only of the cube is visible on screen. To prepare for scrolling we need to expose a `CGPoint scrollOffset` property that can scroll the content.

```objc
@interface CubeView : MTKView
@property (nonatomic) CGPoint scrollOffset;
@end
```

On top of it we also need to handle touch events for other things such as changing the background color at tap.

```objc
 - (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  [self _randomizeColor];
}
```

Now since in our app, we only ever scroll horizontally, we can simply forward the `x` value to the `Renderer`

```objc
- (void)setScrollOffset:(CGPoint)scrollOffset
{
  _renderer.contentOffset = scrollOffset.x;
}
```

Then in the `Renderer` we can use this `contentOffset` value to calculate the *view matrix*

```objc
matrix_float4x4 modelMatrix = ...

float viewOffset = _contentOffset/view.bounds.size.width;
float viewX = (kMinX + viewOffset * (kMaxX - kMinX)) * -1;
matrix_float4x4 viewMatrix = matrix4x4_translation(viewX, 0.0, -8.0);

uniforms->modelViewMatrix = matrix_multiply(viewMatrix, modelMatrix);
```

We need to multiply with `-1` because we need to move the content in the opposite direction of the scroll. Remember the `contentOffset` gives a increasing `+ve` value from `0` as we go towards right, while the content is actually moving left.

Next we need to actually add the `UIScrollView`. The simplest way could be to just add a `UIScrollView` on top of `CubeView` and use the `UIScrollViewDelegate` to forward the `contentOffset`.

```objc
- (void)viewDidLoad
{
  [super viewDidLoad];
  
  _cubeView = (CubeView *)self.view;

  CGRect cubeVwFrame = [_cubeView bounds];
  CGSize contentSize = CGSizeMake(CGRectGetWidth(cubeVwFrame) * 2, CGRectGetHeight(cubeVwFrame));
  UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:cubeVwFrame];
  scrollView.contentSize = contentSize;
  scrollView.showsHorizontalScrollIndicator = NO;
  scrollView.delegate = self;
  [self.view addSubview:scrollView];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  _cubeView.scrollOffset = scrollView.contentOffset;
}
```

 But remember we would like to handle the touch events on the `CubeView` for updating the background color. So this solution won't work since `UIScrollView` is going to consume all the touch events. The solution then is to not let the `UIScrollView` be part of the responder chain but still be able to use the gesture recognizers of `UIScrollView`. One way to achieve this is by using a placeholder view.

 ```objc
 - (void)viewDidLoad
{
  [super viewDidLoad];
  
  _cubeView = (CubeView *)self.view;

  CGRect cubeVwFrame = [_cubeView bounds];
  CGSize contentSize = CGSizeMake(CGRectGetWidth(cubeVwFrame) * 2, CGRectGetHeight(cubeVwFrame));
  UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:cubeVwFrame];
  scrollView.contentSize = contentSize;
  scrollView.showsHorizontalScrollIndicator = NO;
  scrollView.delegate = self;
  scrollView.hidden = YES; // remove from responder chain
  [self.view addSubview:scrollView];

  UIView *dummyView = [[UIView alloc] initWithFrame:scrollView.frame];
  [dummyView addGestureRecognizer:scrollView.panGestureRecognizer];
  [self.view addSubview:dummyView];
}
```

With this in place, the `UIScrollView` would not be part of the responder chain but still provide us with the `UIPanGestureRecognizer` and the app should behave as we expect.

![success](https://user-images.githubusercontent.com/213683/118399153-12960480-b65c-11eb-82f2-3a7bd6038738.gif)

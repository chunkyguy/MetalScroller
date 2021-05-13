//
// Created by Sidharth Juyal on 13/05/2021.
// Copyright © 2021 ___ORGANIZATIONNAME___. All rights reserved.
// 

#import "GameViewController.h"
#import "CubeView.h"

@interface GameViewController () <UIScrollViewDelegate>

@end

@implementation GameViewController
{
  CubeView *_cubeView;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  _cubeView = (CubeView *)self.view;

  CGRect cubeVwFrame = [_cubeView bounds];
  UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:cubeVwFrame];
  scrollView.contentSize = CGSizeMake(CGRectGetWidth(cubeVwFrame) * 2, CGRectGetHeight(cubeVwFrame));
  scrollView.showsHorizontalScrollIndicator = NO;
  scrollView.delegate = self;
  scrollView.hidden = YES;
  [self.view addSubview:scrollView];

  UIView *dummyView = [[UIView alloc] initWithFrame:scrollView.frame];
  [dummyView addGestureRecognizer:scrollView.panGestureRecognizer];
  [self.view addSubview:dummyView];
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  _cubeView.scrollOffset = scrollView.contentOffset;
}

@end

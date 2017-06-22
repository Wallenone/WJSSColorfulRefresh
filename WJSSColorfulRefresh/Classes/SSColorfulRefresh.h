//
//  SSColorfulRefresh.h
//  SSColorfulRefresh
//
//  Created by Mrss on 16/3/1.
//  Copyright © 2016年 expai. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol SSColorRefreshDelegate <NSObject>

@required
- (void)ssColorBeginRefreshing;

@end

@interface SSColorfulRefresh : UIControl

@property (nonatomic,weak) id<SSColorRefreshDelegate>  delegate;
//the count of color must be 6.
//clockwise.
@property (nonatomic,strong) UIActivityIndicatorView * view1;

- (instancetype)initWithScrollView:(UIScrollView *)scrollView
                            colors:(NSArray <UIColor *> *)colors;

- (void)beginRefreshing;

- (void)endRefreshing;

@end

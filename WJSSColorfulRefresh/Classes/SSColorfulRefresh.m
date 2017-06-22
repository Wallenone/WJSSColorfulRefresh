//
//  SSColorfulRefresh.m
//  SSColorfulRefresh
//
//  Created by Mrss on 16/3/1.
//  Copyright © 2016年 expai. All rights reserved.
//

#import "SSColorfulRefresh.h"


static const CGFloat kColorfulRefreshWidth = 35.0;

@interface NSTimer (SafeTimer)

+ (NSTimer *)safe_timerWithTimeInterval:(NSTimeInterval)ti
                                  block:(void(^)())block
                                repeats:(BOOL)bo;

@end


@implementation NSTimer (SafeTimer)

+ (NSTimer *)safe_timerWithTimeInterval:(NSTimeInterval)ti block:(void (^)())block repeats:(BOOL)bo {
    return [self timerWithTimeInterval:ti target:self selector:@selector(safe_timerBlock:) userInfo:[block copy] repeats:bo];
}

+ (void)safe_timerBlock:(NSTimer *)timer {
    void (^block)() = timer.userInfo;
    if (block) {
        block();
    }
}

@end

typedef NS_ENUM(NSInteger,SSColorfulItemPosition) {
    SSColorfulItemPositionRightBottom,
    SSColorfulItemPositionLeftBottom,
    SSColorfulItemPositionRightCenter,
    SSColorfulItemPositionLeftCenter,
    SSColorfulItemPositionRightTop,
    SSColorfulItemPositionLeftTop,
};

@interface SSColorfulItem : UIView

@property (nonatomic,strong) UIColor *color;
@property (nonatomic,assign,readonly) CGFloat originalCenterY;
@property (nonatomic,assign) float offYChangeSpeed;
@property (nonatomic,assign) NSInteger currentColorIndex;
@property (nonatomic,assign,readonly) SSColorfulItemPosition position;

- (instancetype)initWithCenter:(CGPoint)point originalColor:(UIColor *)color position:(SSColorfulItemPosition)position;

@end


typedef struct {
    CGFloat minBorderLen;
    CGFloat middleBorderLen;
    CGFloat maxBorderLen;
}TriangleBorder;

@implementation SSColorfulItem {
    TriangleBorder _border;
}

- (instancetype)initWithCenter:(CGPoint)point originalColor:(UIColor *)color position:(SSColorfulItemPosition)position {
    self = [super init];
    if (self) {
        self.bounds = CGRectMake(0, 0, kColorfulRefreshWidth, kColorfulRefreshWidth);
        self.center = point;
        _color = color;
        _position = position;
        _border.middleBorderLen = kColorfulRefreshWidth/2;
        _border.minBorderLen = _border.middleBorderLen*tan(M_PI/6);
        _border.maxBorderLen = 2*_border.minBorderLen;
        _originalCenterY = point.y;
        self.backgroundColor = [UIColor clearColor];
    }

    return self;
}

- (void)setColor:(UIColor *)color {
    _color = color;
    [self setNeedsDisplay];
}

@end

static const NSInteger kColorfulItemBaseTag = 10000;
static const NSTimeInterval kColorfulRefreshUpdateTimeInterval = 0.15;
static const CGFloat kColorfulRefreshTargetHeight = 65.0;
static const CGFloat kColorfulRefreshTriggerHeight = 65.0;
static NSString *const  ObservingKeyPath = @"contentOffset";

@interface SSColorfulRefresh () <UIScrollViewDelegate>

@property (nonatomic,strong) NSArray *colors;
@property (nonatomic,strong) NSArray *originalColors;
@property (nonatomic,strong) NSMutableArray *items;
@property (nonatomic,strong) NSArray *originalItems;
@property (nonatomic,strong) NSMutableArray *originalPositions;
@property (nonatomic,strong) NSArray *speeds;
@property (nonatomic,assign) UIScrollView *attachScrollView;
@property (nonatomic,strong) NSTimer *timer;
@property (nonatomic,assign) NSInteger flagCount;
@property (nonatomic,assign) BOOL refreshing;
@property (nonatomic,strong) UIActivityIndicatorView * acView;
@end

@implementation SSColorfulRefresh

- (UIActivityIndicatorView *)acView{
    
    if (!_acView) {
        _acView = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 370, 30, 30)];
        _acView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
        
        _acView.backgroundColor = [UIColor redColor];
    }
    return _acView;
}

+ (NSArray *)defaultColors {
    return @[
             [UIColor colorWithRed:230/255.0 green:155/255.0 blue:3/255.0 alpha:1],
             [UIColor colorWithRed:175/255.0 green:18/255.0 blue:88/255.0 alpha:1],
             [UIColor colorWithRed:244/255.0 green:13/255.0 blue:100/255.0 alpha:1],
             [UIColor colorWithRed:137/255.0 green:157/255.0 blue:192/255.0 alpha:1],
             [UIColor colorWithRed:179/255.0 green:197/255.0 blue:135/255.0 alpha:1],
             [UIColor colorWithRed:250/255.0 green:227/255.0 blue:113/255.0 alpha:1]
             ];
}

- (NSTimer *)timer {
    if (_timer == nil) {
        __weak SSColorfulRefresh *weakSelf = self;
        _timer = [NSTimer safe_timerWithTimeInterval:kColorfulRefreshUpdateTimeInterval block:^{
            [weakSelf updateColors];
        } repeats:YES];
        [_timer setFireDate:[NSDate distantFuture]];
    }
    return _timer;
}

- (void)startRunloop {
    NSRunLoop *loop = [NSRunLoop currentRunLoop];
    [loop addTimer:self.timer forMode:NSDefaultRunLoopMode];
    [loop run];
}

- (instancetype)initWithScrollView:(UIScrollView *)scrollView colors:(NSArray<UIColor *> *)colors {
    self = [super initWithFrame:CGRectMake(0, -400, [UIScreen mainScreen].bounds.size.width, 400)];
    if (self) {
        self.view1 = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake([UIScreen mainScreen].bounds.size.width * 0.5 - 10, 360, 20, 10)];
        [self.view1 startAnimating];
        self.view1.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        [self addSubview:self.view1];
        
        [self addSubview:self.acView];
        _attachScrollView = scrollView;
        [scrollView addSubview:self];
        [scrollView addObserver:self forKeyPath:ObservingKeyPath options:NSKeyValueObservingOptionNew context:NULL];
        if (colors && colors.count == 6) {
            _originalColors = [colors copy];
        }
        else {
            _originalColors = [[self class]defaultColors];
        }
        _originalPositions = [[NSMutableArray alloc]initWithCapacity:6];
        _items = [[NSMutableArray alloc]initWithCapacity:6];
        _colors = @[_originalColors[2],_originalColors[3],_originalColors[1],_originalColors[4],_originalColors[0],_originalColors[5]];
        [_colors enumerateObjectsUsingBlock:^(UIColor *color, NSUInteger idx, BOOL *stop) {
            SSColorfulItemPosition position = (SSColorfulItemPosition)idx;
            SSColorfulItem *item = [[SSColorfulItem alloc]initWithCenter:CGPointMake(CGRectGetWidth(self.frame)/2, 400-kColorfulRefreshTargetHeight-kColorfulRefreshWidth/2-30*idx) originalColor:color position:position];
            item.tag = idx+kColorfulItemBaseTag;
            [self addSubview:item];
            [_items addObject:item];
            [_originalPositions addObject:@(400-kColorfulRefreshTargetHeight-kColorfulRefreshWidth/2-30*idx)];
        }];
        _speeds = @[@(55.0/75.0),
                    @(85.0/80.0),
                    @(115.0/85.0),
                    @(145.0/90.0),
                    @(175.0/95.0),
                    @(205.0/100.0)];
        _originalItems = @[_items[4],_items[2],_items[0],_items[1],_items[3],_items[5]];
        //[self performSelectorInBackground:@selector(startRunloop) withObject:nil];
    }
    return self;
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    [super willMoveToSuperview:newSuperview];
    if (!newSuperview) {
        [self.attachScrollView removeObserver:self forKeyPath:ObservingKeyPath];
        self.attachScrollView = nil;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    if (![keyPath isEqualToString:ObservingKeyPath]) {
        return;
    }
    CGFloat offsetY = [change[NSKeyValueChangeNewKey]CGPointValue].y;
    if (!self.refreshing) {
    }
    else {
        if (!self.attachScrollView.dragging && self.attachScrollView.decelerating) {
            [self.attachScrollView setContentOffset:CGPointMake(0, 0) animated:YES];
        }
    }
    if (offsetY <= -kColorfulRefreshTriggerHeight) {
        if (!self.attachScrollView.dragging && self.attachScrollView.decelerating) {
            if (!self.refreshing) {
                [self beginRefreshing];
                [self.delegate ssColorBeginRefreshing];
            }
        }
    }
}

- (void)updateColors {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.originalItems enumerateObjectsUsingBlock:^(SSColorfulItem *item, NSUInteger idx, BOOL * _Nonnull stop) {
            item.color = self.originalColors[(self.flagCount+idx)%6];
        }];
        self.flagCount++;
    });
}

- (void)beginRefreshing {
    if (self.refreshing) {
        return;
    }
    self.refreshing = YES;
    [self.attachScrollView setContentOffset:CGPointMake(0, -kColorfulRefreshTargetHeight) animated:YES];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)endRefreshing {
    if (!self.refreshing) {
        return;
    }
    self.flagCount = 0;
    self.refreshing = NO;
    [UIView animateWithDuration:0.3 delay:0.5 options:UIViewAnimationOptionCurveLinear animations:^{
        self.attachScrollView.contentOffset = CGPointMake(0, 0);
    } completion:^(BOOL finished) {
        [self.attachScrollView setContentOffset:CGPointMake(0,0) animated:NO];
    }];
    
}

- (void)dealloc {
    [self.attachScrollView removeObserver:self forKeyPath:ObservingKeyPath];
    self.attachScrollView = nil;
}

-(UIColor *)getColor:(NSString*)hexColor
{
    unsigned int red,green,blue;
    NSRange range;
    range.length = 2;
    
    range.location = 0;
    [[NSScanner scannerWithString:[hexColor substringWithRange:range]]scanHexInt:&red];
    
    range.location = 2;
    [[NSScanner scannerWithString:[hexColor substringWithRange:range]]scanHexInt:&green];
    
    range.location = 4;
    [[NSScanner scannerWithString:[hexColor substringWithRange:range]]scanHexInt:&blue];
    
    return [UIColor colorWithRed:(float)(red/255.0f)green:(float)(green / 255.0f) blue:(float)(blue / 255.0f)alpha:1.0f];
}


@end

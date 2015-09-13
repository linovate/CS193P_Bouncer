//
//  ViewController.m
//  Bouncer
//
//  Created by lordofming on 7/2/15.
//  Copyright (c) 2015 lordofming. All rights reserved.
//

#import "ViewController.h"
#import <CoreMotion/CoreMotion.h>

@interface ViewController ()
@property (nonatomic,weak) UIView *redBlock;
@property (nonatomic,weak) UIView *blackBlock;
@property (nonatomic,strong)UIDynamicAnimator *animator;
@property (nonatomic,weak)UIGravityBehavior *gravity;
@property (nonatomic,weak)UICollisionBehavior *collider;
@property (nonatomic,weak)UIDynamicItemBehavior *elastic;
@property (nonatomic,strong)CMMotionManager *motionManager;

//For scores:
@property(nonatomic,weak)UILabel *scoreLabel;
@property(nonatomic)double lastScore;
@property(nonatomic)double maxScore;
@property(nonatomic)double blackBlockDistanceTraveled;
@property(nonatomic,strong)NSDate *lastRecordedBlackBlockTravelTime;
@property(nonatomic)double cumulativeBlackBlockTravelTime;
@property(nonatomic,weak) UIDynamicItemBehavior *blackBlockTracker;
@property(nonatomic,weak) UICollisionBehavior *scoreBoundary;
@property(nonatomic) CGPoint scoreBoundaryCenter;

//QuickSand for pause
@property(nonatomic,weak) UIDynamicItemBehavior *quickSand;
@end

@implementation ViewController

static CGSize blockSize={40,40};

-(UIView *)addBlockOffsetFromCenterBy: (UIOffset)offset
{
    CGPoint blockCenter=CGPointMake(CGRectGetMidX(self.view.bounds)+offset.horizontal, CGRectGetMidY(self.view.bounds)+offset.vertical);
    CGRect blockFrame=CGRectMake(blockCenter.x-blockSize.width/2, blockCenter.y-blockSize.height/2, blockSize.width, blockSize.height);
    UIView *block= [[UIView alloc] initWithFrame:blockFrame];
    [self.view addSubview:block];
    return block;
}

-(UIDynamicAnimator *)animator
{
    if (!_animator) {
        _animator=[[UIDynamicAnimator alloc] initWithReferenceView:self.view];
    }
    return _animator;
}

-(UICollisionBehavior *)collider
{
    if (!_collider) {
        UICollisionBehavior *collider=[[UICollisionBehavior alloc] init];
        collider.translatesReferenceBoundsIntoBoundary=YES;
        [self.animator addBehavior:collider];
        self.collider=collider;
    }
    return _collider;
}

-(UIGravityBehavior *)gravity
{
    if (!_gravity) {
        UIGravityBehavior *gravity=[[UIGravityBehavior alloc] init];
        [self.animator addBehavior:gravity];
        self.gravity=gravity;
    }
    return _gravity;
}

-(UIDynamicItemBehavior *)elastic
{
    if (!_elastic) {
        UIDynamicItemBehavior *elastic = [[UIDynamicItemBehavior alloc]init];
        elastic.elasticity=1.0;
        [self.animator addBehavior:elastic];
        self.elastic=elastic;
    }
    return _elastic;
}

-(UIDynamicItemBehavior *)quickSand
{
    if (!_quickSand) {
        UIDynamicItemBehavior *quickSand=[[UIDynamicItemBehavior alloc]init];
        quickSand.resistance=0;
        [self.animator addBehavior:quickSand];
        _quickSand=quickSand;
    }
    return _quickSand;
}

-(CMMotionManager *)motionManager
{
    if (!_motionManager) {
        _motionManager=[[CMMotionManager alloc]init];
        _motionManager.accelerometerUpdateInterval=0.1;
    }
    return _motionManager;
}


-(void)pauseGame
{
    [self.motionManager stopAccelerometerUpdates];
    self.gravity.gravityDirection=CGVectorMake(0, 0);
    self.quickSand.resistance=10.0;
    [self pauseScoring];
}

-(BOOL)isPaused
{
    return !self.motionManager.isAccelerometerActive;
}


-(void)resumeGame
{
    if (!self.redBlock) {
        self.redBlock=[self addBlockOffsetFromCenterBy:UIOffsetMake(-100, 0)];
        self.redBlock.backgroundColor=[UIColor redColor];
        
        [self.collider addItem:self.redBlock];
        [self.elastic addItem:self.redBlock];
        [self.gravity addItem:self.redBlock];
        [self.quickSand addItem:self.redBlock];
        
        self.blackBlock=[self addBlockOffsetFromCenterBy:UIOffsetMake(+100, 0)];
        self.blackBlock.backgroundColor=[UIColor blackColor];
        [self.collider addItem:self.blackBlock];
        [self.quickSand addItem:self.blackBlock]; 
    }
    
    self.quickSand.resistance=0.0;
    self.gravity.gravityDirection=CGVectorMake(0, 0);
    
    if (!self.motionManager.isAccelerometerActive) {
        [self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue mainQueue]
    withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
        CGFloat x=accelerometerData.acceleration.x;
        CGFloat y=accelerometerData.acceleration.y;
//CMAccelerometerData(and all CMAccelerometer related) define +Y as the UP direction in portait, which is the opposite direction of +Y for CGVectorMake () and CGGeometry-related stuff in general, that's why even for "UIInterfaceOrientationPortrait", we need to do:self.gravity.gravityDirection=CGVectorMake(x, -y); See Switch statement below.

// Paul said we can also get orientation from UIDevice, and said the most correct way is to
// use STATUS BAR orientation as it will guarantee to be always right from user's stand point.
        
        
//Paul Hegaty's version (except the UIInterfaceOrientationUnknown case, which is added by myself)
        
        
        switch (self.interfaceOrientation) {
            case UIInterfaceOrientationLandscapeRight:
                self.gravity.gravityDirection=CGVectorMake(-y, -x);
                break;
                
            case UIInterfaceOrientationLandscapeLeft:
                self.gravity.gravityDirection=CGVectorMake(y, x);
                break;
            case UIInterfaceOrientationPortrait:
                self.gravity.gravityDirection=CGVectorMake(x, -y);
                break;
            case UIInterfaceOrientationPortraitUpsideDown:
                self.gravity.gravityDirection=CGVectorMake(-x, y);
                break;
            case UIInterfaceOrientationUnknown:
                NSLog(@"UIInterface Orientation is Unknown, can't play this game 😓");
                break;
        }
        
//            switch ([UIDevice currentDevice].orientation) {
//                case UIInterfaceOrientationLandscapeRight:
//                    self.gravity.gravityDirection=CGVectorMake(-y, -x);
//                    break;
//                    
//                case UIInterfaceOrientationLandscapeLeft:
//                    self.gravity.gravityDirection=CGVectorMake(y, x);
//                    break;
//                case UIInterfaceOrientationPortrait:
//                    self.gravity.gravityDirection=CGVectorMake(x, -y);
//                    break;
//                case UIInterfaceOrientationPortraitUpsideDown:
//                    self.gravity.gravityDirection=CGVectorMake(-x, y);
//                    break;
//                case UIInterfaceOrientationUnknown:
//                    NSLog(@"UIInterface Orientation is Unknown, can't play this game 😓");
//                    break;
//                default:
//                    NSLog(@"Faceup and Facedown are not included in switch cases.");
//                    break;
//            }
        
        [self updateScore];
        }];
    }
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self resumeGame];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self pauseGame];
}

//Tap gesture to pause the game
-(void)viewDidLoad
{
    [super viewDidLoad];
    [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tap)]];
    
    [[NSNotificationCenter defaultCenter]addObserverForName:UIApplicationWillResignActiveNotification
                                                     object:nil
                                                      queue:nil
                                                 usingBlock:^(NSNotification *note) {
                                                     [self pauseGame];
                                                 }];
    [[NSNotificationCenter defaultCenter]addObserverForName:UIApplicationDidBecomeActiveNotification
                                                     object:nil
                                                      queue:nil
                                                 usingBlock:^(NSNotification *note) {
                                                     [self resumeGame];
                                                 }];
}

-(void)tap
{
    if ([self isPaused]) {
        [self resumeGame];
    }else{
        [self pauseGame];
    }
}

//Score related methods:

-(void)updateScore
{
    if (self.lastRecordedBlackBlockTravelTime) {
        self.cumulativeBlackBlockTravelTime-=[self.lastRecordedBlackBlockTravelTime timeIntervalSinceNow];
        double score=self.blackBlockDistanceTraveled/self.cumulativeBlackBlockTravelTime;
        if (score>self.maxScore) {
            self.maxScore=score;
        }
        if ((score!=self.lastScore)||![self.scoreLabel.text length]) {
            self.scoreLabel.textColor=[UIColor blackColor];
            self.scoreLabel.text=[NSString stringWithFormat:@"%.0f\n%.0f",score,self.maxScore];
            [self updateScoreBoundary];
        }else if(!CGPointEqualToPoint(self.scoreLabel.center, self.scoreBoundaryCenter)){
            [self updateScoreBoundary];
        }
    }else{
        [self.animator addBehavior:self.blackBlockTracker];
        self.scoreLabel.text=nil;
    }
    self.lastRecordedBlackBlockTravelTime=[NSDate date];
}

-(void)pauseScoring
{
    self.lastRecordedBlackBlockTravelTime=nil;
    self.scoreLabel.text=@"Paused";
    self.scoreLabel.textColor=[UIColor lightGrayColor];
    [self.animator removeBehavior:self.blackBlockTracker];
}

-(void)resetScore{
    self.blackBlockDistanceTraveled=0;
    self.lastRecordedBlackBlockTravelTime=nil;
    self.cumulativeBlackBlockTravelTime=0;
    self.maxScore=0;
    self.lastScore=0;
    self.scoreLabel.text=@"";
}

-(UILabel *)scoreLabel
{
    if (!_scoreLabel) {
        UILabel *scoreLabel= [[UILabel alloc]initWithFrame:self.view.bounds];
        scoreLabel.font=[scoreLabel.font fontWithSize:64];
        scoreLabel.textAlignment=NSTextAlignmentCenter;
        scoreLabel.numberOfLines=2;
        scoreLabel.autoresizingMask=UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
        [self.view insertSubview:scoreLabel atIndex:0];
        _scoreLabel=scoreLabel;
    }
    return _scoreLabel;
}

-(void)updateScoreBoundary
{
    CGSize scoreSize=[self.scoreLabel.text sizeWithAttributes:@{NSFontAttributeName:self.scoreLabel.font}];
    self.scoreBoundaryCenter=self.scoreLabel.center;
    CGRect scoreRect=CGRectMake(self.scoreBoundaryCenter.x-scoreSize.width/2, self.scoreBoundaryCenter.y-scoreSize.height/2, scoreSize.width, scoreSize.height);
    [self.scoreBoundary removeBoundaryWithIdentifier:@"Score"];
    [self.scoreBoundary addBoundaryWithIdentifier:@"Score"
                                          forPath:[UIBezierPath bezierPathWithRect:scoreRect]];
}

-(UICollisionBehavior *)scoreBoundary
{
    if (!_scoreBoundary) {
        UICollisionBehavior *scoreBoundary=[[UICollisionBehavior alloc] initWithItems:@[self.redBlock,self.blackBlock]];
        [self.animator addBehavior:scoreBoundary];
        _scoreBoundary=scoreBoundary;
    }
    return _scoreBoundary;
}

-(UIDynamicBehavior *)blackBlockTracker
{
    if (!_blackBlockTracker) {
        UIDynamicItemBehavior *blackBlockTracker=[[UIDynamicItemBehavior alloc]initWithItems:@[self.blackBlock]];
        [self.animator addBehavior:blackBlockTracker];
        __weak ViewController *weakSelf=self;
        __block CGPoint lastKnownBlackBlockCenter=self.blackBlock.center;
        blackBlockTracker.action=^{
            CGFloat dx=weakSelf.blackBlock.center.x-lastKnownBlackBlockCenter.x;
            CGFloat dy=weakSelf.blackBlock.center.y-lastKnownBlackBlockCenter.y;
            weakSelf.blackBlockDistanceTraveled+=sqrt(dx*dx+dy*dy);
            lastKnownBlackBlockCenter=weakSelf.blackBlock.center;
        };
        _blackBlockTracker=blackBlockTracker;
    }
    return _blackBlockTracker;
}



@end

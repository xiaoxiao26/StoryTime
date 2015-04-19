//
//  ViewController.m
//  ReactiveStorytime
//
//  Created by Alex Xiao on 3/7/15.
//  Copyright (c) 2015 Stever2Startup. All rights reserved.
//

#import "StoryViewController.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
#import <AFNetworking-RACExtensions/RACAFNetworking.h>
#import "StoryManager.h"
#import "StoryLocationManager.h"
#import "Globals.h"
#import "TargetLocation.h"
#import <MapKit/MapKit.h>

@interface StoryViewController ()

@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UILabel *timerLabel;
@property (weak, nonatomic) IBOutlet UIButton *doneButton;
@property (weak, nonatomic) IBOutlet UIButton *resetButton;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UIButton *targetBButton;
@property (weak, nonatomic) IBOutlet UIButton *targetAButton;

@property (strong, nonatomic) RACCommand *timerCommand;

@property (strong, nonatomic) RACCommand *fetchFirstStoryCommand;
@property (strong, nonatomic) RACCommand *fetchNextStoryCommand;
@property (strong, nonatomic) RACSubject *finishedRunSubject;


@end

@implementation StoryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Storytime";
    self.timerLabel.text = @"";
    self.targetAButton.titleLabel.numberOfLines = 3;
    self.targetBButton.titleLabel.numberOfLines = 3;
    [self setUpCommands];
    [self bindUI];
}

- (void)setUpCommands {
    
    RACSignal *done = [self.doneButton rac_signalForControlEvents:UIControlEventTouchUpInside];
    RACSignal *reset = [self.resetButton rac_signalForControlEvents:UIControlEventTouchUpInside];
    RACSignal *cancel = [self.cancelButton rac_signalForControlEvents:UIControlEventTouchUpInside];
    RACSignal *doneOrReset = [RACSignal merge:@[done, reset]];
    
    self.fetchFirstStoryCommand = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id _) {
        return [[[StoryLocationManager sharedManager] fetchStorySignal] takeUntil:cancel];
    }];
    [self.fetchFirstStoryCommand.executionSignals.switchToLatest subscribeNext:^(NSDictionary *result) {
        [self startNextChapterWithContents:result cancelSignal:doneOrReset];
        [self.timerCommand execute:nil];
    }];
    
    self.fetchNextStoryCommand = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(RACSignal *fetchNextStorySignal) {
        return [fetchNextStorySignal takeUntil:doneOrReset];
    }];
    
    [self.fetchNextStoryCommand.executionSignals.switchToLatest subscribeNext:^(NSDictionary *result) {
        [self startNextChapterWithContents:result cancelSignal:doneOrReset];
    }];
    
    [[RACSignal merge:@[self.fetchFirstStoryCommand.errors,self.fetchNextStoryCommand.errors]]
        subscribeNext:^(NSError *error) {
            [self showAlertWithTitle:@"Loading Story Error" message:error.localizedDescription];
    }];
    
    self.finishedRunSubject = [RACSubject subject];
    self.timerCommand = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
        return [[[self timerSignal] takeUntil:doneOrReset] takeUntil:self.finishedRunSubject];
    }];
    
    
    self.startButton.rac_command = self.fetchFirstStoryCommand;
    self.resetButton.rac_command = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
        @weakify(self)
        return [[RACObserve(self.timerCommand, executing)
                 take:1]
                doCompleted:^{
                    @strongify(self)
                    [self resetRun];
                }];
    }];
    
    [done subscribeNext:^(id x) {
        [self finishedRunEarly];
    }];
}



- (void)startNextChapterWithContents:(NSDictionary *)result cancelSignal:cancelSignal
{
    
    NSString *story = result[kStoryKey];
//    NSArray *targets = [result valueForKeyPath:kTargetKey];
//    [self.targetAButton setTitle:targets[0][@"name"] forState:UIControlStateNormal];
//    NSLog(@"%@", result);
    RACSignal *nextStorySignal = [[[RACSignal
                                    zip:@[[[StoryManager sharedManager] storySignalWithStory:story],
                                          [[StoryLocationManager sharedManager] foundLocationSignalWithJson:result]]
                                    reduce:^id(id _, RACTuple *tuple){
                                        return tuple;
                                    }]
                                    take:1]
                                    takeUntil:cancelSignal];
    
    [nextStorySignal subscribeNext:^(RACTuple *tuple) {

        RACTupleUnpack(NSNumber *last, RACSignal *fetchNextStorySignal) = tuple;
        BOOL isDestination = last.boolValue;
        if (isDestination) {
            [self finishedRun];
        } else {

            [self.fetchNextStoryCommand execute:fetchNextStorySignal];
        }
    }];
}

- (void)finishedRun
{
    [self.finishedRunSubject sendNext:nil];
}

- (void)bindUI {
    RACSignal *startButtonHidden = [RACSignal combineLatest:@[self.fetchFirstStoryCommand.executing,
                                                              self.timerCommand.executing]
                                                     reduce:^id(NSNumber *start, NSNumber *timer){
                                                         BOOL fetchingStory = start.boolValue;
                                                         BOOL timing = timer.boolValue;
                                                
                                                         return @(fetchingStory || timing);
                                                     }];
    
    RAC(self.startButton, hidden) = startButtonHidden;
    
    RAC(self.timerLabel, text) = self.timerCommand.executionSignals.switchToLatest;
    RAC(self.timerLabel, hidden) = self.timerCommand.executing.not;
    RAC(self.doneButton, hidden) = self.timerCommand.executing.not;
    RAC(self.resetButton, hidden) = self.timerCommand.executing.not;
    
    RAC(self.targetBButton, hidden) = self.timerCommand.executing.not;
    RAC(self.targetAButton, hidden) = self.timerCommand.executing.not;
    
    RAC(self.cancelButton, hidden) = self.fetchFirstStoryCommand.executing.not;
    RAC(self.activityIndicator, hidden) = self.fetchFirstStoryCommand.executing.not;
    
    [self.targetAButton rac_liftSelector:@selector(setTitle:forState:)
                             withSignals:[RACObserve([StoryLocationManager sharedManager], targetA)
                                          map:^id(TargetLocation *target) {
                                              return target.name;
                                          }],
                                         [RACSignal return:@(UIControlStateNormal)], nil];
    
    [self.targetBButton rac_liftSelector:@selector(setTitle:forState:)
                             withSignals:[RACObserve([StoryLocationManager sharedManager], targetB)
                                          map:^id(TargetLocation *target) {
                                              return target.name;
                                          }],
                                         [RACSignal return:@(UIControlStateNormal)], nil];

    RAC([UIApplication sharedApplication], networkActivityIndicatorVisible) = [RACSignal merge:@[self.fetchFirstStoryCommand.executing, self.fetchNextStoryCommand.executing]];
}

- (void)finishedRunEarly {
    
}

- (void)resetRun {
    [self.fetchFirstStoryCommand execute:nil];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [alert dismissViewControllerAnimated:YES completion:nil];
    }];
    
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (RACSignal *)timerSignal {
    NSDate *startDate = [NSDate date];
    
    RACSignal *intervalSignal = [RACSignal interval:1.0 onScheduler:[RACScheduler scheduler]];
    RACSignal *startedIntervalSignal = [intervalSignal startWith:[NSDate date]];
    RACSignal *mappedIntervalSignal = [[startedIntervalSignal map:^id(NSDate *value) {
        
        NSDateComponents *dateComponents = [[NSCalendar currentCalendar] components:NSCalendarUnitMinute|NSCalendarUnitHour|NSCalendarUnitSecond fromDate:startDate toDate:value options:NSCalendarWrapComponents];
        
        return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)dateComponents.hour, (long)dateComponents.minute, (long) dateComponents.second];
    }] deliverOnMainThread];
    
    return mappedIntervalSignal;
}



@end

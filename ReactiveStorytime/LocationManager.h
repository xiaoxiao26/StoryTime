//
//  LocationManager.h
//  ReactiveStorytime
//
//  Created by Alex Xiao on 4/16/15.
//  Copyright (c) 2015 Stever2Startup. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

@interface LocationManager : NSObject

- (RACSignal *)foundLocationSignalWithJson:(NSDictionary *)json;
+ (LocationManager*) sharedManager;
- (RACSignal *)updatedLocationSignal;
- (RACSignal *)fetchStorySignal;

@end

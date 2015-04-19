//
//  TargetLocation.h
//  ReactiveStorytime
//
//  Created by Alex Xiao on 4/18/15.
//  Copyright (c) 2015 Stever2Startup. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TargetLocation : NSObject

@property (nonatomic) double lat;
@property (nonatomic) double lng;
@property (nonatomic) NSString *name;

- (instancetype)initWithDictionary:(NSDictionary *)dict;

@end

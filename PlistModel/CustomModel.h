//
//  CustomModel.h
//  PlistModel
//
//  Created by Logan Wright on 5/1/14.
//  Copyright (c) 2014 Logan Wright. All rights reserved.
//

#import "PlistModel.h"

@interface CustomModel : PlistModel

@property (strong, nonatomic) NSString * stringPropertyKey;
@property (strong, nonatomic) NSDate * datePropertyKey;
@property (strong, nonatomic) NSArray * arrayPropertyKey;
@property (strong, nonatomic) NSDictionary * dictionaryPropertyKey;

@property int intPropertyKey;
@property BOOL boolPropertyKey;
@property float floatPropertyKey;

@end

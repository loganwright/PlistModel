//
//  CustomModel.h
//  PlistModel
//
//  Created by Logan Wright on 5/1/14.
//  Copyright (c) 2014 Logan Wright. All rights reserved.
//

#import "PlistModel.h"

@interface CustomModel : PlistModel

@property (strong, nonatomic) NSString * StringPropertyKey;
@property (strong, nonatomic) NSDate * DatePropertyKey;
@property (strong, nonatomic) NSArray * ArrayPropertyKey;
@property (strong, nonatomic) NSDictionary * DictionaryPropertyKey;

@property int IntPropertyKey;
@property BOOL BoolPropertyKey;
@property float FloatPropertyKey;

@end

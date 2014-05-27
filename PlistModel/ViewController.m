//
//  ViewController.m
//  PlistModel
//
//  Created by Logan Wright on 5/1/14.
//  Copyright (c) 2014 Logan Wright. All rights reserved.
//

/*
 Mozilla Public License
 Version 2.0
 */

#import "ViewController.h"

#import "PlistModel.h"
#import "CustomModel.h"
#import "DynamicModel.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    // Dynamically loading and saving Plist ... Will print Null 1st run
    [DynamicModel plistNamed:@"DynamicModel" inBackgroundWithBlock:^(PlistModel *plistModel) {
        DynamicModel * dynamicModel = (DynamicModel *)plistModel;
        NSLog(@"\n\n\n");
        NSLog(@"** DynamicModel.plist **");
        // Will be null on first run because the plist doesn't exist yet and we haven't set anything
        NSLog(@"DM: Name: %@", dynamicModel.name);
        NSLog(@"DM: Counter: %i", dynamicModel.counter);
        dynamicModel.name = @"Hello Worldly!";
        dynamicModel.counter++;
        NSLog(@"\n\n\n");
    }];
    
    // Loading Custom Plist From Bundle
    [CustomModel plistNamed:@"CustomModel" inBackgroundWithBlock:^(PlistModel *plistModel) {
        
        // Get our custom model from return block
        CustomModel * customModel = (CustomModel *)plistModel;
        NSLog(@"\n\n\n");
        NSLog(@"** CustomModel.plist **");
        NSLog(@"CM:StringProperty: %@", customModel.stringPropertyKey);
        NSLog(@"CM:DateProperty: %@", customModel.datePropertyKey);
        NSLog(@"CM:ArrayProperty: %@", customModel.arrayPropertyKey);
        NSLog(@"CM:DictionaryProperty: %@", customModel.dictionaryPropertyKey);
        NSLog(@"CM:IntProperty: %i", customModel.intPropertyKey);
        NSLog(@"CM:BoolProperty: %@", customModel.boolPropertyKey ? @"YES" : @"NO");
        NSLog(@"CM:FloatProperty: %f", customModel.floatPropertyKey);
        NSLog(@"\n\n\n");
        
    }];
    
    // Loading Info.plist
    [PlistModel plistNamed:@"Info" inBackgroundWithBlock:^(PlistModel *plistModel) {
        NSLog(@"\n\n\n");
        NSLog(@"** Info.plist **");
        NSLog(@"Development Region: %@", plistModel.CFBundleDevelopmentRegion);
        NSLog(@"Version: %@", plistModel.CFBundleVersion);
        NSLog(@"Application requires iPhone environment? %@", plistModel.LSRequiresIPhoneOS ? @"YES" : @"NO");
        // Etc ... (see PlistModel.h for full list)
        NSLog(@"\n\n\n\n");
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
@end


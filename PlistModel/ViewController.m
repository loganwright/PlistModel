//
//  ViewController.m
//  PlistModel
//
//  Created by Logan Wright on 5/1/14.
//  Copyright (c) 2014 Logan Wright. All rights reserved.
//

#import "ViewController.h"

#import "PlistModel.h"
#import "CustomModel.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    // Standard Info.Plist Model
    [PlistModel plistNamed:@"Info" inBackgroundWithBlock:^(PlistModel *plistModel) {
        
        NSLog(@"Printing: Info \n\n");
        NSLog(@"Development Region: %@", plistModel.CFBundleDevelopmentRegion);
        NSLog(@"Version: %@", plistModel.CFBundleVersion);
        NSLog(@"Application requires iPhone environment? %@", plistModel.LSRequiresIPhoneOS ? @"YES" : @"NO");
        // Etc ...
        NSLog(@"\n");
        
    }];
    
    // Custom Subclassed Model With Plist File Included In Xcode Project
    [CustomModel plistNamed:@"CustomModel" inBackgroundWithBlock:^(PlistModel *plistModel) {
        
        NSLog(@"Printing: PlistIncluded - CustomModel \n\n");
        CustomModel * customModel = (CustomModel *)plistModel;
        NSLog(@"PlistIncluded - StringProperty: %@", customModel.StringPropertyKey);
        NSLog(@"PlistIncluded - DateProperty: %@", customModel.DatePropertyKey);
        NSLog(@"PlistIncluded - ArrayProperty: %@", customModel.ArrayPropertyKey);
        NSLog(@"PlistIncluded - DictionaryProperty: %@", customModel.DictionaryPropertyKey);
        NSLog(@"PlistIncluded - IntProperty: %i", customModel.IntPropertyKey);
        NSLog(@"PlistIncluded - BoolProperty: %@", customModel.BoolPropertyKey ? @"YES" : @"NO");
        NSLog(@"PlistIncluded - FloatProperty: %f", customModel.FloatPropertyKey);
        NSLog(@"\n");
        
    }];
    
    // Custom Subclassed Model With Plist Created Dynamically
    [CustomModel plistNamed:@"DynamicallyCreatedList" inBackgroundWithBlock:^(PlistModel *plistModel) {
        
        NSLog(@"Printing: Dynamic - CustomModel (1st run will be nil because it hasn't been created yet) \n\n");
        CustomModel * customModel = (CustomModel *)plistModel;
        NSLog(@"Dynamic - StringProperty: %@", customModel.StringPropertyKey);
        NSLog(@"Dynamic - DateProperty: %@", customModel.DatePropertyKey);
        NSLog(@"Dynamic - ArrayProperty: %@", customModel.ArrayPropertyKey);
        NSLog(@"Dynamic - DictionaryProperty: %@", customModel.DictionaryPropertyKey);
        NSLog(@"Dynamic - IntProperty: %i", customModel.IntPropertyKey);
        NSLog(@"Dynamic - BoolProperty: %@", customModel.BoolPropertyKey ? @"YES" : @"NO");
        NSLog(@"Dynamic - FloatProperty: %f", customModel.FloatPropertyKey);
        NSLog(@"\n");
        
        // Set our values
        customModel.StringPropertyKey = @"Hello World!";
        customModel.DatePropertyKey = [NSDate date];
        customModel.ArrayPropertyKey = @[@"Object1", @"Object2"];
        customModel.DictionaryPropertyKey = @{@"Key1": @"Value1", @"Key2": @"Value2"};
        customModel.IntPropertyKey = 7654321;
        customModel.BoolPropertyKey = YES;
        customModel.FloatPropertyKey = 636.859497;
        
    }];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

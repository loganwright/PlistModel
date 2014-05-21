PlistModel
==========

A Class For Easily Interacting With Plists as Objects via Automatically Set Properties

#Getting Started

##Set Up - CUSTOM PLIST IN BUNDLE

###Step 1: Set up your Plist

In `CustomModel.plist`

<p align="center">
  <img src="https://raw.githubusercontent.com/LoganWright/PlistModel/master/PlistModel/Images/PlistExample.png"><img />
</p>

###Step 2: Add Corresponding Properties to Subclass

In `CustomModel.h`

```ObjC
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
```

The logic that connects Plist keys to properties is case insensitive. Do not duplicate keys in your Plist or this may cause errors.

###Step 3: Load and Use Plist

```ObjC
[CustomModel plistNamed:@"CustomModel" inBackgroundWithBlock:^(PlistModel *plistModel) {
        
    // Get our custom model from return block
    CustomModel * customModel = (CustomModel *)plistModel;
        
    NSLog(@"\n");
    NSLog(@"** CustomModel.plist **");
    NSLog(@"CM:StringProperty: %@", customModel.stringPropertyKey);
    NSLog(@"CM:DateProperty: %@", customModel.datePropertyKey);
    NSLog(@"CM:ArrayProperty: %@", customModel.arrayPropertyKey);
    NSLog(@"CM:DictionaryProperty: %@", customModel.dictionaryPropertyKey);
    NSLog(@"CM:IntProperty: %i", customModel.intPropertyKey);
    NSLog(@"CM:BoolProperty: %@", customModel.boolPropertyKey ? @"YES" : @"NO");
    NSLog(@"CM:FloatProperty: %f", customModel.floatPropertyKey);
    NSLog(@"\n");
    
}];
```

The properties are automatically populated at runtime without any additional code.  Running in background is optional, but loading files from the directory can sometimes be an expensive operation.  Background methods are suggested.

##Set Up - PLIST CREATED DYNAMICALLY - **MUTABLE**

###Step 1: Declare properties you'd like to use in .h

In `DynamicModel.h`

```ObjC
#import "PlistModel.h"

@interface DynamicModel : PlistModel

@property (strong, nonatomic) NSString *name;
@property int counter;

@end

```

###Step 2: Interact with your Plist:

```ObjC
[DynamicModel plistNamed:@"DynamicModel" inBackgroundWithBlock:^(PlistModel *plistModel) {
    DynamicModel * dynamicModel = (DynamicModel *)plistModel;
    // Will be null on first run
    NSLog(@"DynamicModel.name = %@", dynamicModel.name);
    NSLog(@"Counter: %i", dynamicModel.counter);
    dynamicModel.name = @"Hello World!";
    dynamicModel.counter++;
    NSLog(@"DynamicModel: %@", dynamicModel);  
}];
```

If no Plist already exists at the specified name, a new one will be created automatically.  PlistModel will save in the background automatically on `dealloc` or you can call save explicitly using `saveInBackgroundWithBlock`.  

##Set Up: INTERACTING WITH THE INFO.PLIST

###Step 1: Call PlistModel w/o Subclassing

```ObjC
[PlistModel plistNamed:@"Info" inBackgroundWithBlock:^(PlistModel *plistModel) {
    NSLog(@"\n\n\n");
    NSLog(@"** Info.plist **");
    NSLog(@"Development Region: %@", plistModel.CFBundleDevelopmentRegion);
    NSLog(@"Version: %@", plistModel.CFBundleVersion);
    NSLog(@"Application requires iPhone environment? %@", plistModel.LSRequiresIPhoneOS ? @"YES" : @"NO");
    // Etc ... (see PlistModel.h for full list)
    NSLog(@"\n\n\n\n");
}];
```

You can find more available properties in `PlistModel.h`

#PlistModel with Dynamic Keys

You can also interact with PlistModel as if it is a mutableDictionary for keys that you might not know ahead of time and thus can't set as properties.  For these situations, you can use:

```ObjC
instanceOfPlistModel[@"dynamicKey"] = @"dynamicValue";
```

###NOTE:
Do NOT interact w/ matching keys and properties interchangeably or you may get unpredictable results.  For example, don't do:

```ObjC
***** BAD CODE -- DO NOT IMPLEMENT! *****
instanceOfPlistModel.dynamicKey = @"dynamicValue";
NSString * dynamicValue = instanceOfPlistModel[@"dynamicKey"];
```

In the above example `dynamicValue` may not be equal to the value set.  

This only applies to MATCHING keys and properties, using the two types of interaction for non-matching keys is acceptable.  For example, the following code would be ok:

```ObjC
// OK to use :)
instanceOfPlistModel.someProperty = @"someValue";
instanceOfPlistModel[@"anotherProperty"] = @"anotherValue";
```








PlistModel
==========

A Class For Easily Interacting With Plists as Objects via Automatically Set Properties

#Quick Set Up - PLIST IN BUNDLE

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

#Quick Set Up - PLIST CREATED DYNAMICALLY

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


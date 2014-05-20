//
//  PlistModel.m
//  ShakeLog
//
//  Created by Logan Wright on 4/29/14.
//  Copyright (c) 2014 Logan Wright. All rights reserved.
//

#import "PlistModel.h"
#import <objc/runtime.h>

@interface PlistModel ()

@property (strong, nonatomic) NSMutableDictionary * realDictionary;
@property (strong, nonatomic) NSString * plistName;

// INJECTION
@property (strong, nonatomic) NSMutableSet * observingKeyPaths;
@property BOOL isDealloc;

// BundledPlists are immutable
@property BOOL isBundledPlist;

@end

@implementation PlistModel

#pragma mark INITIALIZERS

+ (instancetype) plistNamed:(NSString *)plistName {
    return [[self alloc]initWithPlistName:plistName];
}

+ (void) plistNamed:(NSString *)plistName inBackgroundWithBlock:(void(^)(PlistModel * plistModel))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        
        PlistModel * newModel = [[self alloc]initWithPlistName:plistName];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            completion(newModel);
        });
        
    });
}

- (instancetype)init {
    self = [super init];
    if (self) {
        
        // See if init was called properly, if not, we'll default to a plist with the class name
        if (!_plistName) {
            
            // If no plist is named, set it to class name:
            _plistName = NSStringFromClass(self.class);
            
            if ([_plistName isEqual:@"PlistModel"]) {
                // If Class is plistModel, then is not subclassed.  Set to "Info"
                _plistName = @"Info";
            }
            
        }
        
        // To make sure everything is set properly
        self = [self initWithPlistName:_plistName];
        
    }
    return self;
}

- (instancetype) initWithPlistName:(NSString *)plistName {
    self = [super init];
    if (self) {
        
        // Establish out plistName
        _plistName = plistName;
        
        // Step 1: Fetch PLIST & set to our backing dictionary
        _realDictionary = [NSMutableDictionary dictionaryWithDictionary:[self getPlist]];
        
        // Step 2: Find properties that exist in plist
        NSMutableSet * propertiesInPlist = [NSMutableSet setWithArray:[self getPropertyNames]];
        NSSet * allKeys = [NSSet setWithArray:_realDictionary.allKeys];
        // INJECTION BEGIN
        /*
         It's possible that not all properties exist as keys or vice versa.  We need to KVO all possible changes to account for interactions between the dictionary and property entities in a PlistModel
         */
        
        /*
         We will only observe _realDictionary because all properties are eventually updated in the dictionary.  In this way we can always know if there is a change.  We must add KVO observers in `setObject` and remove observers in `removeObject`
         */
        _observingKeyPaths = [NSMutableSet setWithSet:allKeys];
        [_observingKeyPaths enumerateObjectsUsingBlock:^(NSString * keyPath, BOOL *stop) {
            NSLog(@"Observing: %@", keyPath);
            [_realDictionary addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
        }];
        // INJECTION END
        [propertiesInPlist intersectSet:allKeys];
        
        
        // Step 3: Set properties to values from plist
        [propertiesInPlist enumerateObjectsUsingBlock:^(NSString * propertyName, BOOL *stop) {
            
            [self setPropertyFromDictionaryValueWithName:propertyName];
            
        }];
    }
    return self;
}

#pragma mark GET OUR PLIST

- (NSMutableDictionary *) getPlist {
    
    // Check to see if there's a Plist included in the main bundle
    NSString *path = [[NSBundle mainBundle] pathForResource:_plistName ofType: @"plist"];
    
    if (path) {
        _isBundledPlist = YES;
    }
    else {
        
        // There isn't already a plist, make one
        NSString * appendedPlistName = [NSString stringWithFormat:@"%@.plist", _plistName];
        
        // Fetch out plist & set to new path
        NSArray *pathArray = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [pathArray objectAtIndex:0];
        path = [documentsDirectory stringByAppendingPathComponent:appendedPlistName];
        
    }
    
    // If it doesn't exist, create it
    NSMutableDictionary * plist = [[NSMutableDictionary alloc]initWithContentsOfFile:path];
    
    // Return
    return plist;
    
}

#pragma mark GET OUR PROPERTY NAMES

- (NSMutableArray *) getPropertyNames {
    
    // Prepare Package
    NSMutableArray * propertyNames = [NSMutableArray array];
    
    // Fetch Properties
    unsigned count;
    objc_property_t *properties = class_copyPropertyList([self class], &count);
    
    // Parse Out Properties
    for (int i = 0; i < count; i++) {
        objc_property_t property = properties[i];
        const char * name = property_getName(property);
        // NSLog(@"Name: %s", name);
        // INJECTION
        NSString *stringName = [NSString stringWithUTF8String:name];
        NSLog(@"EvalSTring: %@", stringName);
        if ([@[@"realDictionary", @"plistName", @"observingKeyPaths", @"isDirty", @"isDealloc", @"isBundledPlist"]containsObject:stringName]) {
            // Block these properties
            continue;
        }
        /* Removing in updated version
         if ([stringName isEqualToString:@"realDictionary"] || [stringName isEqualToString:@"plistName"] || [stringName isEqualToString:@"observingKeyPaths"] || [stringName isEqualToString:@"isDirty"] || [stringName isEqualToString:@"isDealloc"]) {
         NSLog(@"IS EQUAL TO PROPERTY LIST %@", stringName);
         // Block these properties
         continue;
         }*/
        const char * attributes = property_getAttributes(property);
        // NSLog(@"Attributes: %s", attributes);
        NSString * attributeString = [NSString stringWithUTF8String:attributes];
        NSArray * attributesArray = [attributeString componentsSeparatedByString:@","];
        if ([attributesArray containsObject:@"R"]) {
            // is ReadOnly
            NSLog(@"Properties can NOT be readonly to work properly.  %s will not be set", name);
        }
        else {
            // Add to our array
            [propertyNames addObject:[NSString stringWithUTF8String:name]];
        }
    }
    
    // Free our properties
    free(properties);
    
    // Send it off
    return propertyNames;
}

#pragma mark DEALLOC & SAVE - OK?

- (void) dealloc {
    
    // INJECTION END
    
    NSLog(@"About to save: %@", self);
    // Save
    // Set to YES on dealloc so we can remove all KVO observers
    _isDealloc = YES;
    
    
    if (!_isBundledPlist) {
        [self saveInBackgroundWithCompletion:nil];
    }
    
}

- (void) saveInBackgroundWithCompletion:(void(^)(void))completion {
    /*
     // So we don't have to check it every time
     BOOL isInfo = [_plistName isEqualToString:@"Info"];
     
     // Set our properties to the dictionary before we write it
     for (NSString * propertyName in [self getPropertyNames]) {
     
     // INJECTION
     // Block our instance properties from setting to plist
     // Possibly unneccessary since they are blocked in `getPropertyNames`
     if ([propertyName isEqualToString:@"realDictionary"] || [propertyName isEqualToString:@"plistName"] || [propertyName isEqualToString:@"observingKeyPaths"] || [propertyName isEqualToString:@"isDirty"]) {
     // Block these properties
     continue;
     }
     
     // Check if we're using an Info.plist model
     if (!isInfo) {
     // If not Info.plist, don't set this variable.  The other properties won't be set, but because it's a BOOL, it will set a default 0;
     if ([propertyName isEqualToString:@"LSRequiresIPhoneOS"]) {
     continue;
     }
     }
     
     // Make sure our dictionary is set to show any updated properties
     [self setDictionaryValueFromPropertyWithName:propertyName];
     }
     */
    // INJECTION BEGIN
    
    // remove all observers
    
    //[_observingKeyPaths enumerateObjectsUsingBlock:^(NSString * keyPath, BOOL *stop) {
    //  [_realDictionary removeObserver:self forKeyPath:keyPath];
    //}];
    
    // So we don't have to check it every time
    BOOL isInfo = [_plistName isEqualToString:@"Info"];
    
    // Set our properties to the dictionary before we write it
    for (NSString * propertyName in [self getPropertyNames]) {
        
        // INJECTION
        // Block our instance properties from setting to plist
        // Possibly unneccessary since they are blocked in `getPropertyNames`
        if ([propertyName isEqualToString:@"realDictionary"] || [propertyName isEqualToString:@"plistName"] || [propertyName isEqualToString:@"observingKeyPaths"] || [propertyName isEqualToString:@"isDirty"] || [propertyName isEqualToString:@"isDealloc"]) {
            // Block these properties
            continue;
        }
        
        // Check if we're using an Info.plist model
        if (!isInfo) {
            // If not Info.plist, don't set this variable.  The other properties won't be set, but because it's a BOOL, it will set a default 0;
            if ([propertyName isEqualToString:@"LSRequiresIPhoneOS"]) {
                continue;
            }
        }
        
        // Make sure our dictionary is set to show any updated properties
        [self setDictionaryValueFromPropertyWithName:propertyName];
    }
    
    // INJECTION BEGIN
    
    // remove all observers if deallocating, otherwise, keep observing!
    if (_isDealloc) {
        [_observingKeyPaths enumerateObjectsUsingBlock:^(NSString * keyPath, BOOL *stop) {
            [_realDictionary removeObserver:self forKeyPath:keyPath];
        }];
    }
    
    // INJECTION END
    
    // INJECTION MODIFICATION BEGIN
    
    if (_isDirty) {
        NSLog(@"IS DIRTY");
        
        // Set our block variables
        // __block NSString * nameToSave = _plistName;
        // __block NSDictionary * dictToSave = _realDictionary;
        // __block BOOL blockDirty = _isDirty;
        
        __weak typeof(self) weakSelf = self;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            
            __strong typeof(weakSelf) strongSelf = weakSelf;
            
            NSString *path = [[NSBundle mainBundle] pathForResource:strongSelf.plistName ofType: @"plist"];
            if (!path) {
                
                // There isn't already a plist, make one
                NSString * plistName = [NSString stringWithFormat:@"%@.plist", strongSelf.plistName];
                
                // Fetch out plist
                NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                NSString *documentsDirectory = [paths objectAtIndex:0];
                path = [documentsDirectory stringByAppendingPathComponent:plistName];
            }
            
            // Write it to file
            [strongSelf.realDictionary writeToFile:path atomically:YES];
            
            // INJECTION BEGIN
            // _isDirty = NO;
            // INJECTION END
            
            // Run completion
            strongSelf.isDirty = NO;
            
            // Run completion
            if (completion) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    completion();
                });
            }
            
        });
    }
    else {
        NSLog(@"IS CLEAN");
    }
    
    // INJECTION MODIFICATION END
}

#pragma mark SELECTOR ARGUMENT / RETURN TYPE METHODS

- (const char *) returnTypeOfSelector:(SEL)selector {
    NSMethodSignature * sig = [self methodSignatureForSelector:selector];
    return [sig methodReturnType];
}

- (const char *) typeOfArgumentForSelector:(SEL)selector atIndex:(int)index {
    NSMethodSignature * sig = [self methodSignatureForSelector:selector];
    // Index 0 is object, Index 1 is the selector: arguments start at Index 2
    const char * argType = [sig getArgumentTypeAtIndex:index];
    return argType;
}

#pragma mark SELECTORS AND PROPERTIES STUFF

- (SEL) setterSelectorForPropertyName:(NSString *)propertyName {
    
    /*
     Because apple automatically generates setters to "setPropertyName:", we can use that and return the first argument to get the type of property it is.  That way, we can set it to our plist values.  Custom setters will cause problems.
     */
    
    // Make our first letter capitalized -  Using this because `capitalizedString` causes issues with camelCase => Camelcase
    NSString * capitalizedPropertyName = [propertyName stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[propertyName substringToIndex:1] capitalizedString]];
    
    // The name of our auto synthesized setter | Custom setters will cause issues
    NSString * methodString = [NSString stringWithFormat:@"set%@:", capitalizedPropertyName];
    
    // Set our Selector
    SEL propertySetterSelector = NSSelectorFromString(methodString);
    
    // Return it
    return propertySetterSelector;
}

- (SEL) getterSelectorForPropertyName:(NSString *)propertyName {
    
    // AutoSynthesized Getters are just the property name
    return NSSelectorFromString(propertyName);
}

#pragma mark SYNCHRONYZING DICTIONARY AND PROPERTIES

- (void) setDictionaryValueFromPropertyWithName:(NSString *)propertyName {
    
    SEL propertyGetterSelector = [self getterSelectorForPropertyName:propertyName];
    
    const char * returnType = [self returnTypeOfSelector:propertyGetterSelector];
    
    if ([self respondsToSelector:propertyGetterSelector]) {
        
        // Get object from our dictionary
        // strcmp(str1, str2)
        // 0 if same
        // A value greater than zero indicates that the first character that does not match has a greater value in str1 than in str2;
        // And a value less than zero indicates the opposite.
        
        // Set our implementation
        IMP imp = [self methodForSelector:propertyGetterSelector];
        
        // Set to property
        if (strcmp(returnType, @encode(id)) == 0) {
            //NSLog(@"Is Object");
            id (*func)(id, SEL) = (void *)imp;
            id object = func(self, propertyGetterSelector);
            if (object) {
                _realDictionary[propertyName] = object;
            }
            else {
                [_realDictionary removeObjectForKey:propertyName];
            }
        }
        else if (strcmp(returnType, @encode(BOOL)) == 0) {
            //NSLog(@"Is Bool");
            BOOL (*func)(id, SEL) = (void *)imp;
            _realDictionary[propertyName] = @(func(self, propertyGetterSelector));
        }
        else if (strcmp(returnType, @encode(int)) == 0) {
            //NSLog(@"Is Int");
            int (*func)(id, SEL) = (void *)imp;
            _realDictionary[propertyName] = @(func(self, propertyGetterSelector));
        }
        else if (strcmp(returnType, @encode(float)) == 0) {
            //NSLog(@"Is Float");
            float (*func)(id, SEL) = (void *)imp;
            _realDictionary[propertyName] = @(func(self, propertyGetterSelector));
        }
        else if (strcmp(returnType, @encode(double)) == 0) {
            //NSLog(@"Is Double");
            double (*func)(id, SEL) = (void *)imp;
            _realDictionary[propertyName] = @(func(self, propertyGetterSelector));
        }
    }
}

- (void) setPropertyFromDictionaryValueWithName:(NSString *)propertyName {
    
    
    // Get our setter from our string
    SEL propertySetterSelector = [self setterSelectorForPropertyName:propertyName];
    
    // Make sure it exists as a property
    if ([self respondsToSelector:propertySetterSelector]) {
        
        
        if (_realDictionary[propertyName]) {
            
            // Index 0 is object, Index 1 is the selector: arguments start at Index 2
            const char * typeOfProperty = [self typeOfArgumentForSelector:propertySetterSelector atIndex:2];
            
            // Get object from our dictionary
            id objectFromDictionaryForProperty = _realDictionary[propertyName];
            
            // strcmp(str1, str2)
            // 0 if same
            // A value greater than zero indicates that the first character that does not match has a greater value in str1 than in str2;
            // And a value less than zero indicates the opposite.
            
            // Set our implementation
            IMP imp = [self methodForSelector:propertySetterSelector];
            
            // Set PlistValue to property
            if (strcmp(typeOfProperty, @encode(id)) == 0) {
                //NSLog(@"Is Object");
                void (*func)(id, SEL, id) = (void *)imp;
                func(self, propertySetterSelector, objectFromDictionaryForProperty);
            }
            else if (strcmp(typeOfProperty, @encode(BOOL)) == 0) {
                //NSLog(@"Is Bool");
                void (*func)(id, SEL, BOOL) = (void *)imp;
                func(self, propertySetterSelector, [objectFromDictionaryForProperty boolValue]);
            }
            else if (strcmp(typeOfProperty, @encode(int)) == 0) {
                //NSLog(@"Is Int");
                void (*func)(id, SEL, int) = (void *)imp;
                func(self, propertySetterSelector, [objectFromDictionaryForProperty intValue]);
            }
            else if (strcmp(typeOfProperty, @encode(float)) == 0) {
                //NSLog(@"Is Float");
                void (*func)(id, SEL, float) = (void *)imp;
                func(self, propertySetterSelector, [objectFromDictionaryForProperty floatValue]);
            }
            else if (strcmp(typeOfProperty, @encode(double)) == 0) {
                //NSLog(@"Is Double");
                void (*func)(id, SEL, double) = (void *)imp;
                func(self, propertySetterSelector, [objectFromDictionaryForProperty doubleValue]);
            }
            
        }
        else {
            
            // Index 0 is object, Index 1 is the selector: arguments start at Index 2
            const char * typeOfProperty = [self typeOfArgumentForSelector:propertySetterSelector atIndex:2];
            
            // strcmp(str1, str2)
            // 0 if same
            // A value greater than zero indicates that the first character that does not match has a greater value in str1 than in str2;
            // And a value less than zero indicates the opposite.
            
            // Set our implementation
            IMP imp = [self methodForSelector:propertySetterSelector];
            
            // Set PlistValue to property
            if (strcmp(typeOfProperty, @encode(id)) == 0) {
                //NSLog(@"Is Object");
                void (*func)(id, SEL, id) = (void *)imp;
                func(self, propertySetterSelector, [NSNull new]);
            }
            else if (strcmp(typeOfProperty, @encode(BOOL)) == 0) {
                //NSLog(@"Is Bool");
                void (*func)(id, SEL, BOOL) = (void *)imp;
                func(self, propertySetterSelector, NO);
            }
            else if (strcmp(typeOfProperty, @encode(int)) == 0) {
                //NSLog(@"Is Int");
                void (*func)(id, SEL, int) = (void *)imp;
                func(self, propertySetterSelector, 0);
            }
            else if (strcmp(typeOfProperty, @encode(float)) == 0) {
                //NSLog(@"Is Float");
                void (*func)(id, SEL, float) = (void *)imp;
                func(self, propertySetterSelector, 0);
            }
            else if (strcmp(typeOfProperty, @encode(double)) == 0) {
                //NSLog(@"Is Double");
                void (*func)(id, SEL, double) = (void *)imp;
                func(self, propertySetterSelector, 0);
            }
        }
        
    }
    
}

#pragma mark NSMutableDictionary Subclass OverRides -- NECESSARY!

- (void) setObject:(id)anObject forKey:(id<NSCopying>)aKey {
    
    if ([[(id)aKey class]isSubclassOfClass:[NSString class]]) {
        
        // INJECTION BEGIN
        // We must observe this key if we aren't already! Before we set it, so KVO triggers
        if ([_observingKeyPaths containsObject:aKey]) {
            NSLog(@"Already observing! %@", aKey);
        }
        else {
            NSLog(@"Not yet observing! %@", aKey);
            [_observingKeyPaths addObject:aKey];
            [_realDictionary addObserver:self forKeyPath:(NSString *)aKey options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
        }
        // INJECTION END
        
        // Set the object to our background dictionary
        _realDictionary[aKey] = anObject;
        
        
        // Update our property -- Just to keep everything synced
        [self setPropertyFromDictionaryValueWithName:(NSString *)aKey];
    }
    else {
        NSLog(@"Error - Unable to add Object: Plist Model can only take strings as keys");
    }
    
}

- (void) removeObjectForKey:(id)aKey {
    
    if ([[(id)aKey class]isSubclassOfClass:[NSString class]]) {
        
        // Remove object from background dictionary
        [_realDictionary removeObjectForKey:aKey];
        
        // INJECTION BEGIN
        // We must stop observing this key! ... or do we?
        /*
         If it is observing a keypath, so be it, just leave it open and close them all in dealloc
         */
        /*
         NSLog(@"Checking: %@", aKey);
         if ([_observingKeyPaths containsObject:aKey]) {
         NSLog(@"Already observing!");
         }
         else {
         NSLog(@"Not yet observing!");
         [_observingKeyPaths addObject:aKey];
         [_realDictionary addObserver:self forKeyPath:(NSString *)aKey options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
         }*/
        // INJECTION END
        
        // Update our property -- Just to keep everything synced
        [self setPropertyFromDictionaryValueWithName:(NSString *)aKey];
    }
    else {
        NSLog(@"Error - Unable to remove Object: Plist Model can only take strings as keys");
    }
}

- (NSUInteger) count {
    return _realDictionary.count;
}

- (id)objectForKey:(id)aKey {
    return _realDictionary[aKey];
}

- (NSEnumerator *)keyEnumerator {
    return [_realDictionary keyEnumerator];
}

#pragma mark KVO OBSERVING

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSLog(@"KeyPath: %@\n Change: %@", keyPath, change);
    
    if (![change[@"new"]isEqual:change[@"old"]]) {
        NSLog(@"NEW VALUE");
        _isDirty = YES;
    }
    else {
        NSLog(@"UNCHANGED VALUE");
    }
}
@end

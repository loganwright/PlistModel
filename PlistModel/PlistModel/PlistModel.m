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
@property (strong, nonatomic) NSMutableSet * observingKeyPaths;

@property BOOL isBundledPlist;
/*
To allow properties to align to the dictionary case insensitive, we will store property names with their corresponding keys in the plist dictionary 'realDictionary'

 Key   : actualPropertyName
 Value : ActualPropertyNameAsItAppearsInDictionary

 */
@property (strong, nonatomic) NSMutableDictionary * propertyKeys;

@property (strong, nonatomic) NSString * plistPath;

@end

@implementation PlistModel

@synthesize isDirty = _isDirty;

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
        
        /*
         MUST BE EXECUTED IN THIS ORDER!
         */
        
        // Step 1: Establish out plistName
        _plistName = plistName;
        
        // Step 2: Set our Path
        [self configurePath];
        
        // Step 3: Set our properties as Keys in _propertyKeys
        [self configurePropertyKeys];
        
        // Step 4: Fetch PLIST & set to our backing dictionary
        [self configureRealDictionary];
        
        // Step 5: Set Properties from PlistDictionary (_realDictionary) & populate corresponding dictionaryKeys with their property in _propertyKeys
        [self populateProperties];
        // Step 5: Start observing
        
        /*
         We will only observe _realDictionary because all properties are eventually updated in the dictionary.  In this way we can always know if there is a core change before saving.  We must add KVO observers in `setObject` to assure interaction w/ keys is not overlooked
         */
        // getPlist(above) will set _isBundledPlist property, should be set at this point
        if (!_isBundledPlist) {
            NSLog(@"Observing!");
            _observingKeyPaths = [NSMutableSet setWithArray:_realDictionary.allKeys];
            [_observingKeyPaths enumerateObjectsUsingBlock:^(NSString * keyPath, BOOL *stop) {
                [_realDictionary addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
            }];
        }
        
        /*
        // Step 6: Set properties to values from plist
        [propertiesInPlist enumerateObjectsUsingBlock:^(NSString * propertyName, BOOL *stop) {
            
            [self setPropertyFromDictionaryValueWithName:propertyName];
            
        }];
         */
    }
    return self;
}

#pragma mark INIT HELPERS

- (void) configurePath {
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
    _plistPath = path;
}

- (void) configurePropertyKeys {
    _propertyKeys = [NSMutableDictionary dictionary];
    
    // Fetch Properties
    unsigned count;
    objc_property_t *properties = class_copyPropertyList([self class], &count);
    
    // Set the properties to not be included in dictionary
    NSArray * propertyNamesToBlock = @[@"realDictionary",
                                       @"plistName",
                                       @"observingKeyPaths",
                                       @"isDirty",
                                       @"isBundledPlist",
                                       @"propertyKeys",
                                       @"plistPath"];
    
    // Parse Out Properties
    for (int i = 0; i < count; i++) {
        objc_property_t property = properties[i];
        const char * name = property_getName(property);
        // NSLog(@"Name: %s", name);
        NSString *stringName = [NSString stringWithUTF8String:name];
        
        // Ignore these properties
        if ([propertyNamesToBlock containsObject:stringName]) {
            // Block these properties
            continue;
        }
        
        // Check if READONLY
        const char * attributes = property_getAttributes(property);
        NSString * attributeString = [NSString stringWithUTF8String:attributes];
        NSArray * attributesArray = [attributeString componentsSeparatedByString:@","];
        if ([attributesArray containsObject:@"R"]) {
            // is ReadOnly
            NSLog(@"Properties can NOT be readonly to work properly.  %s will not be set", name);
        }
        else {
            NSString * propertyName = [NSString stringWithUTF8String:name];
            _propertyKeys[propertyName] = @""; // Just so it will save something
        }
    }
    
    // Free our properties
    free(properties);
}

- (void) configureRealDictionary {
    // Check to see if there's a Plist included in the main bundle
    NSString * path = _plistPath;
    
    // Get Plist
    NSMutableDictionary * plist = [[NSMutableDictionary alloc]initWithContentsOfFile:path];
    
    // Return -- If null, return empty, do not return null
    _realDictionary = (plist) ? plist : [NSMutableDictionary dictionary];
}

- (void) populateProperties {
    NSSet *allPlistKeysSet = [NSSet setWithArray:_realDictionary.allKeys];
    NSSet *allPropertiesSet = [NSSet setWithArray:_propertyKeys.allKeys];
    [allPropertiesSet enumerateObjectsUsingBlock:^(NSString * propertyName, BOOL *stop) {
        
        NSSet * dictKeys = [allPlistKeysSet objectsPassingTest:^BOOL(NSString * key, BOOL *stop) {
            BOOL didPass = NO;
            if ([key caseInsensitiveCompare:propertyName] == NSOrderedSame) {
                didPass = YES;
                *stop = YES;
            }
            return didPass;
        }];
        if (dictKeys.count > 0) {
            _propertyKeys[propertyName] = [dictKeys anyObject];
        }
        
        // Set after setting corresponding value in _propertyKeys
        [self setPropertyFromDictionaryValueWithName:propertyName];
    }];
}

#pragma mark SYNC

- (void) synchronizePropertiesToDictionary {
    
    // So we don't have to check it every time
    BOOL isInfo = [_plistName isEqualToString:@"Info"];
    
    // Set our properties to the dictionary before we write it
    for (NSString * propertyName in _propertyKeys.allKeys) {
        
        // Check if we're using an Info.plist model
        if (!isInfo) {
            // If not Info.plist, don't set this variable.  The other properties won't be set because the can be null, but because it's a BOOL, it will set a default 0 and show NO.  This means that any custom plist will have this property added;
            if ([propertyName isEqualToString:@"LSRequiresIPhoneOS"]) {
                continue;
            }
        }
        
        // Make sure our dictionary is set to latest property value
        [self setDictionaryValueFromPropertyWithName:propertyName];
    }
    
}

#pragma mark DEALLOC & SAVE - OK?

- (void) dealloc {
    
    NSLog(@"Dealloc");

    // Bundled Plists are immutable, return
    if (_isBundledPlist) {
        NSLog(@"Not Saving ... Bundled");
        return;
    }
    else {
        
        // Update Dictionary Before We Compare Dirty (WILL SET VIA KVO)
        [self synchronizePropertiesToDictionary];
        
        // AFTER setting objects to dictionary from properties so we can know if dirty
        [self removeKVO];
        
        // Save
        if (_isDirty) {
            NSLog(@"Saving ... Dirty");
            [self writeDictionaryInBackground:_realDictionary toPath:_plistPath withCompletion:nil];
        }
        else {
            NSLog(@"Not Saving ... Clean");
        }
    }
    
}

- (void) removeKVO {
    [_observingKeyPaths enumerateObjectsUsingBlock:^(NSString * keyPath, BOOL *stop) {
        [_realDictionary removeObserver:self forKeyPath:keyPath];
    }];
}

- (void) writeDictionaryInBackground:(NSDictionary *)dictionary toPath:(NSString *)path withCompletion:(void(^)(void))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        
        NSLog(@"Saving NEW ..........");
        [dictionary writeToFile:path atomically:YES];
        
        if (completion) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                completion();
            });
        }
        else {
            NSLog(@"No CompletionBlock");
        }
        
    });
}

- (void) saveInBackgroundWithCompletion:(void(^)(void))completion {

    // Bundled Plists are immutable, don't save (on real devices)
    if (_isBundledPlist) {
        if (completion) {
            NSLog(@"Bundled Plists are immutable on a RealDevice, New values will not save!");
            completion();
        }
        return;
    }
    
    // Update dictionary to reflect values set via properties.  Will set _isDirty via KVO
    [self synchronizePropertiesToDictionary];
    
    // Save if dirty
    if (_isDirty) {
        
        __weak typeof(self) weakSelf = self;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{

            __strong typeof(weakSelf) strongSelf = weakSelf;
            
            if (strongSelf) {
                
                // Get Path
                NSString *path = _plistPath;
                
                // Write it to file
                [strongSelf.realDictionary writeToFile:path atomically:YES];
                
                // Reset dirty - We need to access directly because of readOnly status
                strongSelf->_isDirty = NO;
                
                // Write and run completion
                [strongSelf writeDictionaryInBackground:strongSelf.realDictionary toPath:strongSelf.plistPath withCompletion:completion];

            }
        });
    }
    else if (completion) {
        // Object is clean, run completion if it exists
        completion();
    }
    else {
        // clean w/ no completion
    }
}

#pragma mark SELECTOR ARGUMENT / RETURN TYPE METHODS

- (const char *) returnTypeOfSelector:(SEL)selector {
    NSMethodSignature * sig = [self methodSignatureForSelector:selector];
    return [sig methodReturnType];
}

- (const char *) typeOfArgumentForSelector:(SEL)selector atIndex:(int)index {
    NSMethodSignature * sig = [self methodSignatureForSelector:selector];
    // Index 0 is object, Index 1 is the selector itself, arguments start at Index 2
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
        
        // Get object to set
        id objectToSet;
        
        // Set to property
        if (strcmp(returnType, @encode(id)) == 0) {
            //NSLog(@"Is Object");
            id (*func)(id, SEL) = (void *)imp;
            objectToSet = func(self, propertyGetterSelector);
        }
        else if (strcmp(returnType, @encode(BOOL)) == 0) {
            //NSLog(@"Is Bool");
            BOOL (*func)(id, SEL) = (void *)imp;
            objectToSet = @(func(self, propertyGetterSelector));
        }
        else if (strcmp(returnType, @encode(int)) == 0) {
            //NSLog(@"Is Int");
            int (*func)(id, SEL) = (void *)imp;
            objectToSet = @(func(self, propertyGetterSelector));
        }
        else if (strcmp(returnType, @encode(float)) == 0) {
            //NSLog(@"Is Float");
            float (*func)(id, SEL) = (void *)imp;
            objectToSet = @(func(self, propertyGetterSelector));
            
        }
        else if (strcmp(returnType, @encode(double)) == 0) {
            //NSLog(@"Is Double");
            double (*func)(id, SEL) = (void *)imp;
            objectToSet = @(func(self, propertyGetterSelector));
        }
        
        if (objectToSet) {
            // self[propertyName] = object;
            [self setObject:objectToSet forKey:propertyName];
        }
        else {
            [self removeObjectForKey:propertyName];
        }
    }
}

- (void) setPropertyFromDictionaryValueWithName:(NSString *)propertyName {
    
    // Default
    __block NSString * dictionaryKey = propertyName;
    
    // If propertyName isn't contained, double check to see if key exists case insensitive
    if (!_realDictionary[propertyName]) {
        /*
         If dictionary value doesn't exist, do case insensitive to check for correctKey
         */
        [_realDictionary.allKeys enumerateObjectsUsingBlock:^(NSString * key, NSUInteger idx, BOOL *stop) {
            if ([key caseInsensitiveCompare:propertyName] == NSOrderedSame) {
                dictionaryKey = key;
                *stop = YES;
            }
        }];
        
    }
    
    // Get our setter from our string
    SEL propertySetterSelector = [self setterSelectorForPropertyName:dictionaryKey];
    
    // Make sure it exists as a property
    if ([self respondsToSelector:propertySetterSelector]) {
        
        if (_realDictionary[dictionaryKey]) {
            
            // Index 0 is object, Index 1 is the selector: arguments start at Index 2
            const char * typeOfProperty = [self typeOfArgumentForSelector:propertySetterSelector atIndex:2];
            
            // Get object from our dictionary
            id objectFromDictionaryForProperty = _realDictionary[dictionaryKey];
            
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

#pragma mark NSMutableDictionary Subclass Like Interaction -- NECESSARY!

- (void) setObject:(id)anObject forKey:(id<NSCopying>)aKey {
    
    if ([[(id)aKey class]isSubclassOfClass:[NSString class]]) {
    
        // We must observe this key before we set it, if we aren't already, otherwise, will not trigger dirty!
        if (![_observingKeyPaths containsObject:aKey]) {
            [_observingKeyPaths addObject:aKey];
            [_realDictionary addObserver:self forKeyPath:(NSString *)aKey options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
        }
        
        // Set the object to our background dictionary
        _realDictionary[aKey] = anObject;
        
        // Update our property -- Just to keep everything synced
        [self setPropertyFromDictionaryValueWithName:(NSString *)aKey];
    }
    else {
        NSLog(@"Error - Unable to add Object: PlistModel can only take strings as keys");
    }
    
}

- (void) removeObjectForKey:(id)aKey {
    
    if ([[(id)aKey class]isSubclassOfClass:[NSString class]]) {
        
        // Remove object from background dictionary
        [_realDictionary removeObjectForKey:aKey];
        
        /*
         I don't remove KVO observers here because, I don't think it's immediately necessary.  I will remove all observers on dealloc, and it's possible the user will still use this key to add objects.
         */
        
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

- (void) observeValueForKeyPath:(NSString *)keyPath
                       ofObject:(id)object
                         change:(NSDictionary *)change
                        context:(void *)context {
    
    // If it's already dirty, don't bother
    if (!_isDirty) {
        if (![change[@"new"]isEqual:change[@"old"]]) {
            // NewValue, We are now dirty
            _isDirty = YES;
        }
    }
    
    NSLog(@"KVO triggered: %@", _isDirty ? @"DIRTY" : @"CLEAN");
}

#pragma mark IS DIRTY GETTER

- (BOOL) isDirty {
    
    /*
     Within self always use _isDirty or self->isDirty.  This method is only for external access if the user wants to check if Dirty
     */
    
    // Will update dictionary to current values (KVO WILL TRIGGER _isDirty)
    [self synchronizePropertiesToDictionary];
    
    // Set when synchronized
    return _isDirty;
}

#pragma mark DESCRIPTION

- (NSString *) description {
    
    // Sync our properties so it will print the appropriate values
    [self synchronizePropertiesToDictionary];
    
    // Print dictionary
    return [_realDictionary description];
}

#pragma mark ADDITIONS


@end

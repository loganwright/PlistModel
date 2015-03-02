//
//  PlistModel.m
//  PlistModel
//
//  Created by Logan Wright on 4/29/14.
//  Copyright (c) 2014 Logan Wright. All rights reserved.
//

/*
 Mozilla Public License
 Version 2.0
 */

#import "PlistModel.h"
#import <objc/runtime.h>

@interface PlistModel ()

/*!
 The actual representation of our Plist
 */
@property (strong, nonatomic) NSMutableDictionary * backingDictionary;

/*!
 The name of our Plist
 */
@property (strong, nonatomic) NSString * plistName;
/*!
 The path to our Plist in directory or bundle
 */
@property (strong, nonatomic) NSString * plistPath;

/*!
 The keyPaths self is currently observing on backingDictionary
 */
@property (strong, nonatomic) NSMutableSet * observingKeyPaths;

/*!
 The names of all properties included in class.
 */
@property (strong, nonatomic) NSMutableArray * propertyNames;

/*!
 Bundled Plists are immutable, we will use this to save time later (set during 'configurePath')
 */
@property BOOL isBundledPlist;

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
        
        // Step 3: Set our properties as Keys in _propertyNames
        [self configurePropertyNames];
        
        // Step 4: Fetch PLIST & set to our backing dictionary
        [self configureBackingDictionary];
        
        // Step 5: Set Properties from PlistDictionary (_backingDictionary) & populate corresponding dictionaryKeys with their property in _propertyNames
        [self populateProperties];
        
        // Step 6: Start observing
        /*
         We will only observe _backingDictionary because all properties are eventually updated in the dictionary.  In this way we can always know if there is a core change before saving.  We must add KVO observers in `setObject` to assure interaction w/ keys is not overlooked.
         
         getPlist(above) will set _isBundledPlist property, should be set at this point
         */
        if (!_isBundledPlist) {
            // Don't observe bundled plists because they're immutable.  Dirty is irrelevant.
            _observingKeyPaths = [NSMutableSet setWithArray:_backingDictionary.allKeys];
            [_observingKeyPaths enumerateObjectsUsingBlock:^(NSString * keyPath, BOOL *stop) {
                [_backingDictionary addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
            }];
        }
        
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
        NSArray *pathArray;
        NSString *documentsDirectory;
#if TARGET_OS_IPHONE
        pathArray = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        documentsDirectory = [pathArray objectAtIndex:0];
        path = [documentsDirectory stringByAppendingPathComponent:appendedPlistName];
#elif TARGET_OS_MAC
        NSString *name = [[NSBundle mainBundle] infoDictionary][(NSString *)kCFBundleNameKey];
        pathArray = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
        documentsDirectory = [pathArray objectAtIndex:0];
        NSString *directoryPath = [documentsDirectory stringByAppendingPathComponent:name];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL isDir = NO;
        if (![fileManager fileExistsAtPath:directoryPath isDirectory:&isDir]) {
            NSError *err;
            [fileManager createDirectoryAtPath:directoryPath withIntermediateDirectories:NO attributes:nil error:&err];
        }
        path = [directoryPath stringByAppendingPathComponent:appendedPlistName];
#endif
    }
    _plistPath = path;
}

- (void) configurePropertyNames {
    _propertyNames = [NSMutableArray array];
    
    // Fetch Properties
    unsigned count;
    objc_property_t *properties = class_copyPropertyList([self class], &count);
    
    // Set the properties to not be included in dictionary
    NSArray * propertyNamesToBlock = @[@"backingDictionary",
                                       @"plistName",
                                       @"observingKeyPaths",
                                       @"isDirty",
                                       @"isBundledPlist",
                                       @"propertyNames",
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
            [_propertyNames addObject:propertyName];
        }
    }
    
    // Free our properties
    free(properties);
}

- (void) configureBackingDictionary {
    // Check to see if there's a Plist included in the main bundle
    NSString * path = _plistPath;
    
    // Get Plist
    NSMutableDictionary *plist;
#if TARGET_OS_IPHONE
    plist = [[NSMutableDictionary alloc]initWithContentsOfFile:path];
#elif TARGET_OS_MAC
    NSData *plistData = [NSData dataWithContentsOfFile:path];
    if (plistData) {
        plist = [NSKeyedUnarchiver unarchiveObjectWithData:plistData];
    }
#endif
    
    // Return -- If null, return empty, do not return null
    _backingDictionary = (plist) ? plist : [NSMutableDictionary dictionary];
}

- (void) populateProperties {
    [_propertyNames enumerateObjectsUsingBlock:^(NSString * propertyName, NSUInteger idx, BOOL *stop) {
        [self setPropertyFromDictionaryValueWithName:propertyName];
    }];
}

#pragma mark DEALLOC

- (void) dealloc {

    // Bundled Plists are immutable ... return
    if (_isBundledPlist) {
        return;
    }
    else {
        
        // Update Dictionary Before We Compare Dirty (WILL SET VIA KVO)
        [self synchronizePropertiesToDictionary];
        
        // AFTER setting objects to dictionary from properties so we can know if dirty
        [self removeKVO];
        
        // Save
        if (_isDirty) {
            [self writeDictionaryInBackground:_backingDictionary toPath:_plistPath withCompletion:nil];
        }
    }
    
}

- (void) removeKVO {
    [_observingKeyPaths enumerateObjectsUsingBlock:^(NSString * keyPath, BOOL *stop) {
        [_backingDictionary removeObserver:self forKeyPath:keyPath];
    }];
}

#pragma mark SAVE & WRITE TO FILE

- (void) writeDictionaryInBackground:(NSDictionary *)dictionary toPath:(NSString *)path withCompletion:(void(^)(BOOL successful))completion {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
    
        // Prepare Package
        BOOL successful = NO;
        
        // Attempt Write
#if TARGET_OS_IPHONE
        successful = [dictionary writeToFile:path atomically:YES];
#elif TARGET_OS_MAC
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:dictionary];
        successful = [[NSFileManager defaultManager]createFileAtPath:path contents:data attributes:nil];
#endif
        if (completion) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                completion(successful);
            });
        }
        else {
            // No completion block
        }
        
    });
}

- (BOOL) save {
    
    // Synchronize
    [self synchronizePropertiesToDictionary];
    
    // Prep Return Package
    BOOL successful = NO;
    
    // Write
    if (_isDirty) {
        successful = [_backingDictionary writeToFile:_plistPath atomically:YES];
        if (successful) _isDirty = NO;
    }
    else {
        successful = YES;
    }
    
    return successful;
}

- (void) saveInBackgroundWithCompletion:(void(^)(BOOL successful))completion {
    
    // Prepare Package
    BOOL successful = NO;

    // Bundled Plists are immutable, don't save (on real devices)
    if (_isBundledPlist) {
        if (completion) {
            NSLog(@"Bundled Plists are immutable on a RealDevice, New values will not save!");
            successful = NO;
            completion(successful);
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
                
                // Prepare Package
                BOOL successful = NO;
                
                // Write to Path
                successful = [strongSelf.backingDictionary writeToFile:strongSelf.plistPath atomically:YES];
                
                // Reset dirty - We need to access directly because of readOnly status
                if (successful) strongSelf->_isDirty = NO;
                
                if (completion) {
                    // Completion on Main Queue
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        completion(successful);
                    });
                }

            }
        });
    }
    else if (completion) {
        // Object is clean, run completion if it exists
        successful = YES;
        completion(successful);
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
    
    if (index < sig.numberOfArguments) {
        // Index 0 is object, Index 1 is the selector itself, arguments start at Index 2
        const char * argType = [sig getArgumentTypeAtIndex:index];
        return argType;
    }
    else {
        NSLog(@"Index out of range of arguments");
        return nil;
    }
}

#pragma mark SELECTORS & PROPERTIES

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

- (void) synchronizePropertiesToDictionary {
    
    // So we don't have to check it every time
    BOOL isInfo = [_plistName isEqualToString:@"Info"];
    
    // Set our properties to the dictionary before we write it
    for (NSString * propertyName in _propertyNames) {
        
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
/*!
 Set the dictionary value from the property value
 */
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
    if (!_backingDictionary[propertyName]) {
        /*
         If dictionary value doesn't exist, do case insensitive to check for correctKey
         */
        [_backingDictionary.allKeys enumerateObjectsUsingBlock:^(NSString * key, NSUInteger idx, BOOL *stop) {
            if ([key caseInsensitiveCompare:propertyName] == NSOrderedSame) {
                dictionaryKey = key;
                *stop = YES;
            }
        }];
        
    }
    
    // Get our setter from our string
    SEL propertySetterSelector = [self setterSelectorForPropertyName:propertyName];
    
    // Make sure it exists as a property
    if ([self respondsToSelector:propertySetterSelector]) {
        
        // Index 0 is object, Index 1 is the selector: arguments start at Index 2
        const char * typeOfProperty = [self typeOfArgumentForSelector:propertySetterSelector atIndex:2];
        // Set our implementation
        IMP imp = [self methodForSelector:propertySetterSelector];
        
        if (_backingDictionary[dictionaryKey]) {
            
            // Get object from our dictionary
            id objectFromDictionaryForProperty = _backingDictionary[dictionaryKey];
            
            // strcmp(str1, str2)
            // 0 if same
            // A value greater than zero indicates that the first character that does not match has a greater value in str1 than in str2;
            // And a value less than zero indicates the opposite.
    
            // Set PlistValue to property
            if (strcmp(typeOfProperty, @encode(id)) == 0) {
                // NSLog(@"Is Object");
                void (*func)(id, SEL, id) = (void *)imp;
                func(self, propertySetterSelector, objectFromDictionaryForProperty);
            }
            else if (strcmp(typeOfProperty, @encode(BOOL)) == 0) {
                // NSLog(@"Is Bool");
                void (*func)(id, SEL, BOOL) = (void *)imp;
                func(self, propertySetterSelector, [objectFromDictionaryForProperty boolValue]);
            }
            else if (strcmp(typeOfProperty, @encode(int)) == 0) {
                // NSLog(@"Is Int");
                void (*func)(id, SEL, int) = (void *)imp;
                func(self, propertySetterSelector, [objectFromDictionaryForProperty intValue]);
            }
            else if (strcmp(typeOfProperty, @encode(float)) == 0) {
                // NSLog(@"Is Float");
                void (*func)(id, SEL, float) = (void *)imp;
                func(self, propertySetterSelector, [objectFromDictionaryForProperty floatValue]);
            }
            else if (strcmp(typeOfProperty, @encode(double)) == 0) {
                // NSLog(@"Is Double");
                void (*func)(id, SEL, double) = (void *)imp;
                func(self, propertySetterSelector, [objectFromDictionaryForProperty doubleValue]);
            }
            
        }
        else {
            
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

#pragma mark LITERALS SUPPORT

- (id)objectForKeyedSubscript:(id)key {
    return [self objectForKey:key];
}

- (void)setObject:(id)obj forKeyedSubscript:(id <NSCopying>)key {
    [self setObject:obj forKey:key];
}

#pragma mark NSMutableDictionary Subclass Like Interaction -- NECESSARY!

- (void) setObject:(id)anObject forKey:(id<NSCopying>)aKey {
    
    if ([[(id)aKey class]isSubclassOfClass:[NSString class]]) {
    
        if (_isBundledPlist) {
            // Bundled plists are immutable
            return;
        }
        
        __block NSString *blockKey = (NSString *)aKey;
        __block NSString *blockPropertyName;
        
        // Check if key matches property, if it does, sync to property value. Properties take priority
        [_propertyNames enumerateObjectsUsingBlock:^(NSString *propertyName, NSUInteger idx, BOOL *stop) {
            if ([propertyName caseInsensitiveCompare:blockKey] == NSOrderedSame) {
                // key matches property
                blockPropertyName = propertyName;
                *stop = YES;
            }
        }];
        
        
        
        // Check to see if there's already a key matching our current key
        if (!_backingDictionary[blockKey]) {
            /*
             If dictionary value doesn't exist, do case insensitive to check for correctKey
             */
            [_backingDictionary.allKeys enumerateObjectsUsingBlock:^(NSString * key, NSUInteger idx, BOOL *stop) {
                if ([key caseInsensitiveCompare:blockKey] == NSOrderedSame) {
                    blockKey = key;
                    *stop = YES;
                }
            }];
            
        }
        
        // We must observe this key before we set it, if we aren't already, otherwise, will not trigger dirty!
        if (![_observingKeyPaths containsObject:blockKey]) {
            [_observingKeyPaths addObject:blockKey];
            [_backingDictionary addObserver:self forKeyPath:blockKey options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
        }
        
        // Set the object to our background dictionary
        _backingDictionary[blockKey] = anObject;
        
        // Update our property -- Just to keep everything synced
        [self setPropertyFromDictionaryValueWithName:blockPropertyName];
    }
    else {
        NSLog(@"Error - Unable to add Object: PlistModel can only take strings as keys");
    }
    
}

- (void) removeObjectForKey:(id)aKey {
    
    if ([[(id)aKey class]isSubclassOfClass:[NSString class]]) {
        
        if (_isBundledPlist) {
            // Bundled plists are immutable
            return;
        }
        
        __block NSString *blockKey = (NSString *)aKey;
        __block NSString *blockPropertyName;
        
        // Check if key matches property, if it does, sync to property value. Properties take priority
        [_propertyNames enumerateObjectsUsingBlock:^(NSString *propertyName, NSUInteger idx, BOOL *stop) {
            if ([propertyName caseInsensitiveCompare:blockKey] == NSOrderedSame) {
                // key matches property
                blockPropertyName = propertyName;
                *stop = YES;
            }
        }];
        
        
        
        // Check to see if there's already a key matching our current key
        if (!_backingDictionary[blockKey]) {
            /*
             If dictionary value doesn't exist, do case insensitive to check for correctKey
             */
            [_backingDictionary.allKeys enumerateObjectsUsingBlock:^(NSString * key, NSUInteger idx, BOOL *stop) {
                if ([key caseInsensitiveCompare:blockKey] == NSOrderedSame) {
                    blockKey = key;
                    *stop = YES;
                }
            }];
            
        }
        
        // Remove object from background dictionary
        [_backingDictionary removeObjectForKey:blockKey];
        
        /*
         I don't remove KVO observers here because, I don't think it's immediately necessary.  I will remove all observers on dealloc, and it's possible the user will still use this key to add objects.
         */
        
        // Update our property -- Just to keep everything synced
        [self setPropertyFromDictionaryValueWithName:blockPropertyName];
    }
    else {
        NSLog(@"Error - Unable to remove Object: Plist Model can only take strings as keys");
    }
}

- (NSUInteger) count {
    return _backingDictionary.count;
}

- (id)objectForKey:(id)aKey {
    
    __block NSString *blockKey = aKey;
    
    // Check if key matches property, if it does, sync to property value. Properties take priority
    [_propertyNames enumerateObjectsUsingBlock:^(NSString *propertyName, NSUInteger idx, BOOL *stop) {
        if ([propertyName caseInsensitiveCompare:blockKey] == NSOrderedSame) {
            // key matches property, must sync - Properties take priority
            [self setDictionaryValueFromPropertyWithName:propertyName];
            *stop = YES;
        }
    }];
    
    // If propertyName isn't contained, double check to see if key exists case insensitive
    if (!_backingDictionary[blockKey]) {
        /*
         If dictionary value doesn't exist, do case insensitive to check for correctKey
         */
        [_backingDictionary.allKeys enumerateObjectsUsingBlock:^(NSString * key, NSUInteger idx, BOOL *stop) {
            if ([key caseInsensitiveCompare:aKey] == NSOrderedSame) {
                blockKey = key;
                *stop = YES;
            }
        }];
        
    }
    
    // Return
    return _backingDictionary[blockKey];
}

- (NSEnumerator *)keyEnumerator {
    return [_backingDictionary keyEnumerator];
}

#pragma mark ENUMERATION

- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id key, id obj, BOOL *stop))block {
    
    [self synchronizePropertiesToDictionary];
    
    [_backingDictionary enumerateKeysAndObjectsUsingBlock:block];
}
- (void)enumerateKeysAndObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (^)(id key, id obj, BOOL *stop))block {
    
    [self synchronizePropertiesToDictionary];
    
    [_backingDictionary enumerateKeysAndObjectsWithOptions:opts usingBlock:block];
}
#pragma mark KEYS & VALUES

- (NSArray *)allKeys {
    
    [self synchronizePropertiesToDictionary];
    
    return _backingDictionary.allKeys;
}
- (NSArray *)allValues {
    
    [self synchronizePropertiesToDictionary];
    
    return _backingDictionary.allValues;
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
}

#pragma mark IS DIRTY GETTER

- (BOOL) isDirty {
    
    /*
     Within self always use _isDirty or self->isDirty.  This method is only for external access if the user wants to check if Dirty
     */
    
    // Will update dictionary to current values (KVO WILL TRIGGER _isDirty) this way user gets latest value
    [self synchronizePropertiesToDictionary];
    
    // Set when synchronized
    return _isDirty;
}

#pragma mark DESCRIPTION

- (NSString *) description {
    
    // Sync our properties so it will print the appropriate values
    [self synchronizePropertiesToDictionary];
    
    // Print dictionary
    return [_backingDictionary description];
}

@end

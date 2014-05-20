//
//  PlistModel.h
//  ShakeLog
//
//  Created by Logan Wright on 4/29/14.
//  Copyright (c) 2014 Logan Wright. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PlistModel : NSObject

#pragma mark CURRENT DIRTY / CLEAN STATUS

/*!
 Checks whether or not the current PlistModel has changed
 */
@property (nonatomic, readonly) BOOL isDirty;

#pragma mark CALL SAVE EXPLICITLY

/*!
 Save is automatically called before being deallocated -- If you need to guarantee a save for whatever reason, you can call it here. 
 */
- (void) saveInBackgroundWithCompletion:(void(^)(void))completion;

#pragma mark INITIALIZERS

/*!
 Use this to initialize your model
 */
+ (instancetype) plistNamed:(NSString *)plistName;

/*!
 Sometimes loading a plist can be a slightly intensive operation.  If performance is of concern, this will execute the load in the background.  Completion block is executed on the main thread.
 */
+ (void) plistNamed:(NSString *)plistName inBackgroundWithBlock:(void(^)(PlistModel * plistModel))completion;

#pragma mark STANDARD INFO.PLIST ITEMS - ONLY SET IF LOADED FROM INFO.PLIST
/*!
 Localization Native Development Region
 */
@property (strong, nonatomic) NSString * CFBundleDevelopmentRegion;

/*!
 Bundle Display Name
 */
@property (strong, nonatomic) NSString * CFBundleDisplayName;

/*!
 Executable File
 */
@property (strong, nonatomic) NSString * CFBundleExecutable;

/*!
 Bundle Identifier
 */
@property (strong, nonatomic) NSString * CFBundleIdentifier;

/*!
 Info Dictionary Version
 */
@property (strong, nonatomic) NSString * CFBundleInfoDictionaryVersion;
@property (strong, nonatomic) NSString * CFBundleName;

/*!
 Bundle OS Type Code
 */
@property (strong, nonatomic) NSString * CFBundlePackageType;

@property (strong, nonatomic) NSString * CFBundleShortVersionString;

/*!
 Bundle Creator OS Type Code
 */
@property (strong, nonatomic) NSString * CFBundleSignature;
@property (strong, nonatomic) NSString * CFBundleVersion;

/*!
 Application Requires iPhone Environment
 */
@property BOOL LSRequiresIPhoneOS;

/*!
 Main Storyboard Filename
 */
@property (strong, nonatomic) NSString * UIMainStoryboardFile;
@property (strong, nonatomic) NSArray * UIRequiredDeviceCapabilities;
@property (strong, nonatomic) NSArray * UISupportedInterfaceOrientations;

#pragma mark ADDITIONAL PROPERTIES - These were invisible on file in Xcode, but show up in code, so I added them
@property (strong, nonatomic) NSString * DTPlatformName;
@property (strong, nonatomic) NSArray * CFBundleSupportedPlatforms;
@property (strong, nonatomic) NSString * DTSDKName;
@property (strong, nonatomic) NSArray * UIDeviceFamily;

/*!
 An array of launch image dictionaries w/ keys: UILaunchImageMinimumOSVersion : UILaunchImageName : UILaunchImageOrientation UILaunchImageSize
 */
@property (strong, nonatomic) NSArray * UILaunchImages;

#pragma mark FOR INTERACTING WITH CLASS LIKE NSMUTABLEDICTIONARY

- (void) setObject:(id)anObject forKey:(id<NSCopying>)aKey;
- (void) removeObjectForKey:(id)aKey;
- (NSUInteger) count;
- (id)objectForKey:(id)aKey;
- (NSEnumerator *)keyEnumerator;

// Enumeration
- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id key, id obj, BOOL *stop))block;
- (void)enumerateKeysAndObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (^)(id key, id obj, BOOL *stop))block;

// Keys and Values
- (NSArray *)allKeys;
- (NSArray *)allValues;

@end

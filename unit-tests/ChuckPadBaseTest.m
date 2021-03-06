//
//  ChuckPadBaseTest.m
//  hello-chuckpad
//
//  Created by Mark Cerqueira on 11/30/16.
//
//

#import "ChuckPadBaseTest.h"

NSInteger const NUMBER_PATCHES_RECENT_API = 20;
NSInteger const MAX_SIZE_FOR_DATA = 10;

@implementation ChuckPadUser

+ (ChuckPadUser *)generateUser {
    ChuckPadUser *user = [[ChuckPadUser alloc] init];
    
    user.username = [[[[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@"iOS"] substringToIndex:12] lowercaseString];
    user.password = [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
    user.email = [NSString stringWithFormat:@"%@@%@.com", user.username, user.username];
    user.totalPatches = 0;
    
    return user;
}

- (void)updateUserId:(NSInteger)userId {
    self.userId = userId;
}

@end

@implementation ChuckPadPatch

// This will let us cycle through the chuck-samples files when calling the generatePatch method
static int sDirectoryIndex = 0;

// Generates a local patch object that we can use to contact the API and then verify its contents. With this default
// method the name of the patch will be the filename, it will have NO parent, and it will not be hidden.
+ (ChuckPadPatch *)generatePatch {
    NSString *chuckSamplesPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"chuck-samples"];
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:chuckSamplesPath error:nil];
    NSString *filename = [dirContents objectAtIndex:sDirectoryIndex];
    
    if (++sDirectoryIndex == [dirContents count]) {
        sDirectoryIndex = 0;
    }
    
    return [self generatePatch:filename];
}

+ (ChuckPadPatch *)generatePatch:(NSString *)filename {
    return [self generatePatch:@"chuck-samples" filename:filename];
}

+ (ChuckPadPatch *)generatePatch:(NSString *)folderName filename:(NSString *)filename {
    ChuckPadPatch *patch = [[ChuckPadPatch alloc] init];
    
    patch.name = filename;
    patch.patchDescription = [[NSUUID UUID] UUIDString];
    
    NSString *folderPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:folderName];
    patch.fileData = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/%@", folderPath, filename]];
    
    patch.hasParent = NO;
    patch.isHidden = NO;
    patch.downloadCount = 0;
    patch.abuseReportCount = 0;
    
    LocationPoint *randomLocation = [LocationPoint generateRandomLocationPoint];
    
    patch.latitude = randomLocation.latitude;
    patch.longitude = randomLocation.longitude;
    
    return patch;
}

- (void)addExtraData:(NSString *)filename {
    [self addExtraData:@"chuck-samples" filename:filename];
}

- (void)addExtraData:(NSString *)folder filename:(NSString *)filename {
    NSString *folderPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:folder];
    self.extraData = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/%@", folderPath, filename]];
}

+ (NSInteger)numberOfChuckFilesInSamplesDirectory {
    NSString *chuckSamplesPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"chuck-samples"];
    return [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:chuckSamplesPath error:nil] count];
}

- (void)setHidden:(BOOL)hidden {
    self.isHidden = hidden;
}

- (void)setNewNameAndDescription {
    self.name = [[NSUUID UUID] UUIDString];
    self.patchDescription = [[NSUUID UUID] UUIDString];
}

@end

@implementation LocationPoint

#define ARC4RANDOM_MAX 0x100000000

+ (LocationPoint *)generateRandomLocationPoint {
    LocationPoint *locationPoint = [LocationPoint new];
    locationPoint.latitude = [NSNumber numberWithFloat:(((float)arc4random() / ARC4RANDOM_MAX) * (90 - -90) + -90)];
    locationPoint.longitude = [NSNumber numberWithFloat:(((float)arc4random() / ARC4RANDOM_MAX) * (180 - -180) + -180)];
    return locationPoint;
}

@end

@implementation ChuckPadBaseTest

#pragma mark - XCTestCase methods

- (void)setUp {
    // We expect all network calls to succeed (as in the service accepts the call and successfully return a response
    // even if that response indicates something did not succeed). If a network call fails it likely means we hit
    // an exception/error on the server.
    [self callSecretStaticMethod:@"setNetworkErrorCallback:" class:@"ChuckPadSocial" argument:^void (void) {
        XCTAssertTrue(false);
    }];
    
    [self resetChuckPadSocialForPatchType:MiniAudicle];
    
    [super setUp];
}

- (void)tearDown {
    [self callSecretStaticMethod:@"clearNetworkErrorCallback" class:@"ChuckPadSocial"];
    
    [[ChuckPadSocial sharedInstance] localLogOut];
    
    [super tearDown];
}

#pragma mark - Helper Methods

// If calling with an argument be sure to add a ":" to the end of the method name!
- (void)callSecretStaticMethod:(NSString *)method class:(NSString *)className argument:(id)object {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if (object != nil) {
        [NSClassFromString(className) performSelector:NSSelectorFromString(method) withObject:object];
    } else {
        [NSClassFromString(className) performSelector:NSSelectorFromString(method)];
    }
#pragma clang diagnostic pop
}

- (void)callSecretStaticMethod:(NSString *)method class:(NSString *)className {
    [self callSecretStaticMethod:method class:className argument:nil];
}

// Source: http://stackoverflow.com/a/2633948/265791
- (NSString *)randomStringWithLength:(int)len {
    // 66 character length string
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.";
    NSMutableString *randomString = [NSMutableString stringWithCapacity:len];
    for (int i = 0; i < len; i++) {
        [randomString appendFormat:@"%C", [letters characterAtIndex:arc4random_uniform((int)[letters length])]];
    }
    return randomString;
}

- (void)resetChuckPadSocialForPatchType:(PatchType)patchType {
    // Before unit tests run, the code in AppDelegate.m runs that bootstraps our ChuckPadSocail class to a particular
    // instance. Call a special debug method to reset all that bootstrapping so we start tests from a clean slate.
    [self callSecretStaticMethod:@"resetSharedInstanceAndBoostrap" class:@"ChuckPadSocial"];
    
    [ChuckPadSocial bootstrapForPatchType:patchType];
    [[ChuckPadSocial sharedInstance] setEnvironment:Local];
}

- (ChuckPadUser *)generateLocalUserAndCreate {
    if ([[ChuckPadSocial sharedInstance] isLoggedIn]) {
        [[ChuckPadSocial sharedInstance] localLogOut];
    }
    
    return [self createUserFromLocalUser:[ChuckPadUser generateUser]];
}

- (ChuckPadUser *)createUserFromLocalUser:(ChuckPadUser *)user {
    XCTestExpectation *expectation = [self expectationWithDescription:@"createUser timed out"];
    [[ChuckPadSocial sharedInstance] createUser:user.username email:user.email password:user.password callback:^(BOOL succeeded, NSError *error) {
        [self postAuthCallAssertsChecks:succeeded user:user logOut:NO];
      
        user.userId = [[ChuckPadKeychain sharedInstance] getLoggedInUserId];
      
        [expectation fulfill];
    }];
    [self waitForExpectations];
    
    return user;
}

- (void)logInWithLocalUser:(ChuckPadUser *)user {
    XCTestExpectation *expectation = [self expectationWithDescription:@"logIn timed out"];
    [[ChuckPadSocial sharedInstance] logIn:user.username password:user.password callback:^(BOOL succeeded, NSError *error) {
        [self postAuthCallAssertsChecks:succeeded user:user logOut:NO];
        [expectation fulfill];
    }];
    [self waitForExpectations];
}

- (ChuckPadPatch *)generatePatch:(BOOL)successExpected {
    return [self generatePatch:NO successExpected:successExpected];
}

- (ChuckPadPatch *)generatePatch:(BOOL)hidden successExpected:(BOOL)successExpected {
    ChuckPadPatch *localPatch = [ChuckPadPatch generatePatch];
    localPatch.isHidden = hidden;
    
    [self uploadPatch:localPatch successExpected:successExpected];
    
    return localPatch;
}

- (ChuckPadPatch *)generatePatchAndUpload:(NSString *)filename successExpected:(BOOL)successExpected {
    ChuckPadPatch *localPatch = [ChuckPadPatch generatePatch:filename];
    [self uploadPatch:localPatch successExpected:successExpected callback:nil];
    return localPatch;
}

- (void)uploadPatch:(ChuckPadPatch *)localPatch successExpected:(BOOL)successExpected {
    [self uploadPatch:localPatch successExpected:successExpected callback:nil];
}

- (void)uploadPatch:(ChuckPadPatch *)localPatch successExpected:(BOOL)successExpected callback:(CreatePatchCallback)callback {
    XCTestExpectation *expectation = [self expectationWithDescription:@"uploadPatch timed out"];
    [[ChuckPadSocial sharedInstance] uploadPatch:localPatch.name description:localPatch.patchDescription parent:localPatch.parentGUID hidden:@(localPatch.isHidden) patchData:localPatch.fileData extraMetaData:localPatch.extraData callback:^(BOOL succeeded, Patch *patch, NSError *error) {
        XCTAssertTrue(succeeded == successExpected);
        
        if (successExpected) {
            [self assertPatch:patch localPatch:localPatch isConsistentForUser:nil];
        }
        
        localPatch.lastServerPatch = patch;
        
        if (callback != nil) {
            callback(succeeded, patch, error);
        }
        
        [expectation fulfill];
    }];
    
    [self waitForExpectations];
}

- (void)uploadMultiplePatches:(NSInteger)patchCount {
    XCTAssertTrue(patchCount <= [ChuckPadPatch numberOfChuckFilesInSamplesDirectory]);
    for (int i = 0; i < patchCount; i++) {
        [self generatePatch:YES];
    }
}

- (void)deletePatch:(ChuckPadPatch *)localPatch {
    XCTAssertTrue(localPatch != nil);
    XCTAssertTrue(localPatch.lastServerPatch != nil);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"deletePatch timed out"];
    [[ChuckPadSocial sharedInstance] deletePatch:localPatch.lastServerPatch callback:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(succeeded);
        XCTAssertTrue(error == nil);
        
        [expectation fulfill];
    }];
    [self waitForExpectations];
}

- (void)assertPatch:(Patch *)patch localPatch:(ChuckPadPatch *)localPatch isConsistentForUser:(ChuckPadUser *)user {
    XCTAssertTrue(patch != nil);
    XCTAssertTrue(localPatch != nil);
    
    // The service does this for us so update localPatch if we passed nil names or descriptions
    if (localPatch.name == nil) {
        localPatch.name = @"";
    }
    
    if (localPatch.patchDescription == nil) {
        localPatch.patchDescription = @"";
    }
    
    XCTAssertTrue([localPatch.name isEqualToString:patch.name]);
    XCTAssertTrue([localPatch.patchDescription isEqualToString:patch.patchDescription]);
    
    if (user != nil) {
        XCTAssertTrue([patch.creatorUsername isEqualToString:user.username]);
    }
    
    XCTAssertTrue(localPatch.isHidden == patch.hidden);
    XCTAssertTrue(localPatch.hasParent == [patch hasParentPatch]);
    
    XCTAssertTrue(localPatch.downloadCount == patch.downloadCount);
    XCTAssertTrue(localPatch.abuseReportCount == patch.abuseReportCount);
    
    XCTAssertFalse(patch.isFeatured);
    XCTAssertFalse(patch.isDocumentation);
    
    // If we pass all these assertions, attach the patch as the server knows it to our local patch object so we
    // have the option of mutating the server patch in subsequent tests. NOTE: lastServerPatch should NEVER be
    // mutated locally. It should simply be used to pass into API calls.
    localPatch.lastServerPatch = patch;
    
    // For every assert patch operation convert that patch to a dictionary and then initialize a new patch with that
    // dictionary. Assert both patches are equal.
    NSDictionary *patchAsDictionary = [localPatch.lastServerPatch asDictionary];
    Patch *patchFromDictionary = [[Patch alloc] initWithDictionary:patchAsDictionary];
    XCTAssertTrue([patchFromDictionary isEqual:localPatch.lastServerPatch]);
}

- (void)postAuthCallAssertsChecks:(BOOL)succeeded user:(ChuckPadUser *)user logOut:(BOOL)logOut {
    XCTAssertTrue(succeeded);
    
    [self doPostAuthAssertChecks:user];
    
    if (logOut) {
        [[ChuckPadSocial sharedInstance] localLogOut];
        [self doPostLogOutAssertChecks];
    }
}

- (void)doPostAuthAssertChecks:(ChuckPadUser *)user {
    XCTAssertTrue([[ChuckPadSocial sharedInstance] isLoggedIn]);
    
    XCTAssertTrue([user.username isEqualToString:[[ChuckPadSocial sharedInstance] getLoggedInUserName]]);
    XCTAssertTrue([user.username isEqualToString:[[ChuckPadKeychain sharedInstance] getLoggedInUserName]]);
    
    XCTAssertTrue([user.email isEqualToString:[[ChuckPadSocial sharedInstance] getLoggedInEmail]]);
    XCTAssertTrue([user.email isEqualToString:[[ChuckPadKeychain sharedInstance] getLoggedInEmail]]);
}

- (void)doPostLogOutAssertChecks {
    XCTAssertFalse([[ChuckPadSocial sharedInstance] isLoggedIn]);
    
    XCTAssertTrue([[ChuckPadKeychain sharedInstance] getLoggedInUserName] == nil);
    XCTAssertTrue([[ChuckPadKeychain sharedInstance] getLoggedInAuthToken] == nil);
    XCTAssertTrue([[ChuckPadKeychain sharedInstance] getLoggedInEmail] == nil);
}

- (void)waitForExpectations {
    [self waitForExpectations:5.0];
}

- (void)waitForExpectations:(NSTimeInterval)timeout {
    [self waitForExpectationsWithTimeout:timeout handler:^(NSError *error) {
        if (error) {
            NSLog(@"waitForExpectations - exceptation not met with error: %@", error);
        }
    }];
}

- (void)cleanUpFollowingTest {
    [[ChuckPadSocial sharedInstance] localLogOut];
}

- (void)assertError:(NSError *)error descriptionContainsString:(NSString *)string {
    [self assertError:error descriptionContainsStrings:@[string]];
}

- (void)assertError:(NSError *)error descriptionContainsString:(NSString *)yesString doesNotContainString:(NSString *)noString {
    [self assertError:error descriptionContainsStrings:@[yesString] doesNotContainStrings:@[noString]];
}

- (void)assertError:(NSError *)error descriptionContainsStrings:(NSArray *)strings {
    [self assertError:error descriptionContainsStrings:strings doesNotContainStrings:nil];
}

- (void)assertError:(NSError *)error descriptionContainsStrings:(NSArray *)strings doesNotContainStrings:(NSArray *)noStrings {
    XCTAssertTrue(error != nil);
    
    NSString *errorDescription = [error.localizedDescription lowercaseString];
    
    for (NSString *string in strings) {
        XCTAssertTrue([errorDescription containsString:[string lowercaseString]]);
    }
    
    for (NSString *noString in noStrings) {
        XCTAssertFalse([errorDescription containsString:[noString lowercaseString]]);
    }
}

@end

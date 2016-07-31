//
//  ChuckPadTests.m
//  chuckpad-social-ios-test
//
//  Created by Mark Cerqueira on 7/25/16.
//
//  NOTE: These tests run against the chuckpad-social server running locally on your machine. To run the chuckpad-social
//  server on your computer please see: https://github.com/markcerqueira/chuckpad-social

#import <XCTest/XCTest.h>

#import "ChuckPadKeychain.h"
#import "ChuckPadSocial.h"
#import "Patch.h"
#import "PatchCache.h"

@interface ChuckPadUser : NSObject

@property(nonatomic, strong) NSNumber *userId;
@property(nonatomic, strong) NSString *username;
@property(nonatomic, strong) NSString *password;
@property(nonatomic, strong) NSString *email;

@end

@implementation ChuckPadUser

+ (ChuckPadUser *)generateUser {
    ChuckPadUser *user = [[ChuckPadUser alloc] init];
    
    user.username = [[[[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@"iOS"] substringToIndex:12] lowercaseString];
    user.password = [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
    user.email = [NSString stringWithFormat:@"%@@%@.com", user.username, user.username];
    
    return user;
}

- (void)updateUserId:(NSInteger)userId {
    self.userId = [NSNumber numberWithInt:userId];
}

@end


@interface ChuckPadPatch : NSObject

@property(nonatomic, strong) NSString *name;
@property(nonatomic, strong) NSString *filename;
@property(nonatomic, strong) NSString *patchDescription;
@property(nonatomic, strong) NSData *fileData;
@property(nonatomic, assign) BOOL hasParent;
@property(nonatomic, assign) BOOL isHidden;

@property(nonatomic, strong) Patch *lastServerPatch;

@end

@implementation ChuckPadPatch

// Generates a local patch object that we can use to contact the API and then verify its contents. With this default
// method the name of the patch will be the filename, it will have NO parent, and it will not be hidden.
+ (ChuckPadPatch *)generatePatch:(NSString *)filename {
    ChuckPadPatch *patch = [[ChuckPadPatch alloc] init];
    
    NSString *chuckSamplesPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"chuck-samples"];

    patch.name = filename;
    patch.filename = filename;
    patch.patchDescription = [[NSUUID UUID] UUIDString];
    patch.fileData = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/%@", chuckSamplesPath, filename]];
    
    patch.hasParent = NO;
    patch.isHidden = NO;
    
    return patch;
}

- (void)setHidden:(BOOL)hidden {
    self.isHidden = hidden;
}

- (void)setNewNameAndDescription {
    self.name = [[NSUUID UUID] UUIDString];
    self.patchDescription = [[NSUUID UUID] UUIDString];
}

@end


@interface ChuckPadTests : XCTestCase

@end

@implementation ChuckPadTests

- (void)setUp {
    [super setUp];
    
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [[ChuckPadSocial sharedInstance] setEnvironmentToDebug];
    [[ChuckPadSocial sharedInstance] logOut];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [[ChuckPadSocial sharedInstance] logOut];
    
    [super tearDown];
}

- (void)testToggleEnvironmentUrl {
    NSString *url = [[ChuckPadSocial sharedInstance] getBaseUrl];
    
    [[ChuckPadSocial sharedInstance] toggleEnvironment];

    NSString *toggledUrl = [[ChuckPadSocial sharedInstance] getBaseUrl];
    
    XCTAssertFalse([url isEqualToString:toggledUrl], @"Base URL did not change after toggle environment call");
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

- (void)testUserRegisterAndLoginAPI {
    // Generate a user with credentials locally. We will register a new user and log in using these credentials.
    ChuckPadUser *user = [ChuckPadUser generateUser];

    // 1 - Register a user
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"createUser timed out (1)"];
    [[ChuckPadSocial sharedInstance] createUser:user.username email:user.email password:user.password callback:^(BOOL succeeded, NSError *error) {
        [self postAuthCallAssertsChecks:succeeded user:user];
        [expectation1 fulfill];
    }];
    [self waitForExpectations];
    
    // 2 - Log in as the user we created
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"logIn timed out (2)"];
    [[ChuckPadSocial sharedInstance] logIn:user.username password:user.password callback:^(BOOL succeeded, NSError *error) {
        [self postAuthCallAssertsChecks:succeeded user:user];
        [expectation2 fulfill];
    }];
    [self waitForExpectations];
}

- (void)testPatchAPI {
    ChuckPadUser *user = [ChuckPadUser generateUser];
    
    // 1 - Create a new user so we can upload patches
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"createUser timed out (1)"];
    [[ChuckPadSocial sharedInstance] createUser:user.username email:user.email password:user.password callback:^(BOOL succeeded, NSError *error) {
        [self doPostAuthAssertChecks:user];
        [expectation1 fulfill];
    }];
    [self waitForExpectations];
    
    // 2 - Upload a new patch
    ChuckPadPatch *localPatch = [ChuckPadPatch generatePatch:@"demo0.ck"];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"uploadPatch timed out (2)"];
    [[ChuckPadSocial sharedInstance] uploadPatch:localPatch.name description:localPatch.patchDescription parent:-1 filename:localPatch.filename fileData:localPatch.fileData callback:^(BOOL succeeded, Patch *patch, NSError *error) {
        XCTAssertTrue(succeeded);
        
        // Assert our username and owner username of patch match and once we confirm that is the case, update our local
        // user object with its user id.
        XCTAssertTrue([patch.creatorUsername isEqualToString:user.username]);
        [user updateUserId:patch.creatorId];
        
        [self assertPatch:patch localPatch:localPatch isConsistentForUser:user];
        
        [expectation2 fulfill];
    }];
    [self waitForExpectations];
    
    
    // 3 - Test get my patches API. This should return one patch for the new user we created in step 1 for which we
    // uploaded a sigle patch in step 2.
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"getMyPatches timed out (3)"];
    [[ChuckPadSocial sharedInstance] getMyPatches:^(NSArray *patchesArray, NSError *error) {
        XCTAssertTrue(patchesArray != nil);
        XCTAssertTrue([patchesArray count] == 1);
        
        [self assertPatch:[patchesArray objectAtIndex:0] localPatch:localPatch isConsistentForUser:user];
        
        [expectation3 fulfill];
    }];
    [self waitForExpectations];
    
    // 4 - We uploaded a patch in step 2. If we download the file data for that patch it should match exactly the
    // data we uploaded during step 2.
    XCTestExpectation *expectation4 = [self expectationWithDescription:@"downloadPatchResource timed out (4)"];
    [[ChuckPadSocial sharedInstance] downloadPatchResource:localPatch.lastServerPatch callback:^(NSData *patchData, NSError *error) {
        XCTAssert([localPatch.fileData isEqualToData:patchData]);
        [expectation4 fulfill];
    }];
    [self waitForExpectations];
    
    // 5 - Test the update patch API. We will first mutate our local patch and then call updatePatch passing in
    // parameters from our updated localPatch and then verify the response against our localPatch.
    [localPatch setHidden:YES];
    [localPatch setNewNameAndDescription];
    
    XCTestExpectation *expectation5 = [self expectationWithDescription:@"updatePatch timed out (5)"];
    [[ChuckPadSocial sharedInstance] updatePatch:localPatch.lastServerPatch hidden:[NSNumber numberWithBool:localPatch.isHidden] name:localPatch.name description:localPatch.patchDescription filename:nil fileData:nil callback:^(BOOL succeeded, Patch *patch, NSError *error) {
        XCTAssertTrue(succeeded);

        [self assertPatch:patch localPatch:localPatch isConsistentForUser:user];
        
        [expectation5 fulfill];
    }];
    [self waitForExpectations];
    
    // 6 - Getting patches for this user would normally return 0 patches because in step 5 we set the only uploaded
    // patch this user has to hidden. But since we are the owning user, we should get back 1 patch because patch owners
    // can see patches even if they are hidden.
    XCTestExpectation *expectation6 = [self expectationWithDescription:@"getPatchesForUserId timed out (6)"];
    [[ChuckPadSocial sharedInstance] getPatchesForUserId:[user.userId integerValue] callback:^(NSArray *patchesArray, NSError *error) {
        XCTAssertTrue(patchesArray != nil);
        XCTAssertTrue([patchesArray count] == 1);
        
        [self assertPatch:[patchesArray objectAtIndex:0] localPatch:localPatch isConsistentForUser:user];

        [expectation6 fulfill];
    }];
    [self waitForExpectations];
    
    // 7 - Get all patches API.
    XCTestExpectation *expectation7 = [self expectationWithDescription:@"getAllPatches timed out (7)"];
    [[ChuckPadSocial sharedInstance] getAllPatches:^(NSArray *patchesArray, NSError *error) {
        XCTAssertTrue(patchesArray != nil);
        
        // We do greater than or equal to 1 because unless the environment has been wiped clean, we will likely have
        // more than one patch.
        XCTAssertTrue([patchesArray count] >= 1);
        
        [expectation7 fulfill];
    }];
    [self waitForExpectations];
}

- (void)testPatchCache {
    [[PatchCache sharedInstance] setObject:@"World" forKey:@"1-seconds" expire:1];
    [[PatchCache sharedInstance] setObject:@"World" forKey:@"4-seconds" expire:4];
    [[PatchCache sharedInstance] setObject:@"World" forKey:@"60-seconds" expire:60];
    
    // A key that does not map to anything should return nil
    XCTAssertNil([[PatchCache sharedInstance] objectForKey:@"Non-existent key"]);
    
    // No time has advanced so all these should return valid, non-nil objects
    XCTAssertNotNil([[PatchCache sharedInstance] objectForKey:@"1-seconds"]);
    XCTAssertNotNil([[PatchCache sharedInstance] objectForKey:@"4-seconds"]);
    XCTAssertNotNil([[PatchCache sharedInstance] objectForKey:@"60-seconds"]);
    
    [NSThread sleepForTimeInterval:2];
    
    // Our object for "1-seconds" should have expired because 2 seconds have passed
    XCTAssertNil([[PatchCache sharedInstance] objectForKey:@"1-seconds"]);
    XCTAssertNotNil([[PatchCache sharedInstance] objectForKey:@"4-seconds"]);
    XCTAssertNotNil([[PatchCache sharedInstance] objectForKey:@"60-seconds"]);
    
    [NSThread sleepForTimeInterval:3];
    
    // Now our object for "4-seconds" should also have expired because 5 seconds have passed
    XCTAssertNil([[PatchCache sharedInstance] objectForKey:@"1-seconds"]);
    XCTAssertNil([[PatchCache sharedInstance] objectForKey:@"4-seconds"]);
    XCTAssertNotNil([[PatchCache sharedInstance] objectForKey:@"60-seconds"]);
    
    [[PatchCache sharedInstance] removeAllObjects];
    
    // All objects removed so everything should return nil
    XCTAssertNil([[PatchCache sharedInstance] objectForKey:@"1-seconds"]);
    XCTAssertNil([[PatchCache sharedInstance] objectForKey:@"4-seconds"]);
    XCTAssertNil([[PatchCache sharedInstance] objectForKey:@"60-seconds"]);
}

- (void)assertPatch:(Patch *)patch localPatch:(ChuckPadPatch *)localPatch isConsistentForUser:(ChuckPadUser *)user {
    XCTAssertTrue(patch != nil);
    XCTAssertTrue(localPatch != nil);
    XCTAssertTrue(user != nil);

    XCTAssertTrue([localPatch.name isEqualToString:patch.name]);
    XCTAssertTrue([localPatch.filename isEqualToString:patch.filename]);
    XCTAssertTrue([localPatch.patchDescription isEqualToString:patch.patchDescription]);

    XCTAssertTrue([patch.creatorUsername isEqualToString:user.username]);
    
    XCTAssertTrue(localPatch.isHidden == patch.hidden);
    XCTAssertTrue(localPatch.hasParent == [patch hasParentPatch]);

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

// Verifies logged in user state is consistent, logs out the user, and verifies logged out state is consistent.
- (void)postAuthCallAssertsChecks:(BOOL)succeeded user:(ChuckPadUser *)user {
    XCTAssertTrue(succeeded);

    [self doPostAuthAssertChecks:user];
    [[ChuckPadSocial sharedInstance] logOut];
    [self doPostLogOutAssertChecks];
}

// Once a user logs in this asserts that ChuckPadSocial is in a consistent state for the user that just logged in.
- (void)doPostAuthAssertChecks:(ChuckPadUser *)user {
    XCTAssertTrue([[ChuckPadSocial sharedInstance] isLoggedIn]);

    XCTAssertTrue([user.username isEqualToString:[[ChuckPadSocial sharedInstance] getLoggedInUserName]]);

    XCTAssertTrue([user.username isEqualToString:[[ChuckPadKeychain sharedInstance] getLoggedInUserName]]);
    XCTAssertTrue([user.password isEqualToString:[[ChuckPadKeychain sharedInstance] getLoggedInPassword]]);
    XCTAssertTrue([user.email isEqualToString:[[ChuckPadKeychain sharedInstance] getLoggedInEmail]]);
}

// Once a user is logged out this asserts that ChuckPadSocial and its internal keychain are in a consistent state.
- (void)doPostLogOutAssertChecks {
    XCTAssertFalse([[ChuckPadSocial sharedInstance] isLoggedIn]);

    XCTAssertTrue([[ChuckPadKeychain sharedInstance] getLoggedInUserName] == nil);
    XCTAssertTrue([[ChuckPadKeychain sharedInstance] getLoggedInPassword] == nil);
    XCTAssertTrue([[ChuckPadKeychain sharedInstance] getLoggedInEmail] == nil);
}

@end
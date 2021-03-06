//
//  ChuckPadServiceUserTests.m
//  hello-chuckpad
//  Created by Mark Cerqueira on 7/25/16.
//

#import "ChuckPadBaseTest.h"

@interface ChuckPadServiceUserTests : ChuckPadBaseTest

@end

@implementation ChuckPadServiceUserTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testCreateUser {
    [self generateLocalUserAndCreate];
    
    [self cleanUpFollowingTest];
}

- (void)testCreateUserAndLogIn {
    ChuckPadUser *user = [self generateLocalUserAndCreate];
    
    // Log out so we can log in below
    [[ChuckPadSocial sharedInstance] localLogOut];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"logIn timed out"];
    [[ChuckPadSocial sharedInstance] logIn:user.username password:user.password callback:^(BOOL succeeded, NSError *error) {
        [self postAuthCallAssertsChecks:succeeded user:user logOut:YES];
        [expectation fulfill];
    }];
    [self waitForExpectations];
    
    [self cleanUpFollowingTest];
}

- (void)testChangePassword {
    ChuckPadUser *user = [self generateLocalUserAndCreate];
    
    NSString *oldPassword = user.password;
    NSString *newPassword = [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
    
    // Change the password
    XCTestExpectation *expectation = [self expectationWithDescription:@"changePassword timed out"];
    [[ChuckPadSocial sharedInstance] changePassword:newPassword callback:^(BOOL succeeded, NSError *error) {
        [self postAuthCallAssertsChecks:succeeded user:user logOut:YES];
        [expectation fulfill];
    }];
    [self waitForExpectations];
    
    // Check to see we can log in with the updated credentials
    expectation = [self expectationWithDescription:@"logIn timed out"];
    [[ChuckPadSocial sharedInstance] logIn:user.username password:newPassword callback:^(BOOL succeeded, NSError *error) {
        [self postAuthCallAssertsChecks:succeeded user:user logOut:YES];
        [expectation fulfill];
    }];
    [self waitForExpectations];
    
    // Check to make sure we cannot log in with the old password
    expectation = [self expectationWithDescription:@"logIn timed out"];
    [[ChuckPadSocial sharedInstance] logIn:user.username password:oldPassword callback:^(BOOL succeeded, NSError *error) {
        XCTAssertFalse(succeeded);
        [expectation fulfill];
    }];
    [self waitForExpectations];
    
    [self cleanUpFollowingTest];
}

- (void)testLogOut {
    [self generateLocalUserAndCreate];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"logOut timed out"];
    [[ChuckPadSocial sharedInstance] logOut:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(succeeded);
        XCTAssertTrue(error == nil);
        [self doPostLogOutAssertChecks];
        [expectation fulfill];
    }];
    [self waitForExpectations];
    
    [self cleanUpFollowingTest];
}

- (void)testAccountCreateWithTakenUsernameEmail {
    // Generate a user with credentials locally. We will register a new user and log in using these credentials.
    ChuckPadUser *user = [ChuckPadUser generateUser];
    
    // Register a user
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"createUser timed out"];
    [[ChuckPadSocial sharedInstance] createUser:user.username email:user.email password:user.password callback:^(BOOL succeeded, NSError *error) {
        // Log out in this check so we can test logging in next
        [self postAuthCallAssertsChecks:succeeded user:user logOut:YES];
        [expectation1 fulfill];
    }];
    [self waitForExpectations];
    
    // Try to create another user with the same email. Note we purposefully use user.email below instead of user2.email
    ChuckPadUser *user2 = [ChuckPadUser generateUser];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"createUser timed out"];
    [[ChuckPadSocial sharedInstance] createUser:user2.username email:user.email password:user2.password callback:^(BOOL succeeded, NSError *error) {
        XCTAssertFalse(succeeded);
        
        [self assertError:error descriptionContainsString:@"email" doesNotContainString:@"username"];

        [expectation2 fulfill];
    }];
    [self waitForExpectations];
    
    // Try to create another user with the same username. Note we purposefully use user.username below instead of user2.username
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"createUser timed out"];
    [[ChuckPadSocial sharedInstance] createUser:user.username email:user2.email password:user2.password callback:^(BOOL succeeded, NSError *error) {
        XCTAssertFalse(succeeded);

        [self assertError:error descriptionContainsString:@"username" doesNotContainString:@"email"];

        [expectation3 fulfill];
    }];
    [self waitForExpectations];
    
    // Try to create another user with the same username and email. The returned error should mention both email and username
    XCTestExpectation *expectation4 = [self expectationWithDescription:@"createUser timed out"];
    [[ChuckPadSocial sharedInstance] createUser:user.username email:user.email password:user2.password callback:^(BOOL succeeded, NSError *error) {
        XCTAssertFalse(succeeded);
        
        [self assertError:error descriptionContainsStrings:@[@"username", @"email"]];

        [expectation4 fulfill];
    }];
    [self waitForExpectations];
    
    [self cleanUpFollowingTest];
}

- (void)testForgotPassword {
    // Generate a user with credentials locally. We will register a new user and log in using these credentials.
    ChuckPadUser *user = [ChuckPadUser generateUser];
    
    // Register a user
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"createUser timed out"];
    [[ChuckPadSocial sharedInstance] createUser:user.username email:user.email password:user.password callback:^(BOOL succeeded, NSError *error) {
        // Log out in this check so we can test logging in next
        [self postAuthCallAssertsChecks:succeeded user:user logOut:YES];
        [expectation1 fulfill];
    }];
    [self waitForExpectations];
    
    // Hit the forgot password API for our user. Account should be found with either email or username so exercise the
    // API first using username and then email
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"forgotPassword timed out"];
    [[ChuckPadSocial sharedInstance] forgotPassword:user.username callback:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(succeeded);
        
        [[ChuckPadSocial sharedInstance] forgotPassword:user.email callback:^(BOOL succeeded, NSError *error) {
            XCTAssertTrue(succeeded);
            [expectation2 fulfill];
        }];
    }];
    [self waitForExpectations];
    
    // This is only a local user. It is not created on the service.
    ChuckPadUser *localUser = [ChuckPadUser generateUser];
    
    // Hit the forgot password API for a user that does not exist with both email and username.
    XCTestExpectation *expectation3 = [self expectationWithDescription:@"forgotPassword timed out"];
    [[ChuckPadSocial sharedInstance] forgotPassword:localUser.username callback:^(BOOL succeeded, NSError *error) {
        XCTAssertFalse(succeeded);
        
        [[ChuckPadSocial sharedInstance] forgotPassword:localUser.email callback:^(BOOL succeeded, NSError *error) {
            XCTAssertFalse(succeeded);
            [expectation3 fulfill];
        }];
    }];
    [self waitForExpectations];
    
    [self cleanUpFollowingTest];
}

- (void)testWeakPassword {
    // Generate a user with credentials locally and set the password to something weak
    ChuckPadUser *user = [ChuckPadUser generateUser];
    user.password = @"1234";
    
    // This createUser call should fail as the password is too weak
    XCTestExpectation *expectation = [self expectationWithDescription:@"createUser timed out"];
    [[ChuckPadSocial sharedInstance] createUser:user.username email:user.email password:user.password callback:^(BOOL succeeded, NSError *error) {
        XCTAssertFalse(succeeded);
        
        [self assertError:error descriptionContainsStrings:@[@"password", @"weak"]];

        [expectation fulfill];
    }];
    [self waitForExpectations];
    
    [self cleanUpFollowingTest];
}

- (void)testChangePasswordWithWeakPassword {
    [self generateLocalUserAndCreate];
    
    NSArray *weakPasswords = @[@"abc", @"123", @"_", @"ab12"];
    
    for (NSString * weakPassword in weakPasswords) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"changePassword timed out"];
        [[ChuckPadSocial sharedInstance] changePassword:weakPassword callback:^(BOOL succeeded, NSError *error) {
            XCTAssertFalse(succeeded);
            
            [self assertError:error descriptionContainsStrings:@[@"password", @"weak"]];
            
            [expectation fulfill];
        }];
        [self waitForExpectations];
    }

    [self cleanUpFollowingTest];
}

- (void)testValidAndInvalidUsernames {
    // Note - we will append a random 5 character prefix to these in the for loop below to avoid hitting the case where
    // we are trying to create multiple users with the same username.
    NSDictionary *usernameValidityDictionary = @{@"super-long-username" : @NO, // Too long
                                                 @"~~$o$_/|\\" : @NO, // Invalid characters
                                                 @"abC-._.-567$" : @NO, // Almost valid except $ is invalid character
                                                 @"abC-._.-567" : @YES}; // Should be valid
    
    for (NSString *username in [usernameValidityDictionary allKeys]) {
        ChuckPadUser *user = [ChuckPadUser generateUser];
        
        user.username = [NSString stringWithFormat:@"%@%@", [self randomStringWithLength:5], username];
        
        BOOL shouldSucceed = [[usernameValidityDictionary objectForKey:username] boolValue];
        
        XCTestExpectation *expectation = [self expectationWithDescription:@"createUser timed out"];
        [[ChuckPadSocial sharedInstance] createUser:user.username email:user.email password:user.password callback:^(BOOL succeeded, NSError *error) {
            XCTAssertTrue(shouldSucceed == succeeded);
            
            // Need to do a localLogOut to clear credentials so we can log in again.
            [[ChuckPadSocial sharedInstance] localLogOut];
            
            [expectation fulfill];
        }];
        [self waitForExpectations];
    }
    
    [self cleanUpFollowingTest];
}

- (void)testUsernameCaseSensitivityForCreateUser {
    NSString *baseUsername = [self randomStringWithLength:20];
    NSArray *usernames = @[baseUsername, [baseUsername uppercaseString], [baseUsername lowercaseString]];
    
    for (int i = 0; i < [usernames count]; i++) {
        ChuckPadUser *user = [ChuckPadUser generateUser];
        user.username = [usernames objectAtIndex:i];
        
        XCTestExpectation *expectation = [self expectationWithDescription:@"createUser timed out"];
        [[ChuckPadSocial sharedInstance] createUser:user.username email:user.email password:user.password callback:^(BOOL succeeded, NSError *error) {
            // Only the first call should succeed because the rest are upper/lower case variations of the first username used
            XCTAssertTrue(succeeded == (i == 0));
            
            // The error message should only mention that the username is used, not the email.
            if (i != 0) {
                [self assertError:error descriptionContainsString:@"username" doesNotContainString:@"email"];
            }
            
            // Need to do a localLogOut to clear credentials so we can log in again.
            [[ChuckPadSocial sharedInstance] localLogOut];
            
            [expectation fulfill];
        }];
        [self waitForExpectations];
    }
    
    [self cleanUpFollowingTest];
}

- (void)testUsernameCaseInsensitivityForLogIn {
    ChuckPadUser *user = [ChuckPadUser generateUser];
    user.username = [self randomStringWithLength:20];
    
    [self createUserFromLocalUser:user];
    
    [[ChuckPadSocial sharedInstance] localLogOut];
    
    NSArray *usernames = @[[user.username uppercaseString], [user.username lowercaseString]];
    for (NSString *username in usernames) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"logIn timed out"];
        [[ChuckPadSocial sharedInstance] logIn:username password:user.password callback:^(BOOL succeeded, NSError *error) {
            XCTAssertTrue(succeeded);
            
            [[ChuckPadSocial sharedInstance] localLogOut];
            
            [expectation fulfill];
        }];
        [self waitForExpectations];
    }
    
    [self cleanUpFollowingTest];
}

- (void)testEmailCaseSensitivityForCreateUser {
    ChuckPadUser *user = [ChuckPadUser generateUser];
    for (int i = 0; i <= 2; i++) {
        // Change username for every pass so we don't hit the duplicate username case
        user.username = [self randomStringWithLength:20];
        
        // 0 pass - leave email as (should succeed)
        
        // 1 pass - make email upper case (should fail)
        if (i == 1) {
            user.email = [user.email uppercaseString];
        }
        
        // 2 pass - make email lower case (should fail)
        if (i == 2) {
            user.email = [user.email lowercaseString];
        }
        
        XCTestExpectation *expectation = [self expectationWithDescription:@"createUser timed out"];
        [[ChuckPadSocial sharedInstance] createUser:user.username email:user.email password:user.password callback:^(BOOL succeeded, NSError *error) {
            // Only the first call should succeed because the rest are upper/lower case variations of the first email used
            XCTAssertTrue(succeeded == (i == 0));
            
            // The error message should only mention that the email is used, NOT the username.
            if (i != 0) {
                [self assertError:error descriptionContainsString:@"email" doesNotContainString:@"username"];
            }
            
            // Need to do a localLogOut to clear credentials so we can log in again.
            [[ChuckPadSocial sharedInstance] localLogOut];
            
            [expectation fulfill];
        }];
        [self waitForExpectations];
    }
    
    [self cleanUpFollowingTest];
}

- (void)testEmailCaseInsensitivityForLogIn {
    ChuckPadUser *user = [ChuckPadUser generateUser];
    
    [self createUserFromLocalUser:user];
    
    [[ChuckPadSocial sharedInstance] localLogOut];
    
    NSArray *emails = @[[user.email uppercaseString], [user.email lowercaseString]];
    for (NSString *email in emails) {
        XCTestExpectation *expectation = [self expectationWithDescription:@"logIn timed out"];
        [[ChuckPadSocial sharedInstance] logIn:email password:user.password callback:^(BOOL succeeded, NSError *error) {
            XCTAssertTrue(succeeded);
            
            [[ChuckPadSocial sharedInstance] localLogOut];
            
            [expectation fulfill];
        }];
        [self waitForExpectations];
    }
    
    [self cleanUpFollowingTest];
}

- (void)testAuthTokenInvalidResponseCode {
    // Create a user
    [self generateLocalUserAndCreate];
    
    // Call a secret method on ChuckPadKeychain to save keychain information in memory
    [self callSecretStaticMethod:@"copyKeychainInfoToMemory" class:@"ChuckPadKeychain"];
    
    // Log out using the logOut API which invalidates the auth token on the service
    XCTestExpectation *expectation = [self expectationWithDescription:@"logOut timed out"];
    [[ChuckPadSocial sharedInstance] logOut:^(BOOL succeeded, NSError *error) {
        XCTAssertTrue(succeeded);
        XCTAssertTrue(error == nil);
        [self doPostLogOutAssertChecks];
        [expectation fulfill];
    }];
    [self waitForExpectations];
    
    // Our auth token should now be invalidated and our keychain has been cleared.
    
    // Call another secret method on ChuckPadKeychain to push our in-memory copy back into the keychain
    // Note that we are copying an invalid auth token into the keychain.
    [self callSecretStaticMethod:@"copyMemoryInfoToKeychain" class:@"ChuckPadKeychain"];
    
    // Try to upload a patch but this should fail because our auth token that we restored into the keychain is invalid.
    [self generatePatch:NO];
    
    [self callSecretStaticMethod:@"copyMemoryInfoToKeychain" class:@"ChuckPadKeychain"];
    
    // Logging out should fail because we are already logged out
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"logOut timed out"];
    [[ChuckPadSocial sharedInstance] logOut:^(BOOL succeeded, NSError *error) {
        XCTAssertFalse(succeeded);
        [expectation2 fulfill];
    }];
    [self waitForExpectations];
    
    // TODO Restore again and test more APIs for catching and responding to the invalid auth token!
    
    [self cleanUpFollowingTest];
}

@end

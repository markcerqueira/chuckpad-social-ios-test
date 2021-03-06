//
//  ChuckPadSupportTests.m
//  hello-chuckpad
//
//  Created by Mark Cerqueira on 8/1/16.
//
//  Tests classes used to support chuckpad-social-ios that don't directly interact with the chuckpad-social API
//  service.

#include <stdlib.h>

#import "ChuckPadBaseTest.h"

@interface ChuckPadSupportTests : ChuckPadBaseTest

@end

@implementation ChuckPadSupportTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testChuckPadKeychain {
    NSArray *environmentEnums = @[@(Production), @(Stage), @(Local)];
    NSArray *environmentUrls = [[NSArray alloc] initWithObjects:EnvironmentHostUrls];
    
    for (NSInteger i = 0; i < [environmentEnums count]; i++) {
        [[ChuckPadSocial sharedInstance] setEnvironment:(Environment)[[environmentEnums objectAtIndex:i] integerValue]];
        
        NSString *environmentUrl = (NSString *)[environmentUrls objectAtIndex:i];
        
        User *user = [[User alloc] init];
        user.userId = arc4random_uniform(9001);
        user.username = [NSString stringWithFormat:@"%@%@", environmentUrl, @"username"];
        user.email = [NSString stringWithFormat:@"%@%@", environmentUrl, @"email"];
        user.authToken = [NSString stringWithFormat:@"%@%@", environmentUrl, @"authToken"];
        
        [[ChuckPadKeychain sharedInstance] authSucceededWithUser:user];
        
        XCTAssertTrue([[ChuckPadSocial sharedInstance] isLoggedIn]);
    }
    
    for (NSInteger i = 0; i < [environmentEnums count]; i++) {
        [[ChuckPadSocial sharedInstance] setEnvironment:(Environment)[[environmentEnums objectAtIndex:i] integerValue]];
        XCTAssertTrue([[ChuckPadSocial sharedInstance] isLoggedIn]);
        [[ChuckPadSocial sharedInstance] localLogOut];
    }
    
    for (NSInteger i = 0; i < [environmentEnums count]; i++) {
        [[ChuckPadSocial sharedInstance] setEnvironment:(Environment)[[environmentEnums objectAtIndex:i] integerValue]];
        XCTAssertFalse([[ChuckPadSocial sharedInstance] isLoggedIn]);
    }
}

- (void)testToggleEnvironmentUrl {
    // urlOne is a production URL
    NSString *urlOne = [[ChuckPadSocial sharedInstance] getBaseUrl];
    [[ChuckPadSocial sharedInstance] toggleEnvironment];
    
    // urlTwo is a stage URL
    NSString *urlTwo = [[ChuckPadSocial sharedInstance] getBaseUrl];
    [[ChuckPadSocial sharedInstance] toggleEnvironment];
    
    // urlThree is a production URL
    NSString *urlThree = [[ChuckPadSocial sharedInstance] getBaseUrl];
    [[ChuckPadSocial sharedInstance] toggleEnvironment];
    
    XCTAssertFalse([urlOne isEqualToString:urlTwo]);
    XCTAssertFalse([urlOne isEqualToString:urlThree]);
    XCTAssertFalse([urlTwo isEqualToString:urlThree]);
}

- (void)testChangingPatchTypeDisallowed {
    // We are boostrapped to MiniAudicle. We should not be able to change that.
    BOOL exceptionThrown1 = NO;
    @try {
        // In the setUp method we bootstrapped to MiniAudicle so this method should throw an exception.
        [ChuckPadSocial bootstrapForPatchType:Auraglyph];
    } @catch (NSException *exception) {
        exceptionThrown1 = YES;
    } @finally {
        XCTAssertTrue(exceptionThrown1);
    }
    
    // If we try to bootstrap to what we're already bootstrapped (i.e. MiniAudicle) that is okay.
    BOOL exceptionThrown2 = NO;
    @try {
        // In the setUp method we bootstrapped to MiniAudicle so this method should throw an exception.
        [ChuckPadSocial bootstrapForPatchType:MiniAudicle];
    } @catch (NSException *exception) {
        exceptionThrown2 = YES;
    } @finally {
        XCTAssertFalse(exceptionThrown2);
    }
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

@end

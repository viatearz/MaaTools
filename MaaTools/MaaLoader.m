//
//  MaaLoader.m
//  MaaTools
//

#import "MaaLoader.h"
#import "MaaTools-Swift.h"

@implementation MaaLoader

static void __attribute__((constructor)) initialize(void) {
    [MaaBootstrap launch];
}

@end

#import <Foundation/Foundation.h>

@class RCTReactNativeFactory;

NS_ASSUME_NONNULL_BEGIN

@interface ConcurrentCommitter : NSObject

+ (void)startWithFactory:(RCTReactNativeFactory *)factory;

@end

NS_ASSUME_NONNULL_END

#ifndef ValhallaWrapperHeader_h
#define ValhallaWrapperHeader_h

#import <Foundation/Foundation.h>

@class ValhallaWrapper;

@interface ValhallaWrapper : NSObject {
    @private
    void* _actor;
}

- (instancetype)initWithConfigPath:(NSString*)config_path error:(__autoreleasing NSError **)error;

- (NSString*)route:(NSString*)request;

- (NSString*)traceRoute:(NSString*)request;

/// trace_attributes: 吸着したエッジの属性（surface / road_class / length 等）を返す。
/// route / trace_route の応答には surface が入らないため、路面を知るにはこの action が要る。
- (NSString*)traceAttributes:(NSString*)request;

@end

#endif /* ValhallaWrapperHeader_h */

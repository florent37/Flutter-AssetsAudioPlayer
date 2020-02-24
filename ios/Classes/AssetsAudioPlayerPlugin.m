#import "AssetsAudioPlayerPlugin.h"
#import <assets_audio_player/SwiftAssetsAudioPlayerPlugin.swift-Swift.h>

@implementation AssetsAudioPlayerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftAssetsAudioPlayerPlugin registerWithRegistrar:registrar];
}
@end

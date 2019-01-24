#import "AssetsAudioPlayerPlugin.h"
#import <assets_audio_player/assets_audio_player-Swift.h>

@implementation AssetsAudioPlayerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftAssetsAudioPlayerPlugin registerWithRegistrar:registrar];
}
@end

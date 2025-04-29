#import "RCTVLCPlayerManager.h"
#import "RCTVLCPlayer.h"
#import <React/RCTBridge.h>
#import <JavaScriptCore/JavaScriptCore.h>

#import <React/RCTUIManager.h>
#import <React/RCTBridge+Private.h>
#import <React/RCTAppState.h>
#import <React/RCTImageLoader.h>


@implementation RCTVLCPlayerManager

RCT_EXPORT_MODULE();

@synthesize bridge = _bridge;

- (UIView *)view
{
    return [[RCTVLCPlayer alloc] initWithEventDispatcher:self.bridge.eventDispatcher];
}

/* Should support: onLoadStart, onLoad, and onError to stay consistent with Image */
RCT_EXPORT_VIEW_PROPERTY(onVideoProgress, RCTDirectEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onVideoPaused, RCTDirectEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onVideoStopped, RCTDirectEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onVideoBuffering, RCTDirectEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onVideoPlaying, RCTDirectEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onVideoEnded, RCTDirectEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onVideoError, RCTDirectEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onVideoOpen, RCTDirectEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onVideoLoadStart, RCTDirectEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onVideoLoad, RCTDirectEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onSnapshotCapture, RCTDirectEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onVideoRecorded, RCTDirectEventBlock);


- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

RCT_EXPORT_VIEW_PROPERTY(source, NSDictionary);
RCT_EXPORT_VIEW_PROPERTY(subtitleUri, NSString);
RCT_EXPORT_VIEW_PROPERTY(paused, BOOL);
RCT_EXPORT_VIEW_PROPERTY(seek, float);
RCT_EXPORT_VIEW_PROPERTY(rate, float);
RCT_EXPORT_VIEW_PROPERTY(resume, BOOL);
RCT_EXPORT_VIEW_PROPERTY(replayMedia, float);
RCT_EXPORT_VIEW_PROPERTY(videoAspectRatio, NSString);
RCT_EXPORT_VIEW_PROPERTY(snapshotPath, NSString);
RCT_EXPORT_VIEW_PROPERTY(jumpForwardDuration, NSString);
RCT_EXPORT_VIEW_PROPERTY(jumpBackwardDuration, NSString);
RCT_EXPORT_VIEW_PROPERTY(subtitleColor, NSString);
RCT_EXPORT_VIEW_PROPERTY(subtitleFont, NSString);
RCT_EXPORT_VIEW_PROPERTY(subtitleFontSize, NSString);
RCT_EXPORT_VIEW_PROPERTY(subtitleFontBold, BOOL)
RCT_EXPORT_VIEW_PROPERTY(subtitleEncoding, NSString)
RCT_EXPORT_VIEW_PROPERTY(subtitleDelay, NSString)
RCT_EXPORT_VIEW_PROPERTY(audioDelay, NSString)
RCT_EXPORT_VIEW_PROPERTY(audioChannel, int)
RCT_EXPORT_VIEW_PROPERTY(stopRecording, BOOL)
RCT_EXPORT_VIEW_PROPERTY(startRecordingAtPath, NSString)
RCT_EXPORT_VIEW_PROPERTY(audioAmplification, NSDictionary)
RCT_EXPORT_VIEW_PROPERTY(contrast, float)
RCT_EXPORT_VIEW_PROPERTY(brightness, float)
RCT_EXPORT_VIEW_PROPERTY(hue, float)
RCT_EXPORT_VIEW_PROPERTY(saturation, float)
RCT_EXPORT_VIEW_PROPERTY(gamma, float)

RCT_CUSTOM_VIEW_PROPERTY(muted, BOOL, RCTVLCPlayer)
{
    BOOL isMuted = [RCTConvert BOOL:json];
    [view setMuted:isMuted];
};
RCT_EXPORT_VIEW_PROPERTY(audioTrack, int);
RCT_EXPORT_VIEW_PROPERTY(textTrack, int);

@end

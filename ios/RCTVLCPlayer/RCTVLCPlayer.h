#import <React/RCTView.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVKit/AVKit.h>
#import "MobileVLCKit/MobileVLCKit.h"
@class RCTEventDispatcher;

@interface RCTVLCPlayer : UIView <VLCMediaListPlayerDelegate,VLCMediaPlayerDelegate>

@property (nonatomic, copy) RCTBubblingEventBlock onVideoProgress;
@property (nonatomic, copy) RCTBubblingEventBlock onVideoPaused;
@property (nonatomic, copy) RCTBubblingEventBlock onVideoStopped;
@property (nonatomic, copy) RCTBubblingEventBlock onVideoBuffering;
@property (nonatomic, copy) RCTBubblingEventBlock onVideoPlaying;
@property (nonatomic, copy) RCTBubblingEventBlock onVideoEnded;
@property (nonatomic, copy) RCTBubblingEventBlock onVideoError;
@property (nonatomic, copy) RCTBubblingEventBlock onVideoOpen;
@property (nonatomic, copy) RCTBubblingEventBlock onVideoLoadStart;
@property (nonatomic, copy) RCTBubblingEventBlock onVideoLoad;
@property (nonatomic, copy) RCTBubblingEventBlock onSnapshotCapture;
@property (nonatomic, copy) RCTBubblingEventBlock onVideoRecorded;
@property (nonatomic, copy) RCTBubblingEventBlock onRecordingStart;

@property (nonatomic, assign) int currentAudioChannel;
@property (nonatomic, assign) float currentPosition;
@property (nonatomic, assign) int subtitleIndex;
@property (nonatomic, strong) NSMutableDictionary *pendingProps;


@property (nonatomic, strong) MPNowPlayingInfoCenter *nowPlayingInfoCenter;
@property (nonatomic, strong) MPRemoteCommandCenter *commandCenter;
@property (nonatomic, strong) UIActivityItemsConfiguration *activityConfiguration;
@property (nonatomic, strong) AVPlayerViewController *playerViewController;


- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher NS_DESIGNATED_INITIALIZER;
- (void)setMuted:(BOOL)value;

@end

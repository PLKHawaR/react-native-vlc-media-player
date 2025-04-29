#import "RCTVLCPlayer.h"
#import "../../../../Backend/Helpers/ObjcHelper.h"
#import <ActivityKit/ActivityKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTConvert.h>
#import <React/RCTEventDispatcher.h>
#import <React/UIView+React.h>
#import <ReplayKit/ReplayKit.h>
#if TARGET_OS_TV
#import <TVVLCKit/TVVLCKit.h>
#else
#import <MobileVLCKit/MobileVLCKit.h>
#endif
#import <AVFoundation/AVFoundation.h>
static NSString *const statusKeyPath = @"status";
static NSString *const playbackLikelyToKeepUpKeyPath =
@"playbackLikelyToKeepUp";
static NSString *const playbackBufferEmptyKeyPath = @"playbackBufferEmpty";
static NSString *const readyForDisplayKeyPath = @"readyForDisplay";
static NSString *const playbackRate = @"rate";

#if !defined(DEBUG) || !(TARGET_IPHONE_SIMULATOR)
// #define NSLog(...)
#endif

@implementation RCTVLCPlayer {

    NSString *subtitleFontName;
    NSString *subtitleFontSize;
    NSString *subtitleFontColor;
    NSString *subtitleFontBold;
    NSString *audioChannelMode;
    VLCMedia *media;
    /* Required to publish events */
    RCTEventDispatcher *_eventDispatcher;
    VLCMediaPlayer *_player;

    NSDictionary *_source;
    BOOL _paused;
    BOOL _started;
    NSString *_subtitleUri;
    NSString *videoAspectRatio;

    NSDictionary *_videoInfo;
    RPScreenRecorder *_screenRecorder;

}

- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher {
    if ((self = [super init])) {
        _pendingProps = [NSMutableDictionary dictionary];
        _eventDispatcher = eventDispatcher;
        _screenRecorder = [RPScreenRecorder sharedRecorder];
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(applicationWillResignActive:)
         name:UIApplicationWillResignActiveNotification
         object:nil];
        
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(applicationWillEnterForeground:)
         name:UIApplicationWillEnterForegroundNotification
         object:nil];
    }
    return self;
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    if (!_paused) {
        //        [self setPaused:_paused];
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    [self applyModifiers];
}

- (void)applyModifiers {
    if (!_paused)
        [self play];
}

- (void)setPaused:(BOOL)paused {
    _paused = paused;
    
    if (!paused) {
        [self play];
    } else {
        if (_player) {
            [_player pause];
            _paused = YES;
        }
    }
}

- (void)play {
    if (_player) {
        [_player play];
        _paused = NO;
        _started = YES;
    }
}

- (void)setResume:(BOOL)autoplay {
    if (_player) {
        [self _release];
    }
    NSString *uri = [_source objectForKey:@"uri"];
    NSURL *_uri = [NSURL URLWithString:uri];
    NSDictionary *initOptions = [_source objectForKey:@"initOptions"];

    _player = [[VLCMediaPlayer alloc] init];
    // [bavv edit end]

    UIView *videoView =
    [[UIView alloc] initWithFrame:self.bounds]; // or another valid frame
    [self addSubview:videoView];
    _player.drawable = videoView;
    //    [_player setDrawable:self];
    _player.delegate = self;
    
    VLCMedia *media = [VLCMedia mediaWithURL:_uri];

    for (NSString *option in initOptions) {

        [media addOption:[option stringByReplacingOccurrencesOfString:@"--"
                                                           withString:@""]];
    }
    _player.media = media;
    _player.media.delegate = self;
    [[AVAudioSession sharedInstance]
     setActive:NO
     withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
     error:nil];
}

- (void)setSource:(NSDictionary *)source {
    NSDictionary *initOptions = [source objectForKey:@"initOptions"];
    NSString *uri = [source objectForKey:@"uri"];
    if ([uri hasPrefix:@"file://"]) {
        uri = uri.stringByRemovingPercentEncoding;
    }
    NSURL *_uri = [NSURL URLWithString:uri];
    VLCMedia *media = [VLCMedia mediaWithURL:_uri];
    
    if (_player) {
        [self _release];
        _player = nil;
    }
    _source = source;
    _videoInfo = nil;

    _player = [[VLCMediaPlayer alloc] init];
    [_player setDrawable:self];
    _player.delegate = self;
    for (NSString *option in initOptions) {
        [media addOption:option];
    }
    _player.media = media;
    _player.media.delegate = self;
    [_player setVideoAspectRatio:[videoAspectRatio cStringUsingEncoding:NSASCIIStringEncoding]];
    [[AVAudioSession sharedInstance]
     setActive:NO
     withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
     error:nil];
//    NSString *path = [ObjcHelper downloadFileName];
//        [media addOptions:@{ @"demuxdump-file" : path,
//                             @"demux" : @"demuxdump" }];
//            VLCConsoleLogger *logger = [[VLCConsoleLogger alloc] init];
//            logger.level = kVLCLogLevelInfo | kVLCLogLevelDebug | kVLCLogLevelWarning;
//            _player.libraryInstance.loggers = @[logger];
    
    [self applyPendingProps];
    [self play];
}

- (void)setSubtitleUri:(NSString *)subtitleUri {
    [self addSubtitleToPlayer:subtitleUri];
}

-(void)addSubtitleToPlayer:(NSString *)subtitleUri {
    _pendingProps[@"subtitleUri"] = subtitleUri;
    NSLog(@"subtitle == subtitle uri %@",subtitleUri);
    if (!_player) {
        return;
    }
    NSURL *url = [NSURL URLWithString:subtitleUri];
    NSInteger textTrack = [subtitleUri integerValue];
    if (textTrack) {
        NSLog(@"subtitle == text track uri %ld",(long)textTrack);
        //        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
        [self->_player setCurrentVideoSubTitleIndex:[subtitleUri intValue]];
        //        });
    } else if ([subtitleUri isEqualToString:@""]) {
        [_player setCurrentVideoSubTitleIndex:-1];
        NSLog(@"subtitle == text track empty uri %ld",(long)textTrack);
    } else {
        NSLog(@"subtitle == uri %@",subtitleUri);
        subtitleUri = url;
        [_player addPlaybackSlave:url type:VLCMediaPlaybackSlaveTypeSubtitle enforce:TRUE];
    }
}

// ==== player delegate methods ===

#pragma Player Delete

- (void)mediaPlayerSnapshot:(NSNotification *)aNotification {
    self.onSnapshotCapture(@{@
                             "target" : self.reactTag});
}

- (void)mediaPlayerStartedRecording:(NSNotification *)aNotification {
    NSLog(@"vlc recording == mediaPlayerStartedRecording");
}

- (void)mediaPlayer:(VLCMediaPlayer *)player
recordingStoppedAtPath:(NSString *)path {
    NSLog(@"vlc recording == recordingStoppedAtPath");
    self.onVideoRecorded(@{@"path" : path});
}

- (void)mediaPlayerTimeChanged:(NSNotification *)aNotification {
    [self updateVideoProgress];
}

- (void)mediaPlayerStateChanged:(NSNotification *)aNotification {
    if (_player) {
        VLCMediaPlayerState state = _player.state;
        switch (state) {
            case VLCMediaPlayerStateOpening:
                NSLog(@"VLCMediaPlayerStateOpening  %i",
                      _player.numberOfAudioTracks);
                
                self.onVideoOpen(@{@"target" : self.reactTag});
                break;
            case VLCMediaPlayerStatePaused:
                _paused = YES;
                NSLog(@"VLCMediaPlayerStatePaused %i", _player.numberOfAudioTracks);
                self.onVideoPaused(@{@"target" : self.reactTag});
                break;
            case VLCMediaPlayerStateStopped:
                NSLog(@"VLCMediaPlayerStateStopped %i",
                      _player.numberOfAudioTracks);
                self.onVideoStopped(@{@"target" : self.reactTag});
                break;
            case VLCMediaPlayerStateBuffering:
                NSLog(@"VLCMediaPlayerStateBuffering %i",
                      _player.numberOfAudioTracks);
                
                if (!_videoInfo && _player.numberOfAudioTracks > 0) {
                    [self applyPendingProps];
                    _videoInfo = [self getVideoInfo];
                    NSLog(@"Video OnLoad");
                    self.onVideoLoad(_videoInfo);
                }
                self.onVideoBuffering(@{@"target" : self.reactTag});
                break;
            case VLCMediaPlayerStatePlaying:
                [self addSubtitleToPlayer:_pendingProps[@"subtitleUri"]];
                _paused = NO;
                NSLog(@"VLCMediaPlayerStatePlaying %i",
                      _player.numberOfAudioTracks);
                self.onVideoPlaying(@{
                    @"target" : self.reactTag,
                    @"seekable" : [NSNumber numberWithBool:[_player isSeekable]],
                    @"duration" :
                        [NSNumber numberWithInt:[_player.media.length intValue]]
                });
                break;
            case VLCMediaPlayerStateEnded:
                NSLog(@"VLCMediaPlayerStateEnded %i", _player.numberOfAudioTracks);
                int currentTime = [[_player time] intValue];
                int remainingTime = [[_player remainingTime] intValue];
                int duration = [_player.media.length intValue];
                [_player stopRecording];
                self.onVideoEnded(@{
                    @"target" : self.reactTag,
                    @"currentTime" : [NSNumber numberWithInt:currentTime],
                    @"remainingTime" : [NSNumber numberWithInt:remainingTime],
                    @"duration" : [NSNumber numberWithInt:duration],
                    @"position" : [NSNumber numberWithFloat:_player.position]
                });
                break;
            case VLCMediaPlayerStateError:
                NSLog(@"VLCMediaPlayerStateError %i", _player.numberOfAudioTracks);
                self.onVideoError(@{@"target" : self.reactTag});
                [self _release];
                break;
            default:
                break;
        }
    }
}

//   ===== media delegate methods =====

- (void)mediaDidFinishParsing:(VLCMedia *)aMedia {
    NSLog(@"VLCMediaDidFinishParsing %i", _player.numberOfAudioTracks);
}

- (void)mediaMetaDataDidChange:(VLCMedia *)aMedia {
    NSLog(@"VLCMediaMetaDataDidChange %i", _player.numberOfAudioTracks);
}

//   ===================================

- (void)updateVideoProgress {

    //    NSLog(@"Audio Channels %d ==== and Audio Delay %ld",[_player
    //    audioChannel],(long)_player.currentAudioPlaybackDelay);
    if (_player) {
        int currentTime = [[_player time] intValue];
        int remainingTime = [[_player remainingTime] intValue];
        int duration = [_player.media.length intValue];
        if (currentTime >= 0 && currentTime < duration) {
            self.onVideoProgress(@{
                @"target" : self.reactTag,
                @"currentTime" : [NSNumber numberWithInt:currentTime],
                @"remainingTime" : [NSNumber numberWithInt:remainingTime],
                @"duration" : [NSNumber numberWithInt:duration],
                @"position" : [NSNumber numberWithFloat:_player.position]
            });
        }
    }
}

- (NSDictionary *)getVideoInfo {
    NSMutableDictionary *info = [NSMutableDictionary new];
    info[@"duration"] = _player.media.length.value;
    int i;
    if (_player.videoSize.width > 0) {
        info[@"videoSize"] = @{
            @"width" : @(_player.videoSize.width),
            @"height" : @(_player.videoSize.height)
        };
    }
    if (_player.numberOfAudioTracks > 0) {
        NSMutableArray *tracks = [NSMutableArray new];
        for (i = 0; i < _player.numberOfAudioTracks; i++) {
            if (_player.audioTrackIndexes[i] && _player.audioTrackNames[i]) {
                [tracks addObject:@{
                    @"id" : _player.audioTrackIndexes[i],
                    @"name" : _player.audioTrackNames[i]
                }];
            }
        }
        info[@"audioTracks"] = tracks;
    }
    if (_player.numberOfSubtitlesTracks > 0) {
        NSMutableArray *tracks = [NSMutableArray new];
        for (i = 0; i < _player.numberOfSubtitlesTracks; i++) {
            if (_player.videoSubTitlesIndexes[i] &&
                _player.videoSubTitlesNames[i]) {
                [tracks addObject:@{
                    @"id" : _player.videoSubTitlesIndexes[i],
                    @"name" : _player.videoSubTitlesNames[i]
                }];
            }
        }
        info[@"textTracks"] = tracks;
    }
    info[@"currentAudio"] = @(_player.currentAudioTrackIndex);
    info[@"currentTextTrack"] = @(_player.currentVideoSubTitleIndex);
    
    return info;
}

- (void)applyPendingProps {
    if (!_player) return;
    if (_pendingProps[@"subtitleDelay"]) {
        NSInteger delay = [_pendingProps[@"subtitleDelay"] integerValue];
        [_player setCurrentVideoSubTitleDelay:delay];
    }
    if (_pendingProps[@"audioDelay"]) {
        NSInteger delay = [_pendingProps[@"audioDelay"] integerValue];
        [_player setCurrentAudioPlaybackDelay:delay];
    }
    if (_pendingProps[@"subtitleEncoding"]) {
        NSString *encoding = [NSString stringWithFormat:@"subsdec-encoding=%@", _pendingProps[@"subtitleEncoding"]];
        [_player.media addOption:encoding];
    }
    if (_pendingProps[@"subtitleUri"]) {
        [self addSubtitleToPlayer:_pendingProps[@"subtitleUri"]];
    }
    if (_pendingProps[@"subtitleColor"]) {
        [_player performSelector:@selector(setTextRendererFontColor:)
                      withObject:_pendingProps[@"subtitleColor"]];
    }
    if (_pendingProps[@"subtitleFont"]) {
        [_player performSelector:@selector(setTextRendererFont:)
                      withObject:_pendingProps[@"subtitleFont"]];
    }
    if (_pendingProps[@"subtitleFontSize"]) {
        [_player performSelector:@selector(setTextRendererFontSize:)
                      withObject:_pendingProps[@"subtitleFontSize"]];
    }
    NSLog(@"delay == after apply %ld",(long)_player.currentVideoSubTitleDelay);
}

- (void)jumpBackward:(int)interval {
    if (interval >= 0 && interval <= [_player.media.length intValue])
        [_player jumpBackward:interval];
}

- (void)jumpForward:(int)interval {
    if (interval >= 0 && interval <= [_player.media.length intValue])
        [_player jumpForward:interval];
}

- (void)setSeek:(float)pos {
    if ([_player isSeekable]) {
        if (pos >= 0 && pos <= 1) {
            
            [_player setPosition:pos];
        }
    }
}

- (void)setReplayMedia:(float)pos {
    if (_player) {
        [_player setPosition:0];
        [_player stop];
        [self applyPendingProps];
        [_player play];
    }
}

- (void)setJumpBackwardDuration:(NSString *)pos {
    NSLog(@"jumpBackwardDuration");
}

- (void)setSubtitleColor:(NSString *)color {
    if (_player) {
        [_player performSelector:@selector(setTextRendererFontColor:)
                      withObject:color];
    } else {
        _pendingProps[@"subtitleColor"] = color;
    }
    
}

- (void)setSubtitleFont:(NSString *)font

{
    if (_player) {
        [_player performSelector:@selector(setTextRendererFont:) withObject:font];
    } else {
        _pendingProps[@"subtitleFont"] = font;
    }
}

- (void)setSubtitleFontSize:(NSString *)size {
    if (_player) {
        [_player performSelector:@selector(setTextRendererFontSize:)
                      withObject:size];
    } else {
        _pendingProps[@"subtitleFontSize"] = size;
    }
}

- (void)setSubtitleFontBold:(BOOL)bold {
    NSString *boolString = bold ? @"YES" : @"NO";
    [_player performSelector:@selector(setTextRendererFontForceBold:)
                  withObject:boolString];
}

- (void)setSnapshotPath:(NSString *)path {
    
    if([_player videoAspectRatio] != NULL) {
        CGFloat width = self.frame.size.width;
        CGFloat height =  self.frame.size.height;
        
        NSString* aspect =  @([_player videoAspectRatio]);
        
        NSArray *components = [aspect componentsSeparatedByString:@":"];
        
        float aspectWidth = [components[0] floatValue];
        float aspectHeight = [components[1] floatValue];
        float aspectRatio = aspectWidth / aspectHeight;
        
        CGFloat newHeight = (width / aspectRatio);
        
        [_player saveVideoSnapshotAt:path withWidth:(int)width andHeight:(int)newHeight];
        
    }
    else {
        [_player saveVideoSnapshotAt:path withWidth:0 andHeight:0];
    }
}

- (void)setRate:(float)rate {
    [_player setRate:rate];
}

- (void)setStartRecordingAtPath:(NSString *)path {
    NSLog(@"setStartRecordingAtPath %@", path);
    if (_player && path && path.length > 0) {
        NSLog(@"Start vlc recording ==  at path %@ == status %d",path,
              [self->_player startRecordingAtPath:path]);
    }
}

- (void)setAudioChannel:(int)audioChannel {
    if (_player) {
        if (audioChannel == 6) {
            [_player.media addOption:@"spatialaudio-headphones"];
        } else if (audioChannel == 5) {
            [_player.media addOption:@"force-dolby-surround=1"];
        } else {
            _player.audioChannel = audioChannel;
        }
    }
}

- (void)setStopRecording:(BOOL)stop {
    if (_player && stop)
        NSLog(@"stop vlc recording == %d",[_player stopRecording]);
    ;
}

- (void)setAudioTrack:(int)track {
    if (_player)
        [_player setCurrentAudioTrackIndex:track];
}

- (void)setSubtitleDelay:(NSString *)delay {
    if (_player) {
        [_player setCurrentVideoSubTitleDelay:[delay intValue] * 1000];
        NSLog(@"delay == %ld",(long)_player.currentVideoSubTitleDelay);
    } else {
        _pendingProps[@"subtitleDelay"] = @([delay intValue] * 1000);
    }
}

- (void)setAudioDelay:(NSString *)delay {
    if (_player) {
        [_player setCurrentAudioPlaybackDelay:[delay intValue] * 1000];
    } else {
        _pendingProps[@"audioDelay"] = @([delay intValue] * 1000);
    }
}

- (void)setSubtitleEncoding:(NSString *)encoding {
    NSString *subtitleEncoding =
    [NSString stringWithFormat:@"subsdec-encoding=%@", encoding];
    if (_player) {
        [_player.media addOption:subtitleEncoding];
    } else {
        _pendingProps[@"subtitleEncoding"] = subtitleEncoding;
    }
}

- (void)setTextTrack:(int)track {
    if (_player) {
        [_player setCurrentVideoSubTitleIndex:track];
    }
}

- (void)setVideoAspectRatio:(NSString *)ratio {
    videoAspectRatio = [ratio isEqualToString:@"Default"] ? nil : ratio;
    if (_player) {
        const char *char_content = [videoAspectRatio cStringUsingEncoding:NSUTF8StringEncoding];
        [_player setVideoAspectRatio:char_content];
    }
}


-(void)setAudioAmplification:(NSDictionary *)amplificationInfo {
    VLCAudioEqualizer *equalizer = _player.equalizer;
    int band = [amplificationInfo[@"band"] intValue];
    int amplification = [amplificationInfo[@"amplification"] floatValue];
    if (amplificationInfo) {
        [_player setAmplification:amplification forBand:band];
    }
}

- (void)setMuted:(BOOL)value {
    if (_player) {
        [[_player audio] setMuted:value];
    }
}

- (void)setContrast:(float)value {
    if(_player){
        [[[_player adjustFilter] contrast] setValue:@(value)];
    }
}

- (void)setBrightness:(float)value {
    if(_player){
        [[[_player adjustFilter] brightness] setValue:@(value)];
    }
}

- (void)setHue:(float)value {
    if(_player){
        [[[_player adjustFilter] hue] setValue:@(value)];
    }
}

- (void)setSaturation:(float)value {
    if(_player){
        [[[_player adjustFilter] saturation] setValue:@(value)];
    }
}

- (void)setGamma:(float)value {
    if(_player){
        [[[_player adjustFilter] gamma] setValue:@(value)];
    }
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_player.media)
        [_player stop];
    
    if (_player)
        _player = nil;
    
    _eventDispatcher = nil;
}

- (void)_release {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_player.media)
        [_player stop];
    
    if (_player)
        _player = nil;
    
    _eventDispatcher = nil;
}

#pragma mark - Lifecycle
- (void)removeFromSuperview {
    NSLog(@"removeFromSuperview");
    [self _release];
    [super removeFromSuperview];
}

@end

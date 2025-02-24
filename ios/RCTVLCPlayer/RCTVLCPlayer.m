#import <React/RCTConvert.h>
#import "RCTVLCPlayer.h"
#import <React/RCTBridgeModule.h>
#import <React/RCTEventDispatcher.h>
#import <React/UIView+React.h>
#import <MediaPlayer/MediaPlayer.h>
#import <ActivityKit/ActivityKit.h>
#if TARGET_OS_TV
#import <TVVLCKit/TVVLCKit.h>
#else
#import <MobileVLCKit/MobileVLCKit.h>
#endif
#import <AVFoundation/AVFoundation.h>
static NSString *const statusKeyPath = @"status";
static NSString *const playbackLikelyToKeepUpKeyPath = @"playbackLikelyToKeepUp";
static NSString *const playbackBufferEmptyKeyPath = @"playbackBufferEmpty";
static NSString *const readyForDisplayKeyPath = @"readyForDisplay";
static NSString *const playbackRate = @"rate";



#if !defined(DEBUG) || !(TARGET_IPHONE_SIMULATOR)
//#define NSLog(...)
#endif


@implementation RCTVLCPlayer
{
    
    NSString *subtitleFontName;
    NSString *subtitleFontSize;
    NSString *subtitleFontColor;
    NSString *subtitleFontBold;
    /* Required to publish events */
    RCTEventDispatcher *_eventDispatcher;
    VLCMediaPlayer *_player;
    
    NSDictionary * _source;
    BOOL _paused;
    BOOL _started;
    NSString * _subtitleUri;
    
    NSDictionary * _videoInfo;
}


- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher
{
    if ((self = [super init])) {
        _eventDispatcher = eventDispatcher;
        
        // Initialize the Now Playing Info Center
//        _nowPlayingInfoCenter = [MPNowPlayingInfoCenter defaultCenter];
//        _commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillResignActive:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
    }
    return self;
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    if (!_paused) {
        [self setPaused:_paused];
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    [self applyModifiers];
}

- (void)applyModifiers
{
    if(!_paused)
        [self play];
}

- (void)setPaused:(BOOL)paused
{
    if(_player) {
        if(!paused){
            [self play];
        }else {
            [_player pause];
            _paused =  YES;
            _started = NO;
        }
    }
}

-(void)play
{
    if(_player) {
        _player.audioChannel = self.currentAudioChannel;
        [_player play];
        _paused = NO;
        _started = YES;
    }
}

-(void)setResume:(BOOL)autoplay
{
    if(_player){
        [self _release];
    }
    NSString* uri    = [_source objectForKey:@"uri"];
    NSURL* _uri    = [NSURL URLWithString:uri];
    NSDictionary* initOptions = [_source objectForKey:@"initOptions"];
    
    _player = [[VLCMediaPlayer alloc] init];
    // [bavv edit end]
    
    [_player setDrawable:self];
    _player.delegate = self;
    
    VLCMedia *media = [VLCMedia mediaWithURL:_uri];
    
    for (NSString* option in initOptions) {
        
        [media addOption:[option stringByReplacingOccurrencesOfString:@"--" withString:@""]];
    }
    _player.media = media;
    _player.media.delegate = self;
    
    [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    NSLog(@"autoplay: %i",autoplay);
}


-(void)setSource:(NSDictionary *)source
{
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSNumber *savedAudioChannel = [defaults objectForKey:@"savedAudioChannel"];
    if (savedAudioChannel) {
        self.currentAudioChannel = [savedAudioChannel intValue];
    } else {
        self.currentAudioChannel = -1;
    }
    if (_player) {
        [self _release];
    }
    _source = source;
    _videoInfo = nil;
    NSString* uri    = [source objectForKey:@"uri"];
    BOOL    autoplay = [RCTConvert BOOL:[source objectForKey:@"autoplay"]];
    NSURL* _uri    = [NSURL URLWithString:uri];
    NSDictionary* initOptions = [source objectForKey:@"initOptions"];
    _player = [[VLCMediaPlayer alloc] init];
    [_player setDrawable:self];
    _player.delegate = self;
    
    VLCMedia *media = [VLCMedia mediaWithURL:_uri];
    for (NSString* option in initOptions) {
        // extract subtitle options
        if ([option hasPrefix:@"--subtitle-font-name="]) {
            subtitleFontName = [[option componentsSeparatedByString:@"="] lastObject];
        } else if ([option hasPrefix:@"--subtitle-font-size="]) {
            subtitleFontSize = [[option componentsSeparatedByString:@"="] lastObject];
        } else if ([option hasPrefix:@"--subtitle-font-color="]) {
            subtitleFontColor = [[option componentsSeparatedByString:@"="] lastObject];
        } else if ([option hasPrefix:@"--subtitle-font-bold="]) {
            NSString *boldValue = [[option componentsSeparatedByString:@"="] lastObject];
            subtitleFontBold = [boldValue isEqualToString:@"YES"] ? @"YES" : @"NO";
        }
        
        NSLog(@"Options is %@",option);
        // set audio channels
        if ([option isKindOfClass:[NSString class]] && [option hasPrefix:@"--audio-channel-mode="]) {
            NSString *value = [[option componentsSeparatedByString:@"="] lastObject];
            int audioChannel = [value intValue];
            self.currentAudioChannel = audioChannel;
            [defaults setInteger:self.currentAudioChannel forKey:@"savedAudioChannel"];
            [defaults synchronize];
        }
        [media addOption:[option stringByReplacingOccurrencesOfString:@"--" withString:@""]];
    }
    NSLog(@"Audio Channel current %i",self.currentAudioChannel);
    
    _player.media = media;
    _player.media.delegate = self;
    if (!subtitleFontName || [subtitleFontName isEqualToString:@""]) {
        subtitleFontName = @"HelveticaNeue";
    }
    
    if (!subtitleFontSize || [subtitleFontSize isEqualToString:@""]) {
        subtitleFontSize = @"16";
    }
    
    if (!subtitleFontColor || [subtitleFontColor isEqualToString:@""]) {
        subtitleFontColor = @"16777215";
    }
    
    if (!subtitleFontBold || [subtitleFontBold isEqualToString:@""]) {
        subtitleFontBold = @"NO";
    }
    [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    if (_subtitleUri && !([_subtitleUri  isEqual: @""]) && _player) {
        [_player addPlaybackSlave:_subtitleUri type:VLCMediaPlaybackSlaveTypeSubtitle enforce:YES];
    }
    // set subtitle setting to player
    if (_player) {
        [_player performSelector:@selector(setTextRendererFont:) withObject:subtitleFontName];
        [_player performSelector:@selector(setTextRendererFontSize:) withObject:subtitleFontSize];
        [_player performSelector:@selector(setTextRendererFontColor:) withObject:subtitleFontColor];
        [_player performSelector:@selector(setTextRendererFontForceBold:) withObject:subtitleFontBold];
    }
    [self play];
}

//- (void)observeValueForKeyPath:(NSString *)keyPath
//                      ofObject:(id)object
//                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
//                       context:(void *)context {
//    if ([keyPath isEqualToString:@"state"]) {
//        VLCMediaPlayerState oldState = [change[NSKeyValueChangeOldKey] intValue];
//        VLCMediaPlayerState newState = [change[NSKeyValueChangeNewKey] intValue];
//        
//        // Handle the state change here
//        NSLog(@"Media player state changed from %d to %d", oldState, newState);
//    } else if ([keyPath isEqualToString:@"remainingTime"]) {
//        NSLog(@"Media player -- remainingTime %d", [change[NSKeyValueChangeOldKey] intValue]);
//    } else if ([keyPath isEqualToString:@"position"]) {
//        NSLog(@"Media player -- position from %d", [change[NSKeyValueChangeOldKey] intValue]);
//    }
//    
//    else {
//        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
//    }
//}

- (void)setSubtitleUri:(NSString *)subtitleUri
{
    NSURL *url = [NSURL URLWithString:subtitleUri];
    if (url && ![subtitleUri isEqualToString:@""] && _player) {
        _subtitleUri = url;
        [_player addPlaybackSlave:_subtitleUri type:VLCMediaPlaybackSlaveTypeSubtitle enforce:YES];
    } else {
        NSLog(@"Invalid subtitle URI: %@", subtitleUri);
    }
}

// ==== player delegate methods ===



- (void)mediaPlayerTimeChanged:(NSNotification *)aNotification
{
    [self updateVideoProgress];
    //    [self updateNowPlayingInfo];
}

- (void)mediaPlayerStateChanged:(NSNotification *)aNotification
{
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if(_player) {
        VLCMediaPlayerState state = _player.state;
        switch (state) {
            case VLCMediaPlayerStateOpening:
                NSLog(@"VLCMediaPlayerStateOpening  %i", _player.numberOfAudioTracks);
                self.onVideoOpen(@{
                    @"target": self.reactTag
                });
                break;
            case VLCMediaPlayerStatePaused:
                _paused = YES;
                NSLog(@"VLCMediaPlayerStatePaused %i", _player.numberOfAudioTracks);
                self.onVideoPaused(@{
                    @"target": self.reactTag
                });
                break;
            case VLCMediaPlayerStateStopped:
                NSLog(@"VLCMediaPlayerStateStopped %i", _player.numberOfAudioTracks);
                self.onVideoStopped(@{
                    @"target": self.reactTag
                });
                break;
                
                //            case VLCMediaPlayerStateStopping:
                //                NSLog(@"VLCMediaPlayerStateStopping %i", _player.numberOfAudioTracks);
            case VLCMediaPlayerStateBuffering:
                NSLog(@"VLCMediaPlayerStateBuffering %i", _player.numberOfAudioTracks);
                if(!_videoInfo && _player.numberOfAudioTracks > 0) {
                    _videoInfo = [self getVideoInfo];
                    if (_player.audioChannel != self.currentAudioChannel) {
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            self->_player.audioChannel = self.currentAudioChannel;
                        });
                    }
                    self.onVideoLoad(_videoInfo);
                }
                
                
                self.onVideoBuffering(@{
                    @"target": self.reactTag
                });
                break;
            case VLCMediaPlayerStatePlaying:
                _paused = NO;
                
                NSLog(@"VLCMediaPlayerStatePlaying %i", _player.numberOfAudioTracks);
                self.onVideoPlaying(@{
                    @"target": self.reactTag,
                    @"seekable": [NSNumber numberWithBool:[_player isSeekable]],
                    @"duration":[NSNumber numberWithInt:[_player.media.length intValue]]
                });
                break;
            case VLCMediaPlayerStateEnded:
                NSLog(@"VLCMediaPlayerStateEnded %i",  _player.numberOfAudioTracks);
                int currentTime   = [[_player time] intValue];
                int remainingTime = [[_player remainingTime] intValue];
                int duration      = [_player.media.length intValue];
                
                self.onVideoEnded(@{
                    @"target": self.reactTag,
                    @"currentTime": [NSNumber numberWithInt:currentTime],
                    @"remainingTime": [NSNumber numberWithInt:remainingTime],
                    @"duration":[NSNumber numberWithInt:duration],
                    @"position":[NSNumber numberWithFloat:_player.position]
                });
                break;
            case VLCMediaPlayerStateError:
                NSLog(@"VLCMediaPlayerStateError %i", _player.numberOfAudioTracks);
                self.onVideoError(@{
                    @"target": self.reactTag
                });
                [self _release];
                break;
            default:
                break;
        }
    }
}


//   ===== media delegate methods =====

-(void)mediaDidFinishParsing:(VLCMedia *)aMedia {
    NSLog(@"VLCMediaDidFinishParsing %i", _player.numberOfAudioTracks);
}

- (void)mediaMetaDataDidChange:(VLCMedia *)aMedia{
    NSLog(@"VLCMediaMetaDataDidChange %i", _player.numberOfAudioTracks);
}

//   ===================================

-(void)updateVideoProgress
{
    
    NSLog(@"Audio Channels %d ==== and current %d",[_player audioChannel],self.currentAudioChannel);
    if(_player) {
        int currentTime   = [[_player time] intValue];
        int remainingTime = [[_player remainingTime] intValue];
        int duration      = [_player.media.length intValue];
        if( currentTime >= 0 && currentTime < duration) {
            self.onVideoProgress(@{
                @"target": self.reactTag,
                @"currentTime": [NSNumber numberWithInt:currentTime],
                @"remainingTime": [NSNumber numberWithInt:remainingTime],
                @"duration":[NSNumber numberWithInt:duration],
                @"position":[NSNumber numberWithFloat:_player.position]
            });
        }
    }
}

-(NSDictionary *)getVideoInfo
{
    NSMutableDictionary *info = [NSMutableDictionary new];
    info[@"duration"] = _player.media.length.value;
    int i;
    if(_player.videoSize.width > 0) {
        info[@"videoSize"] =  @{
            @"width":  @(_player.videoSize.width),
            @"height": @(_player.videoSize.height)
        };
    }
    if(_player.numberOfAudioTracks > 0) {
        NSMutableArray *tracks = [NSMutableArray new];
        for (i = 0; i < _player.numberOfAudioTracks; i++) {
            if(_player.audioTrackIndexes[i] && _player.audioTrackNames[i]) {
                [tracks addObject:  @{
                    @"id": _player.audioTrackIndexes[i],
                    @"name":  _player.audioTrackNames[i]
                }];
            }
        }
        info[@"audioTracks"] = tracks;
    }
    if(_player.numberOfSubtitlesTracks > 0) {
        NSMutableArray *tracks = [NSMutableArray new];
        for (i = 0; i < _player.numberOfSubtitlesTracks; i++) {
            if(_player.videoSubTitlesIndexes[i] && _player.videoSubTitlesNames[i]) {
                [tracks addObject:  @{
                    @"id": _player.videoSubTitlesIndexes[i],
                    @"name":  _player.videoSubTitlesNames[i]
                }];
            }
        }
        info[@"textTracks"] = tracks;
    }
    return info;
}

- (void)jumpBackward:(int)interval
{
    if(interval>=0 && interval <= [_player.media.length intValue])
        [_player jumpBackward:interval];
}

- (void)jumpForward:(int)interval
{
    if(interval>=0 && interval <= [_player.media.length intValue])
        [_player jumpForward:interval];
}

-(void)setSeek:(float)pos
{
    if([_player isSeekable]){
        if(pos>=0 && pos <= 1){
            [_player setPosition:pos];
        }
    }
}

-(void)setSnapshotPath:(NSString*)path
{
    if(_player)
        [_player saveVideoSnapshotAt:path withWidth:0 andHeight:0];
}

-(void)setRate:(float)rate
{
    [_player setRate:rate];
}

-(void)setAudioTrack:(int)track
{
    [_player setCurrentAudioTrackIndex: track];
}

-(void)setTextTrack:(int)track
{
    [_player setCurrentVideoSubTitleIndex:track];
}


-(void)setVideoAspectRatio:(NSString *)ratio{
    char *char_content = [ratio cStringUsingEncoding:NSASCIIStringEncoding];
    [_player setVideoAspectRatio:char_content];
}

- (void)setMuted:(BOOL)value
{
    if (_player) {
        [[_player audio] setMuted:value];
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_player.media)
        [_player stop];
    
    if (_player)
        _player = nil;
    
    _eventDispatcher = nil;
}

- (void)_release
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_player.media)
        [_player stop];
    
    if (_player)
        _player = nil;
    
    _eventDispatcher = nil;
}



#pragma mark - Lifecycle
- (void)removeFromSuperview
{
    NSLog(@"removeFromSuperview");
    [self _release];
    [super removeFromSuperview];
}

@end

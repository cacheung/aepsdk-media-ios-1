/*************************************************************************
 * ADOBE CONFIDENTIAL
 * ___________________
 *
 * Copyright 2018 Adobe
 * All Rights Reserved.
 *
 * NOTICE: All information contained herein is, and remains
 * the property of Adobe and its suppliers, if any. The intellectual
 * and technical concepts contained herein are proprietary to Adobe
 * and its suppliers and are protected by all applicable intellectual
 * property laws, including trade secret and copyright laws.
 * Dissemination of this information or reproduction of this material
 * is strictly forbidden unless prior written permission is obtained
 * from Adobe.
 **************************************************************************/

#import "VideoAnalyticsProvider.h"

NSString *const VIDEO_ID    = @"bipbop";
NSString *const VIDEO_NAME    = @"Bip bop video";

double const VIDEO_LENGTH = 1800;

@implementation VideoAnalyticsProvider
{
    id<AEPMediaTracker> _tracker;
    
    NSDictionary* _videoInfo;
    NSMutableDictionary *_videoMetadata;
    BOOL _pendingSessionStart;
    BOOL _pendingPlay;
    VideoPlayer* _player;
}

#pragma mark Initializer & dealloc

- (instancetype)initWithPlayer:(nonnull VideoPlayer*) player;
{
    if (self = [super init])
    {
        _player = player;
        
        NSMutableDictionary* config = [NSMutableDictionary dictionary];
        // To update the channel to something different from global config
        config[AEPMediaTrackerConfig.CHANNEL] = @"ios_AEPObjc_sample";
        
        // For downloaded content tracking.
        //config[AEPMediaTrackerConfig.DOWNLOADED_CONTENT] = [NSNumber numberWithBool:true];
        
        _tracker = [AEPMobileMedia createTrackerWithConfig:config];
        [self setupPlayerNotifications];
    }

    return self;
}

- (void)dealloc
{
    [self destroy];
}

#pragma mark Public methods

- (void)destroy
{
    // Detach from the notification center.
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    _tracker = nil;
}

#pragma mark VideoPlayer notification handlers

- (void)onMainVideoLoaded:(NSNotification *)notification

{
    

    NSDictionary *mediaObject = [AEPMobileMedia createMediaObjectWith:VIDEO_NAME id:VIDEO_ID length:VIDEO_LENGTH streamType:AEPMediaStreamType.VOD mediaType:AEPMediaTypeVideo];
    

    NSMutableDictionary *videoMetadata = [[NSMutableDictionary alloc] init];
    // Sample implementation for using standard metadata keys
    [videoMetadata setObject:@"Sample show" forKey:AEPVideoMetadataKeys.SHOW];
    [videoMetadata setObject:@"Sample Season" forKey:AEPVideoMetadataKeys.SEASON];
    // Sample implementation for using custom metadata keys
    [videoMetadata setObject:@"false" forKey:@"isUserLoggedIn"];
    [videoMetadata setObject:@"Sample TV station" forKey:@"tvStation"];
    
    
    [_tracker trackSessionStart:mediaObject metadata:videoMetadata];
}

- (void)onMainVideoUnloaded:(NSNotification *)notification
{
    [_tracker trackSessionEnd];
}

- (void)onPlay:(NSNotification *)notification
{
    [_tracker trackPlay];
}

- (void)onStop:(NSNotification *)notification
{
    [_tracker trackPause];
}

- (void)onSeekStart:(NSNotification *)notification
{
    [_tracker trackEvent:AEPMediaEventSeekStart info:nil metadata:nil];
    
}

- (void)onSeekComplete:(NSNotification *)notification
{
    [_tracker trackEvent:AEPMediaEventSeekComplete info:nil metadata:nil];
}

- (void)onComplete:(NSNotification *)notification
{
    [_tracker trackComplete];
}

- (void)onChapterStart:(NSNotification *)notification
{
    NSMutableDictionary *chapterDictionary = [[NSMutableDictionary alloc] init];
    [chapterDictionary setObject:@"Sample segment type" forKey:@"segmentType"];
    
    NSDictionary *chapterData = notification.userInfo;
    
    id chapterObject = [AEPMobileMedia createChapterObjectWith:[chapterData objectForKey:@"name"] position:[[chapterData objectForKey:@"position"] intValue] length:[[chapterData objectForKey:@"length"] doubleValue] startTime:[[chapterData objectForKey:@"time"] doubleValue]];

                        
    [_tracker trackEvent:AEPMediaEventChapterStart info:chapterObject metadata:chapterDictionary];
}

- (void)onChapterComplete:(NSNotification *)notification
{
    [_tracker trackEvent:AEPMediaEventChapterComplete info:nil metadata:nil];
}

- (void)onAdStart:(NSNotification *)notification
{
    NSDictionary *adData = [notification.userInfo objectForKey:@"ad"];
    NSDictionary *adBreakData = [notification.userInfo objectForKey:@"adbreak"];
    
    id  adBreakObject = [AEPMobileMedia createAdBreakObjectWith:[adBreakData objectForKey:@"name"] position:[[adBreakData objectForKey:@"position"] doubleValue] startTime:[[adBreakData objectForKey:@"time"] doubleValue]];
    
    id adObject = [AEPMobileMedia createAdObjectWith:[adData objectForKey:@"name"] id:[adData objectForKey:@"id"] position:[[adData objectForKey:@"position"] intValue] length:[[adData objectForKey:@"length"] doubleValue]];

    NSMutableDictionary *adDictionary = [[NSMutableDictionary alloc] init];
    //Attach standard metadata parameters (context data)
    [adDictionary setObject:@"Sample Advertiser" forKey:AEPAdMetadataKeys.ADVERTISER];
    [adDictionary setObject:@"Sample Campaign" forKey:AEPAdMetadataKeys.CAMPAIGN_ID];
    //Attach custom metadata parameters (context data)    
    [adDictionary setObject:@"Sample affiliate" forKey:@"affiliate"];
    
    [_tracker trackEvent:AEPMediaEventAdBreakStart info:adBreakObject metadata:nil];
    [_tracker trackEvent:AEPMediaEventAdStart info:adObject metadata:adDictionary];
}

- (void)onAdComplete:(NSNotification *)notification
{
    [_tracker trackEvent:AEPMediaEventAdBreakComplete info:nil metadata:nil];
    [_tracker trackEvent:AEPMediaEventAdComplete info:nil metadata:nil];
}

- (void)onPlayheadUpdate:(NSNotification *)notification
{
    NSNumber *time = [notification.userInfo objectForKey:@"time"];
    [_tracker updateCurrentPlayhead:[time doubleValue]];
}

- (void)onMuteUpdate:(NSNotification *)notification
{
    NSNumber* muted = [notification.userInfo objectForKey:@"muted"];
    NSLog(@"[VideoAnalyticsProvider] Player muted : %@", [muted boolValue] ? @"Yes" : @"No");
    NSDictionary* muteState = [AEPMobileMedia createStateObjectWith:AEPMediaPlayerState.MUTE];
    AEPMediaEvent event = [muted boolValue] ? AEPMediaEventStateStart : AEPMediaEventStateEnd;
    [_tracker trackEvent:event info:muteState metadata:nil];
   
}

- (void)onCCUpdate:(NSNotification *)notification
{
    NSNumber* ccActive = [notification.userInfo objectForKey:@"ccActive"];
    NSLog(@"[VideoAnalyticsProvider] Closed caption active : %@", [ccActive boolValue] ? @"Yes" : @"No");
    NSDictionary* ccState = [AEPMobileMedia createStateObjectWith:AEPMediaPlayerState.CLOSED_CAPTION];
    AEPMediaEvent event = [ccActive boolValue] ? AEPMediaEventStateStart : AEPMediaEventStateEnd;
    [_tracker trackEvent:event info:ccState metadata:nil];
}

#pragma mark - Private helper methods

- (void)setupPlayerNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onMainVideoLoaded:)
                                                 name:PLAYER_EVENT_VIDEO_LOAD
                                               object:NULL];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onMainVideoUnloaded:)
                                                 name:PLAYER_EVENT_VIDEO_UNLOAD
                                               object:NULL];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onPlay:)
                                                 name:PLAYER_EVENT_PLAY
                                               object:NULL];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onStop:)
                                                 name:PLAYER_EVENT_PAUSE
                                               object:NULL];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onSeekStart:)
                                                 name:PLAYER_EVENT_SEEK_START
                                               object:NULL];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onSeekComplete:)
                                                 name:PLAYER_EVENT_SEEK_COMPLETE
                                               object:NULL];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onComplete:)
                                                 name:PLAYER_EVENT_COMPLETE
                                               object:NULL];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onChapterStart:)
                                                 name:PLAYER_EVENT_CHAPTER_START
                                               object:NULL];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onChapterComplete:)
                                                 name:PLAYER_EVENT_CHAPTER_COMPLETE
                                               object:NULL];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAdStart:)
                                                 name:PLAYER_EVENT_AD_START
                                               object:NULL];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAdComplete:)
                                                 name:PLAYER_EVENT_AD_COMPLETE
                                               object:NULL];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onPlayheadUpdate:)
                                                 name:PLAYER_EVENT_PLAYHEAD_UPDATE
                                               object:NULL];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onCCUpdate:)
                                                 name:PLAYER_EVENT_CC_CHANGE
                                               object:NULL];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onMuteUpdate:)
                                                 name:PLAYER_EVENT_MUTE_CHANGE
                                               object:NULL];
}

@end

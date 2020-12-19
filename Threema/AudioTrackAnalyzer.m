//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2020 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

#import "AudioTrackAnalyzer.h"
#import <AVFoundation/AVFoundation.h>
#import "RootSquareMean.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

#define DECIBEL_OFFSET 15.0

@interface AudioTrackAnalyzer ()

@property NSInteger numberOfChanels;
@property NSURL *url;
@property AVAssetTrack *songTrack;
@property AVAssetReader *reader;
@end

@implementation AudioTrackAnalyzer

+ (instancetype)audioTrackAnalyzerFor: (NSURL *)audioUrl {
    AudioTrackAnalyzer *analyzer = [[AudioTrackAnalyzer alloc] init];
    analyzer.url = audioUrl;
    
    if ([analyzer loadAVData]) {
        return analyzer;
    } else {
        return nil;
    }
}

- (BOOL)loadAVData {
    NSError *error = nil;
    
    NSDictionary *options = @{ AVURLAssetPreferPreciseDurationAndTimingKey:@YES };
    AVURLAsset * urlAsset = [AVURLAsset URLAssetWithURL:_url options:options];
    if ([urlAsset.tracks count] < 1) {
        return NO;
    }
    
    _reader = [AVAssetReader assetReaderWithAsset:urlAsset error:&error];
    _songTrack = [urlAsset.tracks objectAtIndex:0];

    return YES;
}

- (NSTimeInterval)getDuration {
    CMTimeRange timeRange = _songTrack.timeRange;
    Float64 totalDuration = CMTimeGetSeconds(timeRange.duration);

    return totalDuration;
}

- (NSArray *) reduceAudioToDecibelLevels:(NSInteger)numberOfValues {
    
    UInt32 sampleRate = 0;
    UInt32 channelCount = 0;
    
    NSArray* formatDesc = _songTrack.formatDescriptions;
    for(unsigned int i = 0; i < [formatDesc count]; ++i) {
        CMAudioFormatDescriptionRef item = (__bridge CMAudioFormatDescriptionRef)[formatDesc objectAtIndex:i];
        const AudioStreamBasicDescription* fmtDesc = CMAudioFormatDescriptionGetStreamBasicDescription (item);
        if(fmtDesc) {
            sampleRate = fmtDesc->mSampleRate;
            channelCount = fmtDesc->mChannelsPerFrame;
        } else {
            DDLogError(@"Cannot decode audio track format description");
            return nil;
        }
    }
    
    NSDictionary *outputSettingsDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                                        [NSNumber numberWithInt:kAudioFormatLinearPCM],AVFormatIDKey,
                                        [NSNumber numberWithFloat:sampleRate],AVSampleRateKey,
                                        [NSNumber numberWithInt:16],AVLinearPCMBitDepthKey,
                                        [NSNumber numberWithBool:NO],AVLinearPCMIsBigEndianKey,
                                        [NSNumber numberWithBool:NO],AVLinearPCMIsFloatKey,
                                        [NSNumber numberWithBool:NO],AVLinearPCMIsNonInterleaved,
                                        nil];
    
    
    AVAssetReaderTrackOutput* output = [[AVAssetReaderTrackOutput alloc] initWithTrack:_songTrack outputSettings:outputSettingsDict];
    output.alwaysCopiesSampleData = NO;
    [_reader addOutput:output];
    [_reader startReading];

    NSMutableArray *result = [NSMutableArray arrayWithCapacity:numberOfValues];
    
    CMTimeValue totalTimeValue = _songTrack.timeRange.duration.value;
    
    CMTimeValue samplesPerValue = totalTimeValue / numberOfValues;

    CMItemCount totalSampleCount = 0;
    RootSquareMean *rms = [[RootSquareMean alloc] init];
    
    while (_reader.status == AVAssetReaderStatusReading){
        CMSampleBufferRef sampleBufferRef = [output copyNextSampleBuffer];
        if (sampleBufferRef == NULL) {
            continue;
        }
        
        CMBlockBufferRef blockBufferRef = CMSampleBufferGetDataBuffer(sampleBufferRef);
        
        size_t length = CMBlockBufferGetDataLength(blockBufferRef);
        
        NSMutableData * data = [NSMutableData dataWithLength:length];
        CMBlockBufferCopyDataBytes(blockBufferRef, 0, length, data.mutableBytes);
        SInt16 *samples = (SInt16 *) data.mutableBytes;
        
        CMItemCount blockSampleCount = CMSampleBufferGetNumSamples(sampleBufferRef);
        totalSampleCount += blockSampleCount;
        for (CMItemCount i=0; i<blockSampleCount; i++) {
            for (int j=0; j<channelCount; j++) {
                [rms addValue: *samples];
                samples++;
            }
            
            if ([rms count] >= samplesPerValue) {
                Float32 value = [rms getAndReset];
                Float32 decibel = (20.0f * log10(value/UINT16_MAX) + DECIBEL_OFFSET);

                [result addObject: [NSNumber numberWithDouble: decibel]];
                if (_delegate) {
                    [_delegate trackAnalyzerNextValue: decibel];
                }
            }
        }
        
        CMSampleBufferInvalidate(sampleBufferRef);
        CFRelease(sampleBufferRef);
    }
    
    if ([rms count] > 0) {
        Float32 value = [rms getAndReset];
        Float32 decibel = (20.0f * log10(value/UINT16_MAX) + DECIBEL_OFFSET);
        
        [result addObject: [NSNumber numberWithDouble: decibel]];
    }
    
    
    if (_reader.status == AVAssetReaderStatusFailed || _reader.status == AVAssetReaderStatusUnknown){
        return nil;
    }
    
    if (_delegate) {
        [_delegate trackAnalyzerFinished];
    }

    return result;
}

@end

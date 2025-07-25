#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            printf("Usage: ./prores-raw-export filename.mov [frame count]\n");
            exit(0);
        }
        
        NSString* pathToProResRaw = [NSString stringWithUTF8String:argv[1]];
        NSLog(@"Loading: %@", pathToProResRaw);
        
        int frameCount = 0;
        if (argc == 3) {
            frameCount = [[NSString stringWithFormat:@"%s", argv[2]] intValue];
        }

        AVURLAsset* asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:pathToProResRaw] options:@{AVURLAssetPreferPreciseDurationAndTimingKey: @(YES)}];
        
        // Check if asset is readable
        NSError* loadError = nil;
        NSArray* keys = @[@"readable", @"tracks"];
        AVKeyValueStatus status = [asset statusOfValueForKey:@"readable" error:&loadError];
        if (status == AVKeyValueStatusFailed) {
            NSLog(@"Asset loading failed: %@", loadError.localizedDescription);
            exit(1);
        }
        
        // Load the asset synchronously
        [asset loadValuesAsynchronouslyForKeys:keys completionHandler:^{}];
        
        NSError* error = nil;
        AVAssetReader* assetReader = [AVAssetReader assetReaderWithAsset:asset error:&error];

        if ( error != nil)
        {
            NSLog(@"Error loading asset reader: %@", error.localizedDescription);
            exit(0);
        }
        
        AVAssetTrack* videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
        
        if ( videoTrack == nil)
        {
            NSLog(@"Error loading asset - no video track");
            exit(0);
        }
        
        // Log video track information
        NSLog(@"Video track format: %@", videoTrack.formatDescriptions);
        NSLog(@"Video track duration: %f seconds", CMTimeGetSeconds(videoTrack.timeRange.duration));
        
        // Try different pixel format configurations for ProRes RAW
        NSDictionary *proResDict = @{
            AVVideoAllowWideColorKey: @(YES),
            // Remove specific pixel format to let AVFoundation choose automatically
            // (NSString*)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_16VersatileBayer),
            AVVideoDecompressionPropertiesKey:@{
                @"EnableLoggingInProResRAW": @(YES),
                @"ProResRAWLoggingLevel": @(1)
            }
        };
        
        AVAssetReaderTrackOutput* videoOutputNoDecompress = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack
                                                                                                       outputSettings:proResDict];
        videoOutputNoDecompress.alwaysCopiesSampleData = FALSE;
        
        if (!videoOutputNoDecompress || ![assetReader canAddOutput:videoOutputNoDecompress] )
        {
            NSLog(@"Error loading asset - unable to associate decoder with reader");
            exit(0);
        }
        
        [assetReader addOutput:videoOutputNoDecompress];
        
        BOOL startResult = [assetReader startReading];
        if (!startResult) {
            NSLog(@"Failed to start reading: %@", assetReader.error.localizedDescription);
            exit(1);
        }
        
        NSLog(@"Started reading, asset reader status: %ld", (long)assetReader.status);
        
        int frameNumber = 0;
        while (assetReader.status == AVAssetReaderStatusReading)
        {
            CMSampleBufferRef videoSampleBuffer = [videoOutputNoDecompress copyNextSampleBuffer];
            
            if (videoSampleBuffer)
            {
                CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(videoSampleBuffer);
                
                CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
                
                void* baseaddr = CVPixelBufferGetBaseAddress(imageBuffer);
                size_t bpr = CVPixelBufferGetBytesPerRow(imageBuffer);
                size_t height = CVPixelBufferGetHeight(imageBuffer);
                NSData* sampleBufferRawData = [NSData dataWithBytes:baseaddr length:bpr * height];
                
                NSError *error = nil;
                NSString* path = [NSString stringWithFormat:@"%@.%06d.raw", pathToProResRaw, frameNumber];
                [sampleBufferRawData writeToFile:path options:NSDataWritingAtomic error:&error];
                
                if (error) {
                    NSLog(@"Write error: %@", [error localizedDescription]);
                } else {
                    NSLog(@"%@", path);
                }
                
                CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
                CFRelease(videoSampleBuffer);
                
                frameNumber++;

            } else {
                // Check why videoSampleBuffer is null
                NSLog(@"videoSampleBuffer is null - Asset reader status: %ld", (long)assetReader.status);
                if (assetReader.error) {
                    NSLog(@"Asset reader error: %@", assetReader.error.localizedDescription);
                }
                
                // Check if we've reached the end of the file normally
                if (assetReader.status == AVAssetReaderStatusCompleted) {
                    NSLog(@"Reached end of file normally. Processed %d frames.", frameNumber);
                    break;
                } else {
                    NSLog(@"Asset reader failed or was cancelled");
                    exit(1);
                }
            }
            
            if (frameCount > 0 && frameNumber >= frameCount) {
                NSLog(@"Exported %d frames, exiting early", frameCount);
                break;
            }
        }
        
        NSLog(@"Final asset reader status: %ld", (long)assetReader.status);
        if (assetReader.error) {
            NSLog(@"Final error: %@", assetReader.error.localizedDescription);
        }
        
    }
    return 0;
}

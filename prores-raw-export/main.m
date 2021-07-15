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
        
        NSDictionary *proResDict = @{
            AVVideoAllowWideColorKey: @(YES),
            (NSString*)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_16VersatileBayer),
            (NSString*)kCVPixelBufferIOSurfacePropertiesKey: @{},
            (NSString*)kCVPixelBufferMetalCompatibilityKey: @(YES),
            AVVideoDecompressionPropertiesKey:@{@"EnableLoggingInProResRAW": @(YES)}
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
        [assetReader startReading];
        
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
                
                frameNumber++;

            } else {
                NSLog(@"videoSampleBuffer is null");
                exit(0);
            }
            
            if (frameCount > 0 && frameNumber >= frameCount) {
                NSLog(@"Exported %d frames, exiting early", frameCount);
                exit(0);
            }
        }
        
    }
    return 0;
}

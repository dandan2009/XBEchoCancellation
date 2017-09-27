//
//  XBEchoCancellation.m
//  iOSEchoCancellation
//
//  Created by xxb on 2017/8/25.
//  Copyright © 2017年 xxb. All rights reserved.
//

#import "XBEchoCancellation.h"

typedef struct MyAUGraphStruct{
    AUGraph graph;
    AudioUnit remoteIOUnit;
} MyAUGraphStruct;


@interface XBEchoCancellation ()
{
    MyAUGraphStruct myStruct;
}
@property (nonatomic,assign) BOOL isCloseService; //没有声音服务
@property (nonatomic,assign) BOOL isNeedInputCallback; //需要录音回调(input即麦克风采集到的声音)
@property (nonatomic,assign) BOOL isNeedOutputCallback; //需要播放回调(output即像麦克风传递的声音)

@end

@implementation XBEchoCancellation

@synthesize streamFormat;

+ (instancetype)shared
{
    return [self new];
}
+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    static XBEchoCancellation *cancel = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cancel = [super allocWithZone:zone];
    });
    return cancel;
}
- (instancetype)init
{
    if (self = [super init])
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            self.status = XBEchoCancellationStatus_close;
            self.isCloseService = YES;
            [self startService];
        });
    }
    return self;
}

- (void)startInput
{
    if (self.isCloseService)
    {
        NSLog(@"请调用startService开启服务");
        return;
    }
    self.isNeedInputCallback = YES;
}
- (void)stopInput
{
    self.isNeedInputCallback = NO;
}
- (void)startOutput
{
    if (self.isCloseService)
    {
        NSLog(@"请调用startService开启服务");
        return;
    }
    self.isNeedOutputCallback = YES;
    AudioOutputUnitStart(myStruct.remoteIOUnit);
}
- (void)stopOutput
{
    self.isNeedOutputCallback = NO;
    AudioOutputUnitStop(myStruct.remoteIOUnit);
}
- (void)startService
{
    if (self.isCloseService == NO)
    {
        return;
    }
    
    [self setupSession];
    
    [self createAUGraph:&myStruct];
    
    [self setupRemoteIOUnit:&myStruct];
    
    [self startGraph:myStruct.graph];
    
//    AudioOutputUnitStop(myStruct.remoteIOUnit);
    
    self.isCloseService = NO;
    NSLog(@"startService完成");
}

- (void)stop
{
    self.bl_echoCancellation = nil;
    self.bl_play = nil;
    [self stopGraph:myStruct.graph];
}
- (void)openEchoCancellation
{
    if (self.isCloseService == YES)
    {
        return;
    }
    [self openOrCloseEchoCancellation:0];
}
- (void)closeEchoCancellation
{
    if (self.isCloseService == YES)
    {
        return;
    }
    [self openOrCloseEchoCancellation:1];
}
///0 开启，1 关闭
-(void)openOrCloseEchoCancellation:(UInt32)newEchoCancellationStatus
{
    if (self.isCloseService == YES)
    {
        return;
    }
    UInt32 echoCancellation;
    UInt32 size = sizeof(echoCancellation);
    CheckError(AudioUnitGetProperty(myStruct.remoteIOUnit,
                                    kAUVoiceIOProperty_BypassVoiceProcessing,
                                    kAudioUnitScope_Global,
                                    0,
                                    &echoCancellation,
                                    &size),
               "kAUVoiceIOProperty_BypassVoiceProcessing failed");
    if (newEchoCancellationStatus == echoCancellation)
    {
        return;
    }
    
    CheckError(AudioUnitSetProperty(myStruct.remoteIOUnit,
                                    kAUVoiceIOProperty_BypassVoiceProcessing,
                                    kAudioUnitScope_Global,
                                    0,
                                    &newEchoCancellationStatus,
                                    sizeof(newEchoCancellationStatus)),
               "AudioUnitSetProperty kAUVoiceIOProperty_BypassVoiceProcessing failed");
    self.status = newEchoCancellationStatus == 0 ? XBEchoCancellationStatus_open : XBEchoCancellationStatus_close;
}

-(void)startGraph:(AUGraph)graph
{
    CheckError(AUGraphInitialize(graph),
               "AUGraphInitialize failed");
    CheckError(AUGraphStart(graph),
               "AUGraphStart failed");
    self.status = XBEchoCancellationStatus_open;
}

- (void)stopGraph:(AUGraph)graph
{
    if (self.isCloseService == YES)
    {
        return;
    }
    CheckError(AUGraphUninitialize(graph),
               "AUGraphUninitialize failed");
    CheckError(AUGraphStop(graph),
               "AUGraphStop failed");
    self.isCloseService = YES;
    self.status = XBEchoCancellationStatus_close;
}


-(void)createAUGraph:(MyAUGraphStruct*)augStruct{
    //Create graph
    CheckError(NewAUGraph(&augStruct->graph),
               "NewAUGraph failed");
    
    //Create nodes and add to the graph
    AudioComponentDescription inputcd = {0};
    inputcd.componentType = kAudioUnitType_Output;
    inputcd.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
    inputcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    AUNode remoteIONode;
    //Add node to the graph
    CheckError(AUGraphAddNode(augStruct->graph,
                              &inputcd,
                              &remoteIONode),
               "AUGraphAddNode failed");
    
    //Open the graph
    CheckError(AUGraphOpen(augStruct->graph),
               "AUGraphOpen failed");
    
    //Get reference to the node
    CheckError(AUGraphNodeInfo(augStruct->graph,
                               remoteIONode,
                               &inputcd,
                               &augStruct->remoteIOUnit),
               "AUGraphNodeInfo failed");
}


-(void)setupRemoteIOUnit:(MyAUGraphStruct*)augStruct{
    //Open input of the bus 1(input mic)
    UInt32 inputEnableFlag = 1;
    CheckError(AudioUnitSetProperty(augStruct->remoteIOUnit,
                                    kAudioOutputUnitProperty_EnableIO,
                                    kAudioUnitScope_Input,
                                    1,
                                    &inputEnableFlag,
                                    sizeof(inputEnableFlag)),
               "Open input of bus 1 failed");
    
    //Open output of bus 0(output speaker)
    UInt32 outputEnableFlag = 1;
    CheckError(AudioUnitSetProperty(augStruct->remoteIOUnit,
                                    kAudioOutputUnitProperty_EnableIO,
                                    kAudioUnitScope_Output,
                                    0,
                                    &outputEnableFlag,
                                    sizeof(outputEnableFlag)),
               "Open output of bus 0 failed");
    
    //Set up stream format for input and output
    streamFormat.mFormatID = kAudioFormatLinearPCM;
    streamFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    streamFormat.mSampleRate = kRate;
    streamFormat.mFramesPerPacket = 1;
    streamFormat.mBytesPerFrame = 2;
    streamFormat.mBytesPerPacket = 2;
    streamFormat.mBitsPerChannel = kBits;
    streamFormat.mChannelsPerFrame = kChannels;
    
    CheckError(AudioUnitSetProperty(augStruct->remoteIOUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Input,
                                    0,
                                    &streamFormat,
                                    sizeof(streamFormat)),
               "kAudioUnitProperty_StreamFormat of bus 0 failed");
    
    CheckError(AudioUnitSetProperty(augStruct->remoteIOUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Output,
                                    1,
                                    &streamFormat,
                                    sizeof(streamFormat)),
               "kAudioUnitProperty_StreamFormat of bus 1 failed");
    
    AURenderCallbackStruct input;
    input.inputProc = InputCallback_xb;
    input.inputProcRefCon = (__bridge void *)(self);
    CheckError(AudioUnitSetProperty(augStruct->remoteIOUnit,
                                    kAudioOutputUnitProperty_SetInputCallback,
                                    kAudioUnitScope_Output,
                                    1,
                                    &input,
                                    sizeof(input)),
               "couldnt set remote i/o render callback for output");
    
    AURenderCallbackStruct output;
    output.inputProc = outputRenderTone_xb;
    output.inputProcRefCon = (__bridge void *)(self);
    CheckError(AudioUnitSetProperty(augStruct->remoteIOUnit,
                                    kAudioUnitProperty_SetRenderCallback,
                                    kAudioUnitScope_Input,
                                    0,
                                    &output,
                                    sizeof(output)),
               "kAudioUnitProperty_SetRenderCallback failed");
}

-(void)createRemoteIONodeToGraph:(AUGraph*)graph
{
    
}

-(void)setupSession
{
    NSError *error = nil;
    AVAudioSession* session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:&error];
    [session setActive:YES error:nil];
}


#pragma mark - 其他方法

static void CheckError(OSStatus error, const char *operation)
{
    if (error == noErr) return;
    char errorString[20];
    // See if it appears to be a 4-char-code
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
    if (isprint(errorString[1]) && isprint(errorString[2]) &&
        isprint(errorString[3]) && isprint(errorString[4])) {
        errorString[0] = errorString[5] = '\'';
        errorString[6] = '\0';
    } else
        // No, format it as an integer
        sprintf(errorString, "%d", (int)error);
    fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
    exit(1);
}

OSStatus InputCallback_xb(void *inRefCon,
                       AudioUnitRenderActionFlags *ioActionFlags,
                       const AudioTimeStamp *inTimeStamp,
                       UInt32 inBusNumber,
                       UInt32 inNumberFrames,
                       AudioBufferList *ioData){
    
    XBEchoCancellation *echoCancellation = (__bridge XBEchoCancellation*)inRefCon;
    if (echoCancellation.isNeedInputCallback == NO)
    {
//        NSLog(@"没有开启声音输入回调");
        return noErr;
    }
    MyAUGraphStruct *myStruct = &(echoCancellation->myStruct);
    
    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0].mData = NULL;
    bufferList.mBuffers[0].mDataByteSize = 0;

    AudioUnitRender(myStruct->remoteIOUnit,
                                      ioActionFlags,
                                      inTimeStamp,
                                      1,
                                      inNumberFrames,
                                      &bufferList);
    AudioBuffer buffer = bufferList.mBuffers[0];
    
    if (echoCancellation.bl_echoCancellation)
    {
        echoCancellation.bl_echoCancellation(buffer);
    }

    NSLog(@"InputCallback");
    return noErr;
}
OSStatus outputRenderTone_xb(
                          void *inRefCon,
                          AudioUnitRenderActionFlags 	*ioActionFlags,
                          const AudioTimeStamp 		*inTimeStamp,
                          UInt32 						inBusNumber,
                          UInt32 						inNumberFrames,
                          AudioBufferList 			*ioData)

{
    //TODO: implement this function
    memset(ioData->mBuffers[0].mData, 0, ioData->mBuffers[0].mDataByteSize);
    
    XBEchoCancellation *echoCancellation = (__bridge XBEchoCancellation*)inRefCon;
    if (echoCancellation.isNeedOutputCallback == NO)
    {
        //        NSLog(@"没有开启声音输出回调");
        return noErr;
    }
    if (echoCancellation.bl_play)
    {
        echoCancellation.bl_play(ioData->mBuffers[0].mData,inNumberFrames);
    }

    NSLog(@"outputRenderTone");
    return 0;
}
@end
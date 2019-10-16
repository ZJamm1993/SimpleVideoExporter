//
//  ViewController.m
//  SimpleVideoExporterApp
//
//  Created by zjj on 2019/10/16.
//  Copyright © 2019 zjj. All rights reserved.
//

#import "ViewController.h"
#import "ZZDragFileView.h"
#import "ZZVideoExporter.h"

#define WeakDefine(strongA, weakA) __weak typeof(strongA) weakA = strongA;

@interface ViewController()<ZZDragFileViewDelegate>

@property (weak) IBOutlet NSTextField *outputPathTextField;
@property (weak) IBOutlet NSProgressIndicator *progressBar;
@property (weak) IBOutlet NSTextField *tipsTextField;

@property ZZVideoExporter *currentVideoExporter;
@property NSTimer *timer;
@property NSMutableArray *queueURLs;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
}

- (IBAction)selectOutputPath:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canCreateDirectories = YES;
    panel.canChooseDirectories = YES;
    panel.canChooseFiles = NO;
    panel.allowsMultipleSelection = NO;
    WeakDefine(self, weakself);
    [panel beginWithCompletionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            NSURL *first = panel.URLs.firstObject;
            NSString *path = first.absoluteString;
            weakself.outputPathTextField.stringValue = [self pathStringByRemovingFilePrefix:path];;
        }
    }];
}

- (void)dragFileViewDidDragURLs:(NSArray *)URLs {
    NSLog(@"%@", URLs);
    self.queueURLs = [URLs mutableCopy];
    [self exportVideoForInputURL:URLs.firstObject];
}

- (NSString *)pathStringByRemovingFilePrefix:(NSString *)pathString {
    pathString = [pathString stringByReplacingOccurrencesOfString:@"file:/" withString:@"/"];
    pathString = [pathString stringByReplacingOccurrencesOfString:@"//" withString:@"/"];
    pathString = [pathString stringByReplacingOccurrencesOfString:@"//" withString:@"/"];
    return pathString;
}

- (void)exportVideoForInputURL:(NSURL *)inputURL {
    if (!inputURL) {
        return;
    }
    WeakDefine(self, weakself);
    NSString *inputPath = [inputURL absoluteString];
    inputPath = [self pathStringByRemovingFilePrefix:inputPath];
    self.tipsTextField.stringValue = [NSString stringWithFormat:@"正在导出：%@", inputPath];
    
    NSString *inputFileName = [[inputPath componentsSeparatedByString:@"/"] lastObject];
    NSString *outputDir = self.outputPathTextField.stringValue ;
    if (outputDir.length == 0) {
        return;
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:outputDir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:outputDir withIntermediateDirectories:NO attributes:nil error:nil];
    }
    NSString *outputPath = [outputDir stringByAppendingPathComponent:inputFileName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
        NSMutableArray *nameCompos = [[inputFileName componentsSeparatedByString:@"."] mutableCopy];
        if (nameCompos.count >= 2) {
            NSString *insertCompo = [NSString stringWithFormat:@"%ld.%ld", (long)[NSDate timeIntervalSinceReferenceDate], (long)arc4random() % 1000];
            [nameCompos insertObject:insertCompo atIndex:nameCompos.count - 1];
        }
        NSString *name = [nameCompos componentsJoinedByString:@"."];
        outputPath = [outputDir stringByAppendingPathComponent:name];
    }

    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.02 repeats:YES block:^(NSTimer * _Nonnull timer) {
        weakself.progressBar.doubleValue = weakself.currentVideoExporter.progress;
    }];
    
    self.currentVideoExporter = [[ZZVideoExporter alloc] initWithInputPath:inputPath outputPath:outputPath];
    [self.currentVideoExporter startExportWithCompletionHandler:^{
        [weakself.timer invalidate];
        weakself.progressBar.doubleValue = 0;
        NSError *err = weakself.currentVideoExporter.error;
        if (err) {
            weakself.tipsTextField.stringValue = err.description;
        }
        if (weakself.currentVideoExporter.status == AVAssetExportSessionStatusCompleted) {
            weakself.progressBar.doubleValue = 1;
            weakself.tipsTextField.stringValue = [NSString stringWithFormat:@"已导出：%@", outputPath];
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakself completeWithURL:inputURL];
        });
    }];
}

- (void)completeWithURL:(NSURL *)URL {
    [self.queueURLs removeObject:URL];
    if (self.queueURLs.count > 0) {
        [self exportVideoForInputURL:self.queueURLs.firstObject];
    }
}

@end

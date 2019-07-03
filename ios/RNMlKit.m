
#import "RNMlKit.h"

#import <React/RCTBridge.h>

#import <FirebaseCore/FirebaseCore.h>
#import <FirebaseMLVision/FirebaseMLVision.h>
#import <FirebaseMLVision/MLNLTranslate.h>

@implementation RNMlKit

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE()

static NSString *const detectionNoResultsMessage = @"Something went wrong";


- (NSString *)barcodeFormat:(FIRVisionBarcodeFormat)format {
     switch (format) {
         case FIRVisionBarcodeFormatCode128:
             return @"CODE_128";
         case FIRVisionBarcodeFormatCode39:
             return @"CODE_39";
         case FIRVisionBarcodeFormatCode93:
             return @"CODE_93";
         case FIRVisionBarcodeFormatCodaBar:
             return @"CODABAR";
         case FIRVisionBarcodeFormatDataMatrix:
             return @"DATA_MATRIX";
         case FIRVisionBarcodeFormatEAN13:
             return @"EAN_13";
         case FIRVisionBarcodeFormatEAN8:
             return @"EAN_8";
         case FIRVisionBarcodeFormatITF:
             return @"ITF";
         case FIRVisionBarcodeFormatQRCode:
             return @"QR_CODE";
         case FIRVisionBarcodeFormatUPCA:
             return @"UPC_A";
         case FIRVisionBarcodeFormatUPCE:
             return @"UPC_E";
         case FIRVisionBarcodeFormatPDF417:
             return @"PDF417";
         case FIRVisionBarcodeFormatAztec:
             return @"AZTEC";
         default:
             return @"UNKNOWN";
     }
}



RCT_REMAP_METHOD(deviceBarcodeRecognition, deviceBarcodeRecognition:(NSString *)imagePath resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if (!imagePath) {
        resolve(@NO);
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        FIRVisionBarcodeDetectorOptions *options = [[FIRVisionBarcodeDetectorOptions alloc] initWithFormats: FIRVisionBarcodeFormatAll];
        FIRVision *vision = [FIRVision vision];
        FIRVisionBarcodeDetector *barcodeDetector = [vision barcodeDetectorWithOptions: options];
        NSDictionary *d = [[NSDictionary alloc] init];
        NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:imagePath]];
        UIImage *image = [UIImage imageWithData:imageData];
        
        if (!image) {
            dispatch_async(dispatch_get_main_queue(), ^{
                resolve(@NO);
            });
            return;
        }
        
        FIRVisionImage *handler = [[FIRVisionImage alloc] initWithImage:image];

        [barcodeDetector detectInImage:handler completion:^(NSArray<FIRVisionBarcode *> *barcodes, NSError *_Nullable error) {
            if (error != nil) {
                NSString *errorString = error ? error.localizedDescription : detectionNoResultsMessage;
                NSDictionary *pData = @{
                                        @"error": [NSMutableString stringWithFormat:@"On-Device text detection failed with error: %@", errorString],
                                        };
                // Running on background thread, don't call UIKit
                dispatch_async(dispatch_get_main_queue(), ^{
                    resolve(pData);
                });
                return;
            }

            NSMutableArray *output = [NSMutableArray array];
            for (FIRVisionBarcode *barcode in barcodes) {
                NSMutableDictionary *result = [NSMutableDictionary dictionary];
                NSString *format = [self barcodeFormat: barcode.format];

                result[@"value"] = barcode.rawValue;
                result[@"format"] = format;
                [output addObject:result];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                resolve(output);
            });
        }];
    });
}

RCT_REMAP_METHOD(deviceTextRecognition, deviceTextRecognition:(NSString *)imagePath resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if (!imagePath) {
        resolve(@NO);
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        FIRVision *vision = [FIRVision vision];
        FIRVisionTextRecognizer *textRecognizer = [vision onDeviceTextRecognizer];
        NSDictionary *d = [[NSDictionary alloc] init];
        NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:imagePath]];
        UIImage *image = [UIImage imageWithData:imageData];
        
        if (!image) {
            dispatch_async(dispatch_get_main_queue(), ^{
                resolve(@NO);
            });
            return;
        }
        
        FIRVisionImage *handler = [[FIRVisionImage alloc] initWithImage:image];

        [textRecognizer processImage:handler completion:^(FIRVisionText *_Nullable result, NSError *_Nullable error) {
            if (error != nil || result == nil) {
                NSString *errorString = error ? error.localizedDescription : detectionNoResultsMessage;
                NSDictionary *pData = @{
                                        @"error": [NSMutableString stringWithFormat:@"On-Device text detection failed with error: %@", errorString],
                                        };
                // Running on background thread, don't call UIKit
                dispatch_async(dispatch_get_main_queue(), ^{
                    resolve(pData);
                });
                return;
            }

            CGRect boundingBox;
            CGSize size;
            CGPoint origin;
            NSMutableArray *output = [NSMutableArray array];

            for (FIRVisionTextBlock *block in result.blocks) {
                NSMutableDictionary *blocks = [NSMutableDictionary dictionary];
                NSMutableDictionary *bounding = [NSMutableDictionary dictionary];
                NSString *blockText = block.text;

                bounding[@"left"]=[NSString stringWithFormat: @"%f", block.cornerPoints[0].CGVectorValue.dx];
                bounding[@"top"]=[NSString stringWithFormat: @"%f", block.cornerPoints[0].CGVectorValue.dy];

                bounding[@"width"]=[NSString stringWithFormat: @"%f", block.cornerPoints[2].CGVectorValue.dx-block.cornerPoints[0].CGVectorValue.dx];
                bounding[@"height"]=[NSString stringWithFormat: @"%f", block.cornerPoints[2].CGVectorValue.dy - block.cornerPoints[0].CGVectorValue.dy];

                blocks[@"resultText"] = result.text;
                blocks[@"blockText"] = block.text;
                blocks[@"blockCoordinates"] = bounding;

                [output addObject:blocks];

                for (FIRVisionTextLine *line in block.lines) {
                    NSMutableDictionary *lines = [NSMutableDictionary dictionary];
                    lines[@"lineText"] = line.text;
                    [output addObject:lines];

                    for (FIRVisionTextElement *element in line.elements) {
                        NSMutableDictionary *elements = [NSMutableDictionary dictionary];
                        elements[@"elementText"] = element.text;
                        [output addObject:elements];

                    }
                }
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                resolve(output);
            });
        }];
    });
    
}

@end
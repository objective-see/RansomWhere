//
//  fileChecks.h
//  Daemon
//
//  Created by Patrick Wardle on 1/21/26.
//  Copyright © 2026 Objective-See. All rights reserved.
//

#ifndef fileChecks_h
#define fileChecks_h

#import <Foundation/Foundation.h>

BOOL isGzip(NSData* header);
BOOL isImage(NSData* header);
BOOL isEncrypted(NSString* path);


//gif ('GIF8')
// ->note: covers 'GIF87a' and 'GIF89a'
#define MAGIC_GIF 0x38464947

//png ('.PNG')
#define MAGIC_PNG 0x474E5089

//icns ('icns')
#define MAGIC_ICNS 0x736E6369

//jpg
#define MAGIC_JPG  0xE0FFD8FF

//jpeg
#define MAGIC_JPEG 0xDBFFD8FF

//tiff
#define MAGIC_TIFF 0x2A004D4D

#endif /* fileChecks_h */

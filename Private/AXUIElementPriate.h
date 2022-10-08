//
//  AXUIElementPriate.h
//  Vimac
//
//  Created by marcow on 2022/10/8.
//  Copyright © 2022 Dexter Leng. All rights reserved.
//

#ifndef AXUIElementPriate_h
#define AXUIElementPriate_h

#import <AppKit/AppKit.h>

CF_ASSUME_NONNULL_BEGIN

AXError _AXUIElementCopyElementAtPositionIncludeIgnored(AXUIElementRef application, float x,float y, AXUIElementRef __nullable * __nonnull CF_RETURNS_RETAINED element, bool includingIgnored);

CF_ASSUME_NONNULL_END

#endif /* AXUIElementPriate_h */



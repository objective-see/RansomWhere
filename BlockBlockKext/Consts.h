//
//  Consts.h
//  BlockBlockKext
//
//  Created by Patrick Wardle on 11/23/15.
//  Copyright © 2015 Objective-See. All rights reserved.
//

#ifndef Consts_h
#define Consts_h

//vendor id string
#define OBJECTIVE_SEE_VENDOR "com.objective-see"

//process started
#define PROCESS_BEGAN_EVENT	0x1

//print macros
#ifdef DEBUG
# define DEBUG_PRINT(x) printf x
#else
# define DEBUG_PRINT(x) do {} while (0)
#endif


#endif /* Consts_h */

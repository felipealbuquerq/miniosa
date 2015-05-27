
/*! \file */

#ifndef MN_COREAUDIO_IO_H
#define MN_COREAUDIO_IO_H

#include <AudioUnit/AudioUnit.h>
#include <AudioToolbox/AudioToolbox.h>
#include <CoreAudio/CoreAudioTypes.h>

#include "miniosa.h"

#ifdef __cplusplus
extern "C"
{
#endif /* __cplusplus */
    
        
    mnError mnInitialize(mnAudioInputCallback inputCallback,
                         mnAudioOutputCallback outputCallback,
                         void* callbackContext,
                         mnOptions* options);
    
    mnError mnDeinitialize();
    
    
    /** Creates the singleton remote I/O unit instance. */
    void mnCreateRemoteIOInstance(void);
    
    /**
     * Stops and uninitializes the remote I/O unit.
     */
    void mnStopAndDeinitRemoteIO(void);
    
    /**
     * Initializes and starts the remote I/O unit.
     */
    void mnInitAndStartRemoteIO(void);
    

    
    void mnSuspendAudio(void);
    
    /**
     * Returns non-zero if successful, zero otherwise.
     */
    int mnResumeAudio(void);
    
    
#ifdef __cplusplus
}
#endif /* __cplusplus */


#endif //MN_COREAUDIO_IO_H
